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
    @Environment(NavigationManager.self) var navManager

    @State var viewModel: ChatViewModel
    @State var textPrompt: String = ""
    @FocusState private var isInputFocused: Bool

    // ---- Add State for Keyboard Height ----
    @State private var keyboardHeight: CGFloat = 0
    // ---- Add State for tracking keyboard visibility ----
    @State private var isKeyboardVisible: Bool = false

    init(chatID: UUID) {
        _viewModel = State(initialValue: ChatViewModel(chatID: chatID))
    }

    var body: some View {

        ScrollViewReader { proxy in
            ScrollView {

                Color.clear
                    .frame(height: 8)
                    .id("topAnchor")

                if let chat = viewModel.model {
                    ForEach(chat.messages, id: \.self) { message in
                        HStack {
                            ChatBubbleView(
                                message: message,
                                viewModel: viewModel
                            )
                            .padding(.top, 4)
                            .padding(.bottom, 4)
                            .id(message)
                        }
                    }
                }

                Color.clear
                    .frame(height: 8)
                    .id("bottomAnchor")
            }
            .padding(.horizontal)
            .scrollIndicators(.hidden)
            .onChange(
                of: viewModel.updateScrollView,
                ({
                    scrollToBottom(proxy: proxy, anchor: "bottomAnchor", delay: 0.2)
                })
            )
            .onChange(of: viewModel.editingMessageID) { _, messageID in
                if let messageID {
                    scrollToBottom(proxy: proxy, anchor: messageID, delay: 0.2)
                    viewModel.editingMessageID = nil
                }
            }
            .onChange(of: isInputFocused) { _, isFocused in
                if isFocused {
                    scrollToBottom(proxy: proxy, anchor: "bottomAnchor", delay: 0.2)
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if viewModel.isConnected == false {
                APIStatusBanner(
                    stayOnPath: true
                )
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                VStack {
                    EnhancedTextEditor(
                        text: $textPrompt,
                        placeholder: "Send a Message",
                        maxHeight: 120,
                        minHeight: 44
                    )
                    .focused($isInputFocused)
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
                    .disabled(viewModel.isConnected == false || viewModel.isStreaming == true)
                    .padding(.bottom, 8)
                    .padding(.trailing, 16)
                }
                .background(
                    Color(.secondarySystemBackground)
                        .ignoresSafeArea(.all, edges: .bottom)
                )
            }
        }
        .navigationTitle(viewModel.model?.chatTitle ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    navManager.navigateToChatSettings(chatID: viewModel.chatID)
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundColor(.primary)
                }
            }
        }
        .onAppear {
            self.viewModel.updateScrollView.toggle()
            self.viewModel.isViewActive = true
        }
        .onDisappear {
            self.viewModel.isViewActive = false
        }
    }

    // ---- Helper function for scrolling ----
    private func scrollToBottom(proxy: ScrollViewProxy, anchor: any Hashable, delay: Double = 0.0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation {  // Ensure scrolling is animated
                proxy.scrollTo(anchor, anchor: .bottom)
            }
        }
    }
}
