//
//  OllamaService.swift
//  OllamaClient
//
//  Thin async wrapper around the Ollama REST API. Mirrors the two operations
//  from the reference Python client: listing models (`GET /api/tags`) and
//  streaming a chat completion (`POST /api/chat`).
//

import Foundation

struct OllamaService {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Parses a user-entered host string into a base URL, tolerating a missing
    /// scheme and stripping any trailing slash (like the Python client does).
    func baseURL(from host: String) throws -> URL {
        var trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        if !trimmed.contains("://") {
            trimmed = "http://" + trimmed
        }
        guard let url = URL(string: trimmed), url.host != nil else {
            throw OllamaError.invalidHost(host)
        }
        return url
    }

    /// Fetches the list of models installed on the server (`GET /api/tags`).
    func listModels(host: String) async throws -> [OllamaModel] {
        let url = try baseURL(from: host).appendingPathComponent("api/tags")
        do {
            let (data, response) = try await session.data(from: url)
            try validate(response)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(TagsResponse.self, from: data).models
        } catch let error as OllamaError {
            throw error
        } catch {
            throw OllamaError.transport(error.localizedDescription)
        }
    }

    /// Streams a chat completion, yielding each new piece of text as it arrives.
    ///
    /// Ollama returns the response as one JSON object per line; we read the
    /// body line-by-line with `URLSession.bytes` so the reply can be shown as
    /// it is generated, just like the Python client's streamed output.
    func streamChat(
        host: String,
        model: String,
        messages: [ChatMessage]
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let url = try baseURL(from: host).appendingPathComponent("api/chat")
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONEncoder().encode(
                        ChatRequest(model: model, messages: messages, stream: true)
                    )

                    let (bytes, response) = try await session.bytes(for: request)
                    try validate(response)

                    let decoder = JSONDecoder()
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        guard let data = line.data(using: .utf8),
                              let chunk = try? decoder.decode(ChatStreamChunk.self, from: data)
                        else { continue }

                        if let content = chunk.message?.content, !content.isEmpty {
                            continuation.yield(content)
                        }
                        if chunk.done { break }
                    }
                    continuation.finish()
                } catch let error as OllamaError {
                    continuation.finish(throwing: error)
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: OllamaError.transport(error.localizedDescription))
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Throws an `OllamaError.server` for any non-2xx HTTP status.
    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw OllamaError.server(status: http.statusCode)
        }
    }
}
