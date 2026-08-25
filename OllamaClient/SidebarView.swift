//
//  SidebarView.swift
//  OllamaClient
//
//  Server address entry plus the list of models available on that server.
//

import SwiftUI

struct SidebarView: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            serverSection

            Divider()

            modelList
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Server address

    private var serverSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Server")
                .font(.headline)

            HStack(spacing: 6) {
                TextField("http://localhost:11434", text: $viewModel.host)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { reload() }

                Button {
                    reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh model list")
                .disabled(viewModel.isLoadingModels)
            }

            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
    }

    // MARK: - Model list

    private var modelList: some View {
        Group {
            if viewModel.isLoadingModels {
                VStack {
                    ProgressView()
                    Text("Loading models…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.models.isEmpty {
                ContentUnavailableView(
                    "No Models",
                    systemImage: "shippingbox",
                    description: Text("No models were found on this server.")
                )
            } else {
                List(viewModel.models, selection: $viewModel.selectedModel) { model in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.name)
                                .fontWeight(.medium)
                            Text(model.formattedSize)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .tag(model)
                }
            }
        }
    }

    private func reload() {
        Task { await viewModel.loadModels() }
    }
}
