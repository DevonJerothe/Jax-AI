//
//  ContentView.swift
//  PocketAI
//
//  Created by devon jerothe on 3/11/25.
//

import SwiftLLMSDK
import SwiftUI
import UIKit


struct ChatView: View {
    @Environment(NavigationManager.self) var navManager
    @Environment(\.appTheme) private var appTheme

    @State var viewModel: ChatViewModel
    @State var textPrompt: String = ""
    @State private var isScrollViewAtBottom = true
    @State private var autoScrollGeneration = 0
    @FocusState private var isInputFocused: Bool

    @State private var scrollViewHelper: UIScrollView?
    @State private var viewportHeight: CGFloat = 0

    init(chatID: UUID) {
        _viewModel = State(initialValue: ChatViewModel(chatID: chatID))
    }

    var body: some View {

        Group {
            if viewModel.shouldHidePrivateContent {
                ContentUnavailableView(
                    "Private Chat Locked",
                    systemImage: "lock.fill",
                    description: Text("Unlock the app in Settings to view this chat.")
                )
            } else {
                chatContent
            }
        }
    }

    private var chatContent: some View {
        ScrollViewReader { proxy in
                ZStack(alignment: .bottomTrailing) {
                    ScrollView {
                        Color.clear
                            .frame(height: 8)
                            .id("topAnchor")

                        if let chat = viewModel.model {

                            let cardName = chat.characterCards.first?.name ?? ""
                            let personaName = ServiceContainer.shared.getPersonaName
                            let chatIsIdle = chat.status == .idle
                            let lastMessageID = chat.messages.last?.id
                            let messageCount = chat.messages.count
                            let isOnlyMessage = messageCount == 1

                            LazyVStack {
                                ForEach(chat.messages, id: \.id) { message in
                                    let showToolbar = chatIsIdle && messageCount > 1 && message.id == lastMessageID && message.status == .done
                                    let isStreaming = message.id == viewModel.streamingMessageID
                                
                                    HStack {
                                        ChatBubbleView(
                                            message: message,
                                            isStreaming: isStreaming, 
                                            mdReader: isStreaming ? viewModel.mdReader : nil,
                                            cardName: cardName,
                                            personaName: personaName,
                                            showToolbar: showToolbar,
                                            isOnlyMessage: isOnlyMessage,
                                            onDelete: { Task { await viewModel.deleteMessage(message) } },
                                            onRegenerate: { Task { await viewModel.regenerateMessage(message) } },
                                            onContinue: { Task { await viewModel.regenerateMessage(message, continueResponse: true) } },
                                            onSaveEdit: { newText in Task { await viewModel.updateMessage(message, newText: newText) } },
                                            onNavigateGeneration: { forward in
                                                Task {
                                                    await viewModel.navigateGeneration(message, forward: forward)
                                                }
                                            },
                                            onScrollToMessage: { viewModel.editingMessageID = message.id },
                                            onSetEditing: { enabled in viewModel.disableWhileEditing = enabled },
                                            onScrollViewUpdate: { viewModel.updateScrollView.toggle() }
                                        )
                                    }
                                    .padding(.top, 4)
                                    .padding(.bottom, 4)
                                    .id(message.id)
                                }
                            }
                            .id(viewModel.scrollReloadToggle)
                        }

                        Color.clear
                            .frame(height: 8)
                            .id("bottomAnchor")
                            .onGeometryChange(for: CGFloat.self) { geo in 
                                geo.frame(in: .named("chatScroll")).maxY
                            } action: { newPosition in
                                updateScrollBottomState(bottomPosition: newPosition)
                            }
                            .background{
                                ScrollViewHelper { scrollView in 
                                    scrollViewHelper = scrollView 
                                }
                            }
                    }
                    .coordinateSpace(name: "chatScroll")
                    .padding(.horizontal)
                    .scrollIndicators(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 5)
                            .onChanged { _ in
                                disableAutoScroll()
                            }
                    )
                    .onChange(
                        of: viewModel.updateScrollView,
                        ({
                            guard viewModel.isAutoScrollEnabled else { return }
                            scrollToBottom(proxy: proxy, anchor: "bottomAnchor", delay: 0.1)
                        })
                    )
                    .onChange(
                        of: viewModel.scrollAfterLayout,
                        ({
                            guard viewModel.isAutoScrollEnabled else { return }
                            scrollToBottom(proxy: proxy, anchor: "bottomAnchor", delay: 0.3)
                        })
                    )
                    .onChange(of: viewModel.editingMessageID) { _, messageID in
                        if let messageID {
                            scrollToBottom(proxy: proxy, anchor: messageID, delay: 0.35, requiresAutoScroll: false)
                            viewModel.editingMessageID = nil
                        }
                    }
                    .onChange(of: isInputFocused) { _, isFocused in
                        if isFocused && viewModel.isAutoScrollEnabled {
                            scrollToBottom(proxy: proxy, anchor: "bottomAnchor", delay: 0.2)
                        }
                    }

                    if viewModel.isAutoScrollEnabled == false && isScrollViewAtBottom == false {
                        Button {
                            viewModel.isAutoScrollEnabled = true
                            
                            // Stop scroll view if in mostion before scrolling to bottom
                            scrollViewHelper?.setContentOffset(scrollViewHelper?.contentOffset ?? .zero, animated: false)
                            scrollToBottom(proxy: proxy, anchor: "bottomAnchor", delay: 0.05)
                        } label: {
                            Image(systemName: "arrow.down")
                                // .font(.system(size: 12))
                                .foregroundColor(appTheme.secondaryText.color)
                                .glassCapsule()
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 18)
                        .padding(.bottom, 14)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }
                }
                .onGeometryChange(for: CGFloat.self) { geo in
                    geo.size.height
                } action: { newHeight in
                    viewportHeight = newHeight
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
                .background(appTheme.secondaryBackgroundColor.color)
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
                            .foregroundColor(appTheme.secondaryText.color)
                    }
                    .disabled(true)
                    .padding(.bottom, 8)
                    .padding(.leading, 16)
                    Spacer()
                    Button {
                        let promptText = self.textPrompt
                        self.textPrompt = ""
                        viewModel.isAutoScrollEnabled = true
                        Task {
                            await self.viewModel.sendMessage(
                                prompt: promptText)
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(viewModel.isConnected ? appTheme.tintColor.color : appTheme.secondaryText.color)
                    }
                    .disabled(viewModel.isConnected == false || viewModel.isStreaming == true || viewModel.disableWhileEditing == true)
                    .padding(.bottom, 8)
                    .padding(.trailing, 16)
                }
                .background(
                    appTheme.secondaryBackgroundColor.color
                        .ignoresSafeArea(.all, edges: .bottom)
                )
            }
        }
        .navigationTitle(viewModel.model?.chatTitle ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isInputFocused = false
                    UIApplication.shared.endEditing()
                    navManager.navigateToChatSettings(chatID: viewModel.chatID)
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundColor(appTheme.primaryText.color)
                }
            }
        }
        .background(appTheme.backgroundColor.color)
        .onAppear {
            viewModel.isAutoScrollEnabled = true
            self.viewModel.updateScrollView.toggle()
            self.viewModel.isViewActive = true
        }
        .onDisappear {
            isInputFocused = false
            UIApplication.shared.endEditing()
            self.viewModel.isViewActive = false
        }
    }

    private func scrollToBottom(
        proxy: ScrollViewProxy,
        anchor: any Hashable,
        delay: Double = 0.0,
        requiresAutoScroll: Bool = true
    ) {
        let generation = autoScrollGeneration

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard generation == autoScrollGeneration else {
                return
            }

            guard requiresAutoScroll == false || viewModel.isAutoScrollEnabled else {
                return
            }

            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(anchor, anchor: .bottom)
            }
        }
    }

    private func disableAutoScroll() {
        guard viewModel.isAutoScrollEnabled else {
            return
        }

        viewModel.isAutoScrollEnabled = false
        autoScrollGeneration += 1
    }

    private func updateScrollBottomState(bottomPosition: CGFloat) {
        let newIsAtBottom = bottomPosition <= viewportHeight + 24
        guard newIsAtBottom != isScrollViewAtBottom else { return }

        isScrollViewAtBottom = newIsAtBottom

        if newIsAtBottom && viewModel.isAutoScrollEnabled == false {
            viewModel.isAutoScrollEnabled = true
        }
    }
}
