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
    
    // ---- Add State for Keyboard Height ----
    @State private var keyboardHeight: CGFloat = 0
    // ---- Add State for tracking keyboard visibility ----
    @State private var isKeyboardVisible: Bool = false

    init(chatModel: ChatModel) {
        self.viewModel = ChatViewModel.create(chatModel: chatModel)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                
                // Connection warning
                if viewModel.isConnected == false {
                    HStack {
                        Spacer()
                        Text("Not Connected")
                            .padding(.all, 4)
                        Spacer()
                    }
                    .frame(height: 20)
                    .background(Color.red)
                }
                
                ScrollViewReader { proxy in
                    ScrollView {
                        
                        Color.clear
                           .frame(height: 8)
                           .id("topAnchor")
                        
                        ForEach(viewModel.model.messages, id: \.self) {
                            message in
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
                                            removal: .scale.combined(
                                                with: .opacity)
                                        )
                                    )
                                }

                                ChatBubbleView(
                                    message: message, viewModel: viewModel
                                )
                                .padding(.top, 4)
                                .padding(.bottom, 4)
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
                        
                        Color.clear
                           .frame(height: 8)
                           .id("bottomAnchor")
                    }
                    .scrollIndicators(.hidden)
                    .onChange(
                        of: viewModel.updateScrollView,
                        ({
                            scrollToBottom(proxy: proxy, anchor: "bottomAnchor", delay: 0.2)
                        }))
                }
                .padding(.horizontal)
                
                VStack {
                    EnhancedTextEditor(
                        text: $textPrompt,
                        placeholder: "Send a Message",
                        maxHeight: 120,
                        minHeight: 44
                    )
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 20,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 20
                    )
                )
                .shadow(radius: 12)

                HStack {
                    Button {
                        // TODO: Add image upload funtionality
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.gray)
                    }
                    .disabled(true)
                    .padding(.bottom, 8)
                    .padding(.leading, 16)
                    Spacer()
                    Button {
                        let promptText = self.textPrompt
                        self.textPrompt = ""
                        Task {
                            await self.viewModel.sendMessage(
                                prompt: promptText)
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(viewModel.isConnected ? .accentColor : .gray)
                    }
                    .disabled(viewModel.isConnected == false)
                    .padding(.bottom, 8)
                    .padding(.trailing, 16)
                }
                .background(Color(.secondarySystemBackground))
                .ignoresSafeArea(edges: keyboardHeight > 0 ? .bottom : [])
            }
            .toolbar {
                ToolBarHeader(
                    leadingButtonIcon: viewModel.selectionModeActive
                        ? "trash.fill" : "arrow.left",
                    trailingButtonIcon: viewModel.selectionModeActive
                        ? "xmark" : "list.dash",
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
            }
            .navigationTitle(viewModel.model.chatTitle)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .sheet(isPresented: $viewModel.showSettings) {
                ChatSettingsView(viewModel: self.viewModel)
            }
            .onAppear {
                self.viewModel.updateScrollView.toggle()
                // Check if the connection is active. For existing chats, the connection may have been lost.
                self.viewModel.checkConnection()
                
                observeKeyboardNotifications()
            }
            .onDisappear {
                // ---- Stop Observing Keyboard ----
                NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
                NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
            }
        }
    }
    
    
    // ---- Helper function for scrolling ----
    private func scrollToBottom(proxy: ScrollViewProxy, anchor: String, delay: Double = 0.0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
             withAnimation { // Ensure scrolling is animated
                  proxy.scrollTo(anchor, anchor: .bottom)
             }
        }
    }

    // ---- Keyboard Observation Logic ----
    private func observeKeyboardNotifications() {
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
            guard let userInfo = notification.userInfo,
                  let _ = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                  let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
            else { return }

            withAnimation(.easeOut(duration: duration)) {
                self.isKeyboardVisible = true
                self.viewModel.updateScrollView.toggle()
            }
        }
    }
}

#Preview {
    ChatView(chatModel: ChatModel(chatTitle: "Test Chat"))
}
