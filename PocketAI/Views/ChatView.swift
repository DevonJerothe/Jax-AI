//
//  ContentView.swift
//  PocketAI
//
//  Created by devon jerothe on 3/11/25.
//

import MarkdownUI
import SwiftLLMSDK
import SwiftUI

struct ChatView: View {
    @Environment(\.dismiss) var dismiss

    @State var viewModel: ChatViewModel
    @State var textPrompt: String = ""

    init(chatModel: ChatModel) {
        self.viewModel = ChatViewModel.create(chatModel: chatModel)
    }

    var body: some View {
        VStack {
            ChatViewHeader(
                leadingButtonIcon: viewModel.selectionModeActive
                    ? "trash.fill" : "arrow.left",
                trailingButtonIcon: viewModel.selectionModeActive
                    ? "xmark" : "list.dash",
                title: viewModel.model.chatTitle,
                leadingButtonAction: {
                    if viewModel.selectionModeActive {
                        Task {
                            await viewModel.deleteMessages()
                        }
                    } else {
                        dismiss()
                    }
                },
                trailingButtonAction: {
                    if viewModel.selectionModeActive {
                        viewModel.cancelDeleteMessages()
                    } else {
                        viewModel.showSettings.toggle()
                    }
                }
            )

            ScrollViewReader { proxy in
                ScrollView {
                    ForEach(viewModel.model.messages, id: \.self) { message in
                        HStack {
                            if viewModel.selectionModeActive {
                                SelectionCircle(
                                    isSelected: viewModel.selectedMessages
                                        .contains(message)
                                )
                                .transition(
                                    .asymmetric(
                                        insertion: .scale.combined(
                                            with: .opacity),
                                        removal: .scale.combined(with: .opacity)
                                    )
                                )
                            }

                            ChatBubbleView(
                                message: message, viewModel: viewModel
                            )
                            .padding(.bottom, 8)
                            .id(message)
                            .onLongPressGesture {
                                if !viewModel.selectionModeActive {
                                    viewModel.selectionModeActive = true
                                    viewModel.toggleSelection(message)
                                }
                            }
                            .onTapGesture {
                                if viewModel.selectionModeActive {
                                    viewModel.toggleSelection(message)
                                }
                            }
                        }
                        .animation(
                            .spring(response: 0.3),
                            value: viewModel.selectionModeActive)
                    }
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.immediately)
                .onChange(
                    of: viewModel.updateScrollView,
                    ({
                        withAnimation {
                            proxy.scrollTo(
                                viewModel.model.messages.last, anchor: .bottom)
                        }
                    }))
            }
            Spacer()

            HStack {
                Image(systemName: "trash.fill")
                    .onTapGesture {
                        viewModel.clearChat()
                    }
                TextField("Type a message...", text: $textPrompt)
                    .padding()
                    .background(Color(UIColor.systemGray5))
                    .cornerRadius(14)
                    .onSubmit {
                        let prompText = self.textPrompt
                        self.textPrompt = ""
                        Task {
                            await self.viewModel.sendMessage(prompt: prompText)
                        }
                    }
                    .disabled(viewModel.selectionModeActive)
            }
        }
        .padding()
        .sheet(isPresented: $viewModel.showSettings) {
            ChatSettingsView(viewModel: self.viewModel)
        }
        .onAppear {
            self.viewModel.updateScrollView.toggle()

            // Check if the connection is active. For existing chats, the connection may have been lost.
            self.viewModel.checkConnection()
        }
        .navigationBarHidden(true)
    }
}

#Preview {
    ChatView(chatModel: ChatModel(chatTitle: "Test Chat"))
}
