//
//  ChatBubbleView.swift
//  PocketAI
//
//  Created by devon jerothe on 3/13/25.
//

import SwiftUI

struct ConnectionSettingsView: View {

    @Environment(\.presentationMode) var presentationMode

    @State var viewModel: ConnectionSettingsViewModel = .init()

    var hostBinding: Binding<String> {
        Binding<String>(
            get: { viewModel.host ?? "" },
            set: { viewModel.host = $0.isEmpty ? nil : $0 }
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Connection Type")
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Picker("Connection Type", selection: $viewModel.apiTypeSelection) {
                    Text("KoboldAPI").tag(APITypeSelection.KoboldAPI)
                }
//                Form {
                    Section(header: Text("API Settings").foregroundStyle(.white)) {
                        TextField("Host", text: hostBinding)
                            .textFieldStyle(.plain)
                            .padding()
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.white, lineWidth: 0.5)
                            )
                            .padding(.bottom, 20)
                        TextField("Port", value: $viewModel.port, formatter: NumberFormatter())
                            .textFieldStyle(.plain)
                            .padding()
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.white, lineWidth: 0.5)
                            )
                            .padding(.bottom, 20)
                    }
                    Section(header: Text("Model Settings").foregroundStyle(.white)) {
                        TextField(
                            "Context Length", value: $viewModel.contextLength,
                            formatter: NumberFormatter())
                        .textFieldStyle(.plain)
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.white, lineWidth: 0.5)
                        )
                        .padding(.bottom, 20)
                        TextField(
                            "Response Length", value: $viewModel.responseLength,
                            formatter: NumberFormatter())
                        .textFieldStyle(.plain)
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.white, lineWidth: 0.5)
                        )
                        .padding(.bottom, 20)
                    }
//                }

                Spacer()

                Button(
                    action: {
                        Task {
                            await viewModel.connect()
                        }
                    },
                    label: {
                        Text("Save")
                            .padding()
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .cornerRadius(15)
                            .padding(50)
                    })
            }
        }
    }
}
