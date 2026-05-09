//
//  ContentView.swift
//  PocketAI
//
//  Created by devon jerothe on 3/11/25.
//

import MarkdownUI
import SwiftLLMSDK
import SwiftUI
import UIKit

private struct ScrollBottomPositionKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ChatView: View {
    @Environment(NavigationManager.self) var navManager
    @Environment(\.appTheme) private var appTheme

    @State var viewModel: ChatViewModel
    @State var textPrompt: String = ""
    @State private var isScrollViewAtBottom = true
    @State private var autoScrollGeneration = 0
    @FocusState private var isInputFocused: Bool

    @State private var scrollViewHelper: UIScrollView?

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
            GeometryReader { scrollGeometry in
                ZStack(alignment: .bottomTrailing) {
                    ScrollView {
                        Color.clear
                            .frame(height: 8)
                            .id("topAnchor")

                        if let chat = viewModel.model {
                            LazyVStack {
                                ForEach(chat.messages, id: \.self) { message in
                                    HStack {
                                        ChatBubbleView(
                                            message: message,
                                            viewModel: viewModel
                                        )
                                    }
                                    .padding(.top, 4)
                                    .padding(.bottom, 4)
                                    .id(message.id)
                                }
                            }
                        }

                        Color.clear
                            .frame(height: 8)
                            .id("bottomAnchor")
                            .background(
                                GeometryReader { markerGeometry in
                                    Color.clear.preference(
                                        key: ScrollBottomPositionKey.self,
                                        value: markerGeometry.frame(in: .named("chatScroll")).maxY
                                    )
                                }
                            )
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
                        DragGesture(minimumDistance: 10)
                            .onChanged { _ in
                                disableAutoScroll()
                            }
                            .onEnded { _ in
                                disableAutoScroll()
                            }
                    )
                    .onPreferenceChange(ScrollBottomPositionKey.self) { bottomPosition in
                        updateScrollBottomState(
                            bottomPosition: bottomPosition,
                            viewportHeight: scrollGeometry.size.height
                        )
                    }
                    .onChange(
                        of: viewModel.updateScrollView,
                        ({
                            guard viewModel.isAutoScrollEnabled else { return }
                            scrollToBottom(proxy: proxy, anchor: "bottomAnchor", delay: 0.05)
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
                            scrolltoBottom(proxy: proxy, anchor: "bottomAnchor", delay: 0.05)
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

    private func updateScrollBottomState(bottomPosition: CGFloat, viewportHeight: CGFloat) {
        let isAtBottom = bottomPosition <= viewportHeight + 24
        isScrollViewAtBottom = isAtBottom

        if isAtBottom && viewModel.isAutoScrollEnabled == false {
            viewModel.isAutoScrollEnabled = true
        }
    }
}
