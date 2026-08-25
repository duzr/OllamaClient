//
//  ContentView.swift
//  OllamaClient
//
//  Top-level layout: a sidebar for choosing the server and model, and a chat
//  transcript on the right.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = ChatViewModel()

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        } detail: {
            ChatView(viewModel: viewModel)
        }
        .task {
            // Fetch the model list once on launch, like the Python client does
            // before starting a chat.
            await viewModel.loadModels()
        }
    }
}

#Preview {
    ContentView()
}
