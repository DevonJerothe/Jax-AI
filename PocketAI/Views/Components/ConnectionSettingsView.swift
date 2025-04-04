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
    
    var hostBinding: Binding<String> {
        Binding<String>(
            get: { connectionManager.connectionSettings.host ?? "" },
            set: { connectionManager.connectionSettings.host = $0.isEmpty ? nil : $0 }
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
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    Text("Connection Type")
                }
                
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
                    Text("Enter the host address and port number for your API connection.")
                }
                
                Section {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Context Length")
                            Spacer()
                            Text("\(Int(contextLengthBinding.wrappedValue))")
                                .monospacedDigit()
                        }
                        Slider(value: contextLengthBinding, in: 1024...25600, step: 1024)
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Response Length")
                            Spacer()
                            Text("\(Int(responseLengthBinding.wrappedValue))")
                                .monospacedDigit()
                        }
                        Slider(value: responseLengthBinding, in: 120...3000, step: 60)
                    }
                } header: {
                    Text("Model Settings")
                } footer: {
                    Text("Adjust the sliders to set the model's token limits. Maximum: 16,000.")
                }
                
                Section {
                    HStack {
                        Button(action: {
                            Task {
                                connectionTest = await connectionManager.connectToLanguageModel()
                            }
                        }, label: {
                            Text("Test Connection")
                        })
                        .buttonStyle(.bordered)
                        
                        if let connectionTest = connectionTest {
                            Image(systemName: connectionTest ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(connectionTest ? Color.green : Color.red)
                        }
                    }

                    if connectionManager.isConnected {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Model Name")
                                Spacer()
                            }
                            Text(connectionManager.modelName ?? "N/A")
                                .foregroundStyle(Color(UIColor.label))
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
                            if connectionManager.isConnected == false,
                               await connectionManager.connectToLanguageModel()
                            {
                                connectionManager.saveConnectionSettings()
                                dismiss()
                            }
                            connectionManager.saveConnectionSettings()
                            dismiss()
                        }
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}
