//
//  ConnectionSettingsView.swift
//  PocketAI
//
//  Created by devon jerothe on 3/13/25.
//

import SwiftUI
import SwiftLLMSDK

struct ConnectionSettingsView: View {
    @Environment(ServiceContainer.self) private var serviceContainer

    @State private var isLoadingModels: Bool = false
    @State private var showModelSearch = false

    private var connectionManager: ConnectionStatusManager {
        serviceContainer.getConnectionStatusManager()
    }

    private var hostBinding: Binding<String> {
        Binding(
            get: { connectionManager.connectionSettings.host ?? "" },
            set: { connectionManager.update(\.host, to: $0.isEmpty ? nil : $0) }
        )
    }

    private var portBinding: Binding<Int> {
        Binding(
            get: { connectionManager.connectionSettings.port ?? 5000 },
            set: { connectionManager.update(\.port, to: $0) }
        )
    }

    private var apiKeyBinding: Binding<String> {
        Binding(
            get: { connectionManager.connectionSettings.apiKey ?? "" },
            set: { connectionManager.update(\.apiKey, to: $0.isEmpty ? nil : $0) }
        )
    }

    private var selectedModelBinding: Binding<String> {
        Binding(
            get: { connectionManager.connectionSettings.selectedModel ?? "deepseek/deepseek-chat-v3-0324:free" },
            set: { connectionManager.update(\.selectedModel, to: $0) }
        )
    }

    private var contextLengthBinding: Binding<Double> {
        Binding(
            get: { Double(connectionManager.connectionSettings.contextLength ?? 4096) },
            set: { connectionManager.update(\.contextLength, to: Int($0)) }
        )
    }

    private var responseLengthBinding: Binding<Double> {
        Binding(
            get: { Double(connectionManager.connectionSettings.responseLength ?? 300) },
            set: { connectionManager.update(\.responseLength, to: Int($0)) }
        )
    }

    private var selectedModelLabel: String {
        let selectedModelID = selectedModelBinding.wrappedValue
        return serviceContainer.availableModels.first { $0.id == selectedModelID }?.name ?? selectedModelID
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsCard("Connection") {
                    Menu {
                        Button("KoboldAPI") {
                            connectionManager.update(\.connectionType, to: .KoboldAPI)
                        }
                        Button("OpenRouter") {
                            connectionManager.update(\.connectionType, to: .OpenRouter)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Connection Type")
                                    .foregroundColor(.primary)
                                Text(connectionManager.connectionSettings.connectionType.rawValue)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                SettingsCard("Generation") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Response Length")
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(Int(responseLengthBinding.wrappedValue))")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                        Slider(value: responseLengthBinding, in: 120...3000, step: 60)
                    }
                }

                connectionSpecificSections()
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.immediately)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Text("Status")
                    .foregroundColor(.primary.opacity(0.8))
                if serviceContainer.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                        .scaleEffect(0.7)
                    Text("Connecting...")
                        .foregroundColor(.primary.opacity(0.8))
                        .font(.subheadline)
                } else {
                    Circle()
                        .fill(serviceContainer.isConnected ? .green : .red)
                        .frame(width: 10, height: 10)
                    Text(serviceContainer.isConnected ? "Connected" : "Disconnected")
                        .foregroundColor(serviceContainer.isConnected ? .green : .red)
                }
                Spacer()
                Button {
                    Task {
                        await connectionManager.connect()
                    }
                } label: {
                    Text("Connect")
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.secondary)
                        .cornerRadius(20)
                        .animation(.easeInOut, value: serviceContainer.isLoading)
                }
                .glassEffect(
                    .regular.interactive(), 
                    in: Capsule()
                )
                .disabled(serviceContainer.isLoading)
            }
            .padding()
            .background(.thinMaterial)
            .ignoresSafeArea(.keyboard)
        }
        .navigationTitle("Connection")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showModelSearch) {
            OpenRouterModelSearchView(
                models: serviceContainer.availableModels,
                selectedModel: selectedModelBinding
            )
        }
        .onAppear {
            if connectionManager.connectionSettings.connectionType == .OpenRouter {
                Task {
                    await loadAvailableModels()
                }
            }
        }
        .onChange(of: connectionManager.connectionSettings.connectionType) {
            if connectionManager.connectionSettings.connectionType == .OpenRouter {
                Task {
                    await loadAvailableModels()
                }
            }
        }
    }

    private func loadAvailableModels() async {
        guard connectionManager.connectionSettings.connectionType == .OpenRouter else {
            return
        }

        isLoadingModels = true
        await connectionManager.refreshAvailableModels()
        isLoadingModels = false
    }

    @ViewBuilder
    private func connectionSpecificSections() -> some View {
        switch connectionManager.connectionSettings.connectionType {
        case .KoboldAPI:
            koboldAPISettingsSections()
        case .OpenRouter:
            openRouterSettingsSections()
        }
    }

    @ViewBuilder
    private func koboldAPISettingsSections() -> some View {
        SettingsCard("KoboldAPI") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Host")
                    .foregroundColor(.primary)
                TextField("", text: hostBinding, prompt: Text("e.g., 127.0.0.1"))
                    .keyboardType(.URL)
                    .styledFormField()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Port")
                    .foregroundColor(.primary)
                TextField("", value: portBinding, format: .number.grouping(.never))
                    .keyboardType(.numberPad)
                    .styledFormField()
            }

            VStack(alignment: .leading) {
                HStack {
                    Text("Context Limit")
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(Int(contextLengthBinding.wrappedValue))")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
                Slider(
                    value: contextLengthBinding,
                    in: 1024...Double(connectionManager.maxContextLength),
                    step: 1024
                )
            }
        }
    }

    @ViewBuilder
    private func openRouterSettingsSections() -> some View {
        SettingsCard("OpenRouter") {
            VStack(alignment: .leading, spacing: 8) {
                Text("API Key")
                    .foregroundColor(.primary)
                SecureField("Enter your API key", text: apiKeyBinding)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .styledFormField()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Selected Model")
                    .foregroundColor(.primary)
                if isLoadingModels {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .styledFormField()
                } else {
                    Button {
                        showModelSearch = true
                    } label: {
                        HStack {
                            Text(selectedModelLabel)
                                .foregroundColor(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .styledFormField()
                }
            }
        }
    }
}

struct OpenRouterModelSearchView: View {
    let models: [OpenRouterModel]
    @Binding var selectedModel: String
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filteredModels: [OpenRouterModel] {
        models.filter { model in
            search.isEmpty ||
                model.name.localizedCaseInsensitiveContains(search) ||
                model.id.localizedCaseInsensitiveContains(search) ||
                model.description.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        List(filteredModels, id: \.id) { model in
            Button {
                selectedModel = model.id
                dismiss()
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.name)
                            .foregroundColor(.primary)

                        Text(model.id)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if selectedModel == model.id {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Select Model")
        .searchable(text: $search, prompt: "Search models")
    }
}
