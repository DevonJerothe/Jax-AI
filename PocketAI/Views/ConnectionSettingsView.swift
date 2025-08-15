//
//  ConnectionSettingsView.swift
//  PocketAI
//
//  Created by devon jerothe on 3/13/25.
//

import SwiftUI


struct ConnectionSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    private var connectionManager: ServiceContainer = .shared
    @State private var connectionTest: Bool? = nil
    @State private var isLoadingModels: Bool = false
    
    var hostBinding: Binding<String> {
        Binding<String>(
            get: { connectionManager.connectionSettings.host ?? "" },
            set: { newValue in
                let currentHost = connectionManager.connectionSettings.host ?? ""
                // Only disconnect if the value actually changed
                if currentHost != newValue {
                    connectionManager.getLanguageModelService().isConnected = false
                }
                connectionManager.connectionSettings.host = newValue.isEmpty ? nil : newValue
            }
        )
    }

    var portBinding: Binding<Int> {
        Binding<Int>(
            get: { connectionManager.connectionSettings.port ?? 5000 },
            set: { newValue in
                let currentPort = connectionManager.connectionSettings.port ?? 5000
                // Only disconnect if the value actually changed
                if currentPort != newValue {
                    connectionManager.getLanguageModelService().isConnected = false
                }
                connectionManager.connectionSettings.port = newValue
            }
        )
    }
    
    var apiKeyBinding: Binding<String> {
        Binding<String>(
            get: { connectionManager.connectionSettings.apiKey ?? "" },
            set: { newValue in
                let currentApiKey = connectionManager.connectionSettings.apiKey ?? ""
                // Only disconnect if the value actually changed
                if currentApiKey != newValue {
                    connectionManager.getLanguageModelService().isConnected = false
                }
                connectionManager.connectionSettings.apiKey = newValue.isEmpty ? nil : newValue
            }
        )
    }
    
    var selectedModelBinding: Binding<String> {
        Binding<String>(
            get: { connectionManager.connectionSettings.selectedModel ?? "deepseek/deepseek-chat-v3-0324:free" },
            set: { newValue in
                let currentModel = connectionManager.connectionSettings.selectedModel ?? "deepseek/deepseek-chat-v3-0324:free"
                // Only disconnect if the value actually changed
                if currentModel != newValue {
                    connectionManager.getLanguageModelService().isConnected = false
                }
                connectionManager.connectionSettings.selectedModel = newValue
            }
        )
    }

    // Add computed bindings for slider values
    private var contextLengthBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(connectionManager.connectionSettings.contextLength ?? 4096) },
            set: {
                connectionManager.connectionSettings.contextLength = Int($0)
                connectionManager.saveConnectionSettings()
            }
        )
    }
    
    private var responseLengthBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(connectionManager.connectionSettings.responseLength ?? 300) },
            set: {
                connectionManager.connectionSettings.responseLength = Int($0)
                connectionManager.saveConnectionSettings()
            }
        )
    }
    
    var body: some View {
        ScrollView {
            VStack {
                // Connection Type and Response Length Slider 
                HStack {
                    Text("Connection")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Spacer() 
                }
                .padding(.top, 24)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                // Connection Type Picker 
                Menu {
                    Button("KoboldAPI") {
                        connectionManager.connectionSettings.connectionType = .KoboldAPI
                    }
                    Button("OpenRouter") {
                        connectionManager.connectionSettings.connectionType = .OpenRouter
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
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
                    .padding()
                    .background(Color(.systemGray6).opacity(0.6))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 16)

                // Response Length Slider 
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
                .padding()
                .background(Color(.systemGray6).opacity(0.6))
                .cornerRadius(12)
                .padding(.horizontal, 16)

                // Connection Specific Settings
                connectionSpecificSections()
            }

        }
        .scrollDismissesKeyboard(.immediately)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Text("Status")
                    .foregroundColor(.primary.opacity(0.8))
                if connectionManager.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                        .scaleEffect(0.7)
                    Text("Connecting...")
                        .foregroundColor(.primary.opacity(0.8))
                        .font(.subheadline)
                } else {
                    Circle()
                        .fill(connectionManager.isConnected ? .green : .red)
                        .frame(width: 10, height: 10)
                    Text(connectionManager.isConnected ? "Connected" : "Disconnected")
                        .foregroundColor(connectionManager.isConnected ? .green : .red)
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
                        .animation(.easeInOut, value: connectionManager.isLoading)
                }
                .disabled(connectionManager.isLoading)
            }
            .padding()
            .background(.thinMaterial)
            .ignoresSafeArea(.keyboard)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
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
    
    // TODO: This really should not be here. ViewModel may be necessary. 
    private func loadAvailableModels() async {
        guard connectionManager.connectionSettings.connectionType == .OpenRouter else { return }
        
        await MainActor.run {
            isLoadingModels = true
        }
        
        let languageService = connectionManager.getLanguageModelService()
        await languageService.getAvailableModels()
        
        await MainActor.run {
            isLoadingModels = false
        }
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
        VStack(spacing: 18) {
            HStack {
                Text("KoboldAPI")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer() 
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            VStack(alignment: .leading, spacing: 8) {
                Text("Host")
                    .foregroundColor(.primary)
                TextField("", text: hostBinding, prompt: Text("e.g., 127.0.0.1"))
                    .keyboardType(.URL)
                    .padding()
                    .background(Color(.systemGray6).opacity(0.6))
                    .cornerRadius(12)
            }
            .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 8) {
                Text("Port")
                    .foregroundColor(.primary)
                TextField("", value: portBinding, format: .number.grouping(.never))
                    .keyboardType(.numberPad)
                    .padding()
                    .background(Color(.systemGray6).opacity(0.6))
                    .cornerRadius(12)
            }
            .padding(.horizontal, 16)

            VStack(alignment: .leading) {
                HStack {
                    Text("Context Limit")
                        .foregroundColor(.primary)
                    Spacer() 
                    Text("\(Int(contextLengthBinding.wrappedValue))")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
                Slider(value: contextLengthBinding, in: 1024...Double(connectionManager.maxContextLength ?? 25600), step: 1024)
            }
            .padding()
            .background(Color(.systemGray6).opacity(0.6))
            .cornerRadius(12)
            .padding(.horizontal, 16)
        }
    }
    
    @ViewBuilder
    private func openRouterSettingsSections() -> some View {
        VStack(spacing: 18) {
            HStack {
                Text("OpenRouter")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer() 
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            VStack(alignment: .leading, spacing: 8) {
                Text("API Key")
                    .foregroundColor(.primary)
                SecureField("Enter your API key", text: apiKeyBinding)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding()
                    .background(Color(.systemGray6).opacity(0.6))
                    .cornerRadius(12)
            }
            .padding(.horizontal, 16)

            // Model Selection Picker 
            VStack(alignment: .leading, spacing: 8) {
                Text("Selected Model")
                    .foregroundColor(.primary)
                Picker("Selected Model", selection: selectedModelBinding) {
                    ForEach(connectionManager.availableModels, id: \.self.id) { model in
                        Text(model.name).tag(model.id)
                    }
                }
                .tint(.secondary)
                .pickerStyle(.navigationLink)
                .padding()
                .background(Color(.systemGray6).opacity(0.6))
                .cornerRadius(12)
            }
            .padding(.horizontal, 16)
        }
    }
}
