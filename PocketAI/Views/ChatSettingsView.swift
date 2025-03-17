//
//  ChatSettingsView.swift
//  PocketAI
//
//  Created by devon jerothe on 3/12/25.
//

import SwiftUI

struct ChatSettingsView: View {
    var viewModel: ChatViewModel

    @State var systemPrompt: String
    @State var initialMessage: String

    init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
        _systemPrompt = State(initialValue: viewModel.model.memory)
        _initialMessage = State(initialValue: viewModel.model.firstMessage)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack {
                    Text("Enter a system prompt")
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextEditor(text: $systemPrompt)
                        .frame(height: min(200, CGFloat(systemPrompt.count) / 10 * 20))
                        .background(Color(UIColor.systemGray5))
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white, lineWidth: 0.5)
                        )
                }
                .padding(.vertical, 10)

                VStack {
                    Text("Enter a initial message")
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextEditor(text: $initialMessage)
                        .frame(height: min(200, CGFloat(initialMessage.count) / 10 * 20))
                        .background(Color(UIColor.systemGray5))
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white, lineWidth: 0.5)
                        )
                }
                .padding(.vertical, 10)

                Spacer()

                Button(action: {
                    self.viewModel.updateChatSettings(
                        memory: systemPrompt,
                        firstMessage: initialMessage
                    )
                }) {
                    // Save results to model and close sheet
                    Text("Save")
                        .padding()
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(15)
                        .padding(50)
                }
            }
            .padding()
        }
    }
}
