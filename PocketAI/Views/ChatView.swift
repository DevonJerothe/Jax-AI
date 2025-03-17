//
//  ContentView.swift
//  PocketAI
//
//  Created by devon jerothe on 3/11/25.
//

import MarkdownUI
import SwiftUI
import SwiftLLMSDK


struct ChatView: View {
    @State var viewModel: ChatViewModel
    @State var textPrompt: String = ""

    init(chatModel: ChatModel, llm: KoboldAPI?) {
        self.viewModel = ChatViewModel(chatModel: chatModel, llm: llm)
    }

    var body: some View {
        VStack {
            ChatViewHeader(viewModel: viewModel)

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
        .onAppear() {
            self.viewModel.updateScrollView.toggle()
        }
        .navigationBarHidden(true)
    }
}

#Preview {
    ChatView(chatModel: ChatModel(chatTitle: "Test Chat"), llm: KoboldAPI(urlSession: URLSession.shared, host: "localhost", port: 11434))
}
