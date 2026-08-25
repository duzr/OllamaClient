//
//  MessageBubbleView.swift
//  OllamaClient
//
//  Renders a single chat message. User messages align trailing with an accent
//  background; assistant messages align leading with a neutral background.
//

import SwiftUI

struct MessageBubbleView: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }

            VStack(alignment: .leading, spacing: 0) {
                if message.isStreaming && message.content.isEmpty {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(message.content)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(bubbleBackground, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(isUser ? Color.white : Color.primary)

            if !isUser { Spacer(minLength: 40) }
        }
    }

    private var bubbleBackground: AnyShapeStyle {
        isUser ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary)
    }
}

#Preview {
    VStack {
        MessageBubbleView(message: ChatMessage(role: .user, content: "Hello there!"))
        MessageBubbleView(message: ChatMessage(role: .assistant, content: "Hi! How can I help you today?"))
        MessageBubbleView(message: ChatMessage(role: .assistant, content: "", isStreaming: true))
    }
    .padding()
    .frame(width: 400)
}
