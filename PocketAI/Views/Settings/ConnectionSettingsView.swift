//
//  ConnectionSettingsView.swift
//  PocketAI
//
//  Created by devon jerothe on 3/13/25.
//

import SwiftLLMSDK
import SwiftUI

struct ConnectionSettingsView: View {
    @Environment(ServiceContainer.self) private var serviceContainer
    @Environment(\.appTheme) private var appTheme

    @State private var isLoadingModels: Bool = false
    @State private var showModelSearch = false
    @State private var baseURLRefreshTask: Task<Void, Never>?

    private var connectionManager: ConnectionStatusManager {
        serviceContainer.getConnectionStatusManager()
    }

    private var hostBinding: Binding<String> {
        Binding(
            get: { connectionManager.connectionSettings.activeHost ?? "" },
            set: { connectionManager.updateActiveHost($0.isEmpty ? nil : $0) }
        )
    }

    private var portBinding: Binding<String> {
        Binding(
            get: {
                if let port = connectionManager.connectionSettings.activePort {
                    return "\(port)"
                }
                return ""
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    connectionManager.updateActivePort(nil)
                } else if let parsed = Int(trimmed) {
                    connectionManager.updateActivePort(parsed)
                }
                // Ignore non-numeric input; the field stays as the user typed until valid.
            }
        )
    }

    private var apiKeyBinding: Binding<String> {
        Binding(
            get: { connectionManager.connectionSettings.activeAPIKey ?? "" },
            set: { connectionManager.updateActiveAPIKey($0.isEmpty ? nil : $0) }
        )
    }

    private var selectedModelBinding: Binding<String> {
        Binding(
            get: {
                connectionManager.connectionSettings.activeSelectedModel ?? ""
            },
            set: { connectionManager.updateActiveSelectedModel($0.isEmpty ? nil : $0) }
        )
    }

    private var openAIBaseURLBinding: Binding<String> {
        Binding(
            get: { connectionManager.connectionSettings.openAISettings?.baseURL ?? "" },
            set: { updateOpenAISettings(\.baseURL, to: $0.isEmpty ? nil : $0) }
        )
    }

    private var openAIAPIKeyBinding: Binding<String> {
        Binding(
            get: { connectionManager.connectionSettings.activeAPIKey ?? "" },
            set: { connectionManager.updateActiveAPIKey($0.isEmpty ? nil : $0) }
        )
    }

    private var contextLengthBinding: Binding<Double> {
        Binding(
            get: { Double(connectionManager.connectionSettings.activeContextLength ?? 4096) },
            set: { connectionManager.updateActiveContextLength(Int($0)) }
        )
    }

    private var responseLengthBinding: Binding<Double> {
        Binding(
            get: { Double(connectionManager.connectionSettings.activeResponseLength ?? 300) },
            set: { connectionManager.updateActiveResponseLength(Int($0)) }
        )
    }

    private var selectedModelLabel: String {
        let selectedModelID = selectedModelBinding.wrappedValue
        return serviceContainer.availableModels.first { $0.id == selectedModelID }?.name
            ?? selectedModelID
    }

    private var openAISelectedModelLabel: String {
        let selectedModelID = selectedModelBinding.wrappedValue
        return serviceContainer.availableOpenAIModels.first { $0.id == selectedModelID }?
            .displayName ?? selectedModelID
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
                        Button("OpenAI Server") {
                            connectionManager.update(\.connectionType, to: .OpenAI)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Connection Type")
                                    .foregroundColor(appTheme.primaryText.color)
                                Text(connectionManager.connectionSettings.connectionType.rawValue)
                                    .font(.subheadline)
                                    .foregroundColor(appTheme.secondaryText.color)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(appTheme.secondaryText.color)
                        }
                    }
                    .buttonStyle(.plain)
                }

                SettingsCard("Generation") {
                    ThemedSliderRow(
                        title: "Response Length",
                        value: responseLengthBinding,
                        range: 120...3000,
                        step: 60,
                        displayValue: "\(Int(responseLengthBinding.wrappedValue))"
                    )
                }

                connectionSpecificSections()
            }
            .padding(16)
        }
        .background(appTheme.backgroundColor.color)
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Text("Status")
                    .foregroundColor(appTheme.primaryText.color.opacity(0.8))
                if serviceContainer.isLoading {
                    ProgressView()
                        .progressViewStyle(
                            CircularProgressViewStyle(tint: appTheme.primaryText.color)
                        )
                        .scaleEffect(0.7)
                    Text("Connecting...")
                        .foregroundColor(appTheme.primaryText.color.opacity(0.8))
                        .font(.subheadline)
                } else if connectionManager.connectionStatus == .failed {
                    Circle()
                        .fill(appTheme.destructiveAction.color)
                        .frame(width: 10, height: 10)
                    Text("Connection Failed")
                        .foregroundColor(appTheme.destructiveAction.color)
                        .font(.subheadline)
                } else {
                    Circle()
                        .fill(
                            serviceContainer.isConnected
                                ? appTheme.successColor.color : appTheme.destructiveAction.color
                        )
                        .frame(width: 10, height: 10)
                    Text(serviceContainer.isConnected ? "Connected" : "Disconnected")
                        .foregroundColor(
                            serviceContainer.isConnected
                                ? appTheme.successColor.color : appTheme.destructiveAction.color)
                }
                Spacer()
                Button {
                    Task {
                        await connectionManager.connect()
                    }
                } label: {
                    Text("Connect")
                        .foregroundColor(appTheme.primaryText.color)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(appTheme.primaryAction.color.opacity(0.6))
                        .clipShape(Capsule())
                        .contentShape(Capsule())
                        .glassEffect(
                            .regular.interactive(),
                            in: Capsule()
                        )
                        .animation(.easeInOut, value: serviceContainer.isLoading)
                }
                .buttonStyle(.plain)
                .disabled(serviceContainer.isLoading)
            }
            .padding()
            .background(.thinMaterial)
            .ignoresSafeArea(.keyboard)
        }
        .navigationTitle("Connection")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showModelSearch) {
            if connectionManager.connectionSettings.connectionType == .OpenAI {
                OpenRouterModelSearchView(
                    models: serviceContainer.availableOpenAIModels,
                    selectedModel: selectedModelBinding
                )
            } else {
                OpenRouterModelSearchView(
                    models: serviceContainer.availableModels,
                    selectedModel: selectedModelBinding
                )
            }
        }
        .onAppear {
            if usesRemoteModelPicker {
                Task {
                    await loadAvailableModels()
                }
            }
        }
        .onChange(of: connectionManager.connectionSettings.connectionType) {
            if usesRemoteModelPicker {
                Task {
                    await loadAvailableModels()
                }
            }
        }
        .onChange(of: connectionManager.connectionSettings.openAISettings?.baseURL) {
            scheduleOpenAIModelRefresh()
        }
    }

    private var usesRemoteModelPicker: Bool {
        connectionManager.connectionSettings.connectionType == .OpenRouter
            || connectionManager.connectionSettings.connectionType == .OpenAI
    }

    private func updateOpenAISettings<Value>(
        _ keyPath: WritableKeyPath<OpenAISettings, Value>,
        to value: Value
    ) {
        var settings = connectionManager.connectionSettings
        var openAISettings = settings.openAISettings ?? OpenAISettings()
        openAISettings[keyPath: keyPath] = value
        settings.openAISettings = openAISettings
        connectionManager.updateSettings(settings)
    }

    private func scheduleOpenAIModelRefresh() {
        baseURLRefreshTask?.cancel()

        guard connectionManager.connectionSettings.connectionType == .OpenAI,
            connectionManager.connectionSettings.openAISettings?.baseURL?.isEmpty == false
        else {
            return
        }

        baseURLRefreshTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else {
                return
            }
            await loadAvailableModels()
        }
    }

    private func loadAvailableModels() async {
        guard usesRemoteModelPicker else {
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
        case .OpenAI:
            openAISettingsSections()
        }
    }

    @ViewBuilder
    private func koboldAPISettingsSections() -> some View {
        SettingsCard("KoboldAPI") {
            ThemedTextField(
                title: "Host",
                placeholder: "e.g., 127.0.0.1",
                text: hostBinding,
                keyboardType: .URL,
                autocapitalization: .never
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Port")
                    .foregroundColor(appTheme.primaryText.color)
                TextField("", text: portBinding)
                    .keyboardType(.numberPad)
                    .styledFormField()
            }

            ThemedSliderRow(
                title: "Context Limit",
                value: contextLengthBinding,
                range:
                    1024...Double(
                        connectionManager.connectionSettings.activeMaxContextLength
                            ?? connectionManager.maxContextLength),
                step: 1024,
                displayValue: "\(Int(contextLengthBinding.wrappedValue))"
            )
        }
    }

    @ViewBuilder
    private func openRouterSettingsSections() -> some View {
        SettingsCard("OpenRouter") {
            ThemedSecureField(
                title: "API Key",
                placeholder: "Enter your API key",
                text: apiKeyBinding
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Selected Model")
                    .foregroundColor(appTheme.primaryText.color)
                if isLoadingModels {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .styledFormField()
                } else {
                    Button {
                        Task {
                            await loadAvailableModels()
                            showModelSearch = true
                        }
                    } label: {
                        HStack {
                            Text(selectedModelLabel)
                                .foregroundColor(appTheme.primaryText.color)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(appTheme.borderColor.color)
                        }
                    }
                    .buttonStyle(.plain)
                    .styledFormField()
                }
            }
        }
    }

    @ViewBuilder
    private func openAISettingsSections() -> some View {
        SettingsCard("OpenAI Server") {
            ThemedTextField(
                title: "Base URL",
                placeholder: "e.g., https://api.openai.com/v1",
                text: openAIBaseURLBinding,
                keyboardType: .URL,
                autocapitalization: .never
            )

            ThemedSecureField(
                title: "API Key",
                placeholder: "Enter your API key",
                text: openAIAPIKeyBinding
            )

            ThemedSliderRow(
                title: "Context Limit",
                value: contextLengthBinding,
                range:
                    1024...Double(
                        connectionManager.connectionSettings.activeMaxContextLength ?? 256000),
                step: 1024,
                displayValue: "\(Int(contextLengthBinding.wrappedValue))"
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Selected Model")
                    .foregroundColor(appTheme.primaryText.color)
                if isLoadingModels {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .styledFormField()
                } else {
                    Button {
                        Task {
                            await loadAvailableModels()
                            showModelSearch = true
                        }
                    } label: {
                        HStack {
                            Text(
                                openAISelectedModelLabel.isEmpty
                                    ? "Select a model" : openAISelectedModelLabel
                            )
                            .foregroundColor(appTheme.primaryText.color)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(appTheme.borderColor.color)
                        }
                    }
                    .buttonStyle(.plain)
                    .styledFormField()
                }
            }
        }
    }
}

struct OpenRouterModelSearchView<Model: ModelPickerItem>: View {
    let models: [Model]
    @Binding var selectedModel: String
    @Environment(\.appTheme) private var appTheme
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filteredModels: [Model] {
        models.filter { model in
            search.isEmpty || model.searchableText.localizedCaseInsensitiveContains(search)
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
                        Text(model.displayName)
                            .foregroundColor(appTheme.primaryText.color)

                        Text(model.id)
                            .font(.caption)
                            .foregroundColor(appTheme.secondaryText.color)
                            .lineLimit(1)
                    }

                    Spacer()

                    if selectedModel == model.id {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(appTheme.tintColor.color)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(appTheme.backgroundColor.color)
        .navigationTitle("Select Model")
        .searchable(text: $search, prompt: "Search models")
    }
}
