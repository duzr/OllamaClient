//
//  OllamaModels.swift
//  OllamaClient
//
//  Data types for talking to an Ollama server's REST API.
//

import Foundation

/// A model installed on the Ollama server, as returned by `GET /api/tags`.
struct OllamaModel: Codable, Identifiable, Hashable {
    let name: String
    let size: Int64
    let modifiedAt: Date?

    var id: String { name }

    /// Human-readable size in gigabytes, matching the Python client's display.
    var sizeInGB: Double {
        Double(size) / (1024 * 1024 * 1024)
    }

    var formattedSize: String {
        String(format: "%.1f GB", sizeInGB)
    }

    enum CodingKeys: String, CodingKey {
        case name
        case size
        case modifiedAt = "modified_at"
    }
}

/// Wrapper for the `GET /api/tags` response: `{"models": [...]}`.
struct TagsResponse: Codable {
    let models: [OllamaModel]
}

/// The role of a chat participant, mirroring Ollama's `/api/chat` message roles.
enum ChatRole: String, Codable {
    case system
    case user
    case assistant
}

/// A single message in a conversation. Used both for display and for the wire
/// payload sent to `/api/chat`.
struct ChatMessage: Identifiable {
    let id = UUID()
    let role: ChatRole
    var content: String

    /// True while the assistant reply is still streaming in.
    var isStreaming: Bool = false
}

/// Request body for `POST /api/chat`.
struct ChatRequest: Encodable {
    let model: String
    let messages: [Wire]
    let stream: Bool

    /// Minimal on-the-wire representation of a message (role + content only).
    struct Wire: Encodable {
        let role: String
        let content: String
    }

    init(model: String, messages: [ChatMessage], stream: Bool = true) {
        self.model = model
        self.messages = messages.map { Wire(role: $0.role.rawValue, content: $0.content) }
        self.stream = stream
    }
}

/// A single streamed chunk from `/api/chat`. Ollama sends one JSON object per
/// line; each carries a small piece of the reply plus a `done` flag.
struct ChatStreamChunk: Decodable {
    struct Message: Decodable {
        let content: String
    }

    let message: Message?
    let done: Bool
}

/// Errors surfaced to the UI in a user-friendly way.
enum OllamaError: LocalizedError {
    case invalidHost(String)
    case server(status: Int)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidHost(let host):
            return "\"\(host)\" isn't a valid server address."
        case .server(let status):
            return "The Ollama server returned an error (HTTP \(status))."
        case .transport(let detail):
            return "Could not reach the Ollama server: \(detail)"
        }
    }
}
