//
//  ConnectionSettingsView.swift
//  PocketAI
//
//  Created by devon jerothe on 3/13/25.
//

import SwiftUI

struct ConnectionSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ConnectionSettingsViewModel = .init()

    var hostBinding: Binding<String> {
        Binding<String>(
            get: { viewModel.host ?? "" },
            set: { viewModel.host = $0.isEmpty ? nil : $0 }
        )
    }

    // Add computed bindings for slider values
    private var contextLengthBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(viewModel.contextLength ?? 2048) },
            set: { viewModel.contextLength = Int($0) }
        )
    }
    
    private var responseLengthBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(viewModel.responseLength ?? 512) },
            set: { viewModel.responseLength = Int($0) }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Connection Type", selection: $viewModel.apiTypeSelection) {
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
                    
                    TextField("Port", value: $viewModel.port, format: .number)
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
                        Slider(value: contextLengthBinding, in: 512...16000, step: 4096)
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Response Length")
                            Spacer()
                            Text("\(Int(responseLengthBinding.wrappedValue))")
                                .monospacedDigit()
                        }
                        Slider(value: responseLengthBinding, in: 128...16000, step: 256)
                    }
                } header: {
                    Text("Model Settings")
                } footer: {
                    Text("Adjust the sliders to set the model's token limits. Maximum: 16,000.")
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
                            await viewModel.connect()
                            dismiss()
                        }
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}
