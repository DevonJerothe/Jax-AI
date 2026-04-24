//
//  ConnectionSettingsView.swift
//  PocketAI
//
//  Created by devon jerothe on 3/13/25.
//

import SwiftUI

struct ConnectionSettingsView: View {
    @Environment(ServiceContainer.self) private var serviceContainer

    @State private var isLoadingModels: Bool = false

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

    var body: some View {
        ScrollView {
            VStack {
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

                Menu {
                    Button("KoboldAPI") {
                        connectionManager.update(\.connectionType, to: .KoboldAPI)
                    }
                    Button("OpenRouter") {
                        connectionManager.update(\.connectionType, to: .OpenRouter)
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
                .buttonStyle(.plain)
                .padding(.horizontal, 16)

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

                connectionSpecificSections()
            }
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
                .disabled(serviceContainer.isLoading)
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
                Slider(
                    value: contextLengthBinding,
                    in: 1024...Double(connectionManager.maxContextLength),
                    step: 1024
                )
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

            VStack(alignment: .leading, spacing: 8) {
                Text("Selected Model")
                    .foregroundColor(.primary)
                if isLoadingModels {
                    ProgressView()
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6).opacity(0.6))
                        .cornerRadius(12)
                } else {
                    Picker("Selected Model", selection: selectedModelBinding) {
                        ForEach(serviceContainer.availableModels, id: \.id) { model in
                            Text(model.name).tag(model.id)
                        }
                    }
                    .tint(.secondary)
                    .pickerStyle(.navigationLink)
                    .padding()
                    .background(Color(.systemGray6).opacity(0.6))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
