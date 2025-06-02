//
//  ConnectionSettingsView.swift
//  PocketAI
//
//  Created by devon jerothe on 3/13/25.
//

import SwiftUI

struct ConnectionSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var connectionManager: ServiceContainer = .shared
    @State private var connectionTest: Bool? = nil
    @State private var isLoadingModels: Bool = false
    
    var hostBinding: Binding<String> {
        Binding<String>(
            get: { connectionManager.connectionSettings.host ?? "" },
            set: { connectionManager.connectionSettings.host = $0.isEmpty ? nil : $0 }
        )
    }
    
    var apiKeyBinding: Binding<String> {
        Binding<String>(
            get: { connectionManager.connectionSettings.apiKey ?? "" },
            set: { connectionManager.connectionSettings.apiKey = $0.isEmpty ? nil : $0 }
        )
    }
    
    var selectedModelBinding: Binding<String> {
        Binding<String>(
            get: { connectionManager.connectionSettings.selectedModel ?? "deepseek/deepseek-chat-v3-0324:free" },
            set: { connectionManager.connectionSettings.selectedModel = $0 }
        )
    }

    // Add computed bindings for slider values
    private var contextLengthBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(connectionManager.connectionSettings.contextLength ?? 4096) },
            set: { connectionManager.connectionSettings.contextLength = Int($0) }
        )
    }
    
    private var responseLengthBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(connectionManager.connectionSettings.responseLength ?? 300) },
            set: { connectionManager.connectionSettings.responseLength = Int($0) }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Connection Type", selection: $connectionManager.connectionSettings.connectionType) {
                        Text("KoboldAPI").tag(APITypeSelection.KoboldAPI)
                        Text("OpenRouter").tag(APITypeSelection.OpenRouter)
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    Text("Connection Type")
                }
                
                // Dynamic sections based on connection type
                connectionSpecificSections()
                
                Section {
                    HStack {
                        Button(action: {
                            Task {
                                connectionManager.saveConnectionSettings()
                                await connectionManager.connect()
                                self.connectionTest?.toggle()
                            }
                        }, label: {
                            Text("Connect")
                        })
                        
                        Spacer() 
                        if connectionManager.isLoadingConnection {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            if connectionManager.isConnected {
                                Text("Connected")
                                    .foregroundStyle(Color(UIColor.secondaryLabel))
                                    .padding() 
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.green)
                            } else {
                                Text("Disconnected")
                                    .foregroundStyle(Color(UIColor.secondaryLabel))
                                    .padding() 
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Color.red)
                            }
                        }
                    }
                
                    if connectionManager.isConnected {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Model Name")
                                Spacer()
                            }
                            Text(connectionManager.selectedModelName ?? "N/A")
                                .foregroundStyle(Color(UIColor.secondaryLabel))
                        }
                    }
                } header: {
                    Text("Connected LLM")
                }
            }
            .navigationTitle("Connection Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task {
                            connectionManager.saveConnectionSettings()
                            let connected = await connectionManager.waitForConnection()
                            if connected {
                                dismiss()
                            }
                        }
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                Task {                    
                    // Load available models if OpenRouter is selected
                    if connectionManager.connectionSettings.connectionType == .OpenRouter {
                        await loadAvailableModels()
                    }
                }
            }
            .onChange(of: connectionManager.connectionSettings.connectionType) { _, newValue in
                // Load models when switching to OpenRouter
                if newValue == .OpenRouter {
                    Task {
                        await loadAvailableModels()
                    }
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
        // KoboldAPI Settings
        Section {
            TextField("Host", text: hostBinding)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
            
            TextField("Port", value: $connectionManager.connectionSettings.port, format: .number)
                .keyboardType(.numberPad)
        } header: {
            Text("API Settings")
        } footer: {
            Text("Enter the host address and port number for your KoboldAPI connection.")
        }
        
        // Context and Response Length Settings for KoboldAPI
        Section {
            VStack(alignment: .leading) {
                HStack {
                    Text("Context Length")
                    Spacer()
                    Text("\(Int(contextLengthBinding.wrappedValue))")
                }
                Slider(value: contextLengthBinding, in: 1024...25600, step: 1024)
            }
            
            VStack(alignment: .leading) {
                HStack {
                    Text("Response Length")
                    Spacer()
                    Text("\(Int(responseLengthBinding.wrappedValue))")
                }
                Slider(value: responseLengthBinding, in: 120...3000, step: 60)
            }
        } header: {
            Text("Model Settings")
        } footer: {
            Text("Adjust the sliders to set the model's token limits. Maximum: 25,600 for context.")
        }
    }
    
    @ViewBuilder
    private func openRouterSettingsSections() -> some View {
        // OpenRouter Settings
        Section {
            SecureField("API Key", text: apiKeyBinding)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        } header: {
            Text("OpenRouter API")
        } footer: {
            Text("Enter your OpenRouter API key. You can get one from openrouter.ai")
        }
        
        Section {
            HStack {
                Text("Selected Model")
                Spacer()
                if isLoadingModels {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button("Refresh Models") {
                        Task {
                            await loadAvailableModels()
                        }
                    }
                    .font(.caption)
                }
            }
            
            if connectionManager.availableModels.isEmpty {
                Text("No Models Available")
            } else {
                Picker("Model", selection: selectedModelBinding) {
                    ForEach(connectionManager.availableModels, id: \.self.id) { model in
                        Text(model.name).tag(model.id)
                    }
                }
                .pickerStyle(.navigationLink)
            }
        } header: {
            Text("Model Selection")
        } footer: {
            Text("Select the OpenRouter model to use. You can manually enter a model name or refresh to load available models.")
        }

        Section {
            VStack(alignment: .leading) {
                HStack {
                    Text("Response Length")
                    Spacer()
                    Text("\(Int(responseLengthBinding.wrappedValue))")
                }
                Slider(value: responseLengthBinding, in: 120...3000, step: 60)
            }
        } header: {
            Text("Model Settings")
        } footer: {
            Text("Adjust the sliders to set the model's token limits.")
        }
    }
}
