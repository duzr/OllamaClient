//
//  ChatViewModel.swift
//  OllamaClient
//
//  Observable state for the chat UI: server host, available models, the running
//  conversation history, and the streaming send loop.
//

import Foundation
import Observation

@MainActor
@Observable
final class ChatViewModel {

    /// Server address. Persisted so it survives relaunches.
    var host: String {
        didSet { UserDefaults.standard.set(host, forKey: Self.hostDefaultsKey) }
    }

    /// Models available on the server.
    private(set) var models: [OllamaModel] = []
    var selectedModel: OllamaModel?

    /// The full conversation history sent to `/api/chat` on every turn so the
    /// model retains context between messages.
    private(set) var messages: [ChatMessage] = []

    /// Text currently being composed in the input field.
    var draft: String = ""

    private(set) var isLoadingModels = false
    private(set) var isStreaming = false
    var errorMessage: String?

    private let service = OllamaService()
    private var streamTask: Task<Void, Never>?

    private static let hostDefaultsKey = "ollamaHost"
    static let defaultHost = "http://localhost:11434"

    init() {
        self.host = UserDefaults.standard.string(forKey: Self.hostDefaultsKey) ?? Self.defaultHost
    }

    /// True when the user can submit the current draft.
    var canSend: Bool {
        !isStreaming
            && selectedModel != nil
            && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Models

    /// Fetches the model list from the server and preserves the current
    /// selection when possible.
    func loadModels() async {
        isLoadingModels = true
        errorMessage = nil
        defer { isLoadingModels = false }

        do {
            let fetched = try await service.listModels(host: host)
            models = fetched
            if let selected = selectedModel, fetched.contains(selected) {
                // Keep the existing selection.
            } else {
                selectedModel = fetched.first
            }
        } catch {
            models = []
            selectedModel = nil
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Chat

    /// Sends the current draft and streams the assistant's reply into the
    /// conversation.
    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let model = selectedModel, !isStreaming else { return }

        draft = ""
        errorMessage = nil
        messages.append(ChatMessage(role: .user, content: text))

        // Placeholder assistant message that fills in as chunks arrive.
        let replyIndex = messages.count
        messages.append(ChatMessage(role: .assistant, content: "", isStreaming: true))
        isStreaming = true

        // Snapshot the history to send, sanitizing assistant messages so that
        // reasoning traces and raw LaTeX backslashes don't cause the server to
        // return HTTP 500 on subsequent turns.
        let history = messages[..<replyIndex].map { sanitizedForHistory($0) }

        streamTask = Task {
            let stream = service.streamChat(host: host, model: model.name, messages: history)
            do {
                for try await piece in stream {
                    guard messages.indices.contains(replyIndex) else { break }
                    messages[replyIndex].content += piece
                }
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                if messages.indices.contains(replyIndex),
                   messages[replyIndex].content.isEmpty {
                    // Drop the empty placeholder so the transcript stays clean.
                    messages.remove(at: replyIndex)
                }
            }
            if messages.indices.contains(replyIndex) {
                messages[replyIndex].isStreaming = false
            }
            isStreaming = false
        }
    }

    /// Cancels an in-flight streamed reply.
    func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        if let last = messages.indices.last, messages[last].isStreaming {
            messages[last].isStreaming = false
            if messages[last].content.isEmpty {
                messages.remove(at: last)
            }
        }
    }

    /// Prepares an assistant message for inclusion in the history payload sent
    /// to the server. Non-assistant messages are returned unchanged.
    ///
    /// Two transforms are applied (display is never touched):
    ///   1. Strip `<think>…</think>` blocks — chain-of-thought scratch text
    ///      that the server doesn't need as context.
    ///   2. Double raw backslashes — LaTeX output like `\boxed{4}` breaks
    ///      the server's internal prompt-rendering on replay if left as-is.
    private func sanitizedForHistory(_ message: ChatMessage) -> ChatMessage {
        guard message.role == .assistant else { return message }
        var content = message.content
        // Remove <think>…</think> blocks (potentially multiline).
        let thinkPattern = #/<think>[\s\S]*?<\/think>/#
        content = content.replacing(thinkPattern, with: "")
        // Double every backslash so LaTeX fragments survive the round-trip.
        content = content.replacingOccurrences(of: "\\", with: "\\\\")
        var sanitized = message
        sanitized.content = content
        return sanitized
    }

    /// Clears the conversation to start fresh (history included).
    func newConversation() {
        stopStreaming()
        messages.removeAll()
        errorMessage = nil
    }
}
