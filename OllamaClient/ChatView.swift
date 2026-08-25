//
//  ChatView.swift
//  OllamaClient
//
//  The conversation transcript and message composer.
//

import SwiftUI

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            transcript
            Divider()
            composer
        }
        .navigationTitle(viewModel.selectedModel?.name ?? "OllamaClient")
        .toolbar {
            ToolbarItem {
                Button {
                    viewModel.newConversation()
                } label: {
                    Label("New Chat", systemImage: "square.and.pencil")
                }
                .help("Start a new conversation")
                .disabled(viewModel.messages.isEmpty)
            }
        }
    }

    // MARK: - Transcript

    private var transcript: some View {
        Group {
            if viewModel.messages.isEmpty {
                ContentUnavailableView {
                    Label("Start Chatting", systemImage: "bubble.left.and.bubble.right")
                } description: {
                    if viewModel.selectedModel == nil {
                        Text("Select a model in the sidebar to begin.")
                    } else {
                        Text("Send a message to \(viewModel.selectedModel!.name).")
                    }
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MessageBubbleView(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: lastMessageSignature) {
                        if let last = viewModel.messages.last {
                            withAnimation(.easeOut(duration: 0.15)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Changes whenever a new message is added or the streaming reply grows,
    /// so the transcript keeps scrolling to the bottom.
    private var lastMessageSignature: String {
        guard let last = viewModel.messages.last else { return "" }
        return "\(viewModel.messages.count)-\(last.content.count)"
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 8) {
                TextField(
                    "Message…",
                    text: $viewModel.draft,
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .padding(8)
                .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
                .onSubmit(sendIfPossible)
                .disabled(viewModel.selectedModel == nil)

                if viewModel.isStreaming {
                    Button(role: .destructive) {
                        viewModel.stopStreaming()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .help("Stop generating")
                } else {
                    Button {
                        viewModel.send()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(viewModel.canSend ? Color.accentColor : Color.secondary)
                    .disabled(!viewModel.canSend)
                    .help("Send")
                }
            }
        }
        .padding()
    }

    private func sendIfPossible() {
        if viewModel.canSend {
            viewModel.send()
        }
    }
}
