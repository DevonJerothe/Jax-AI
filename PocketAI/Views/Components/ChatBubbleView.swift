//
//  ChatBubbleView.swift
//  PocketAI
//
//  Created by devon jerothe on 3/13/25.
//

import MarkdownUI
import SwiftUI

struct BubbleHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct ChatBubbleView: View {

    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var message: MessageModel
    var viewModel: ChatViewModel
    @State private var isEditing = false
    @State private var bubbleHeight: CGFloat = 0
    @State private var editedText: String = ""

    var body: some View {
        switch message.actor {
        case .bot:
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    if shouldShowLoadingBubble {
                        HStack {
                            LoadingIndicator(size: 25, thinking: message.status == .thinking)
                                .padding(.trailing, 5)
                        }
                        .padding(10)
//                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(15)
                        .frame(alignment: .leading)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    } else {
                        if isEditing {
                            TextEditor(text: $editedText)
                                .padding(
                                    EdgeInsets(
                                        top: 8, leading: 10, bottom: 8,
                                        trailing: 10)
                                )
                                .background(Color(.clear))
                                .cornerRadius(15)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color.accentColor, lineWidth: 1)
                                )
                                .frame(minHeight: bubbleHeight + 30)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(
                                    maxWidth: UIScreen.main.bounds.width * 1,
                                    alignment: .leading
                                )
                                .onChange(of: editedText) {
                                    viewModel.updateScrollView.toggle()
                                }
                        } else {
                            Markdown(
                                message.getRolePlayText(
                                    cardName: viewModel.model?.characterCards.first?.name
                                        ?? "")
                            )
                            .markdownCodeSyntaxHighlighter(
                                .splash(
                                    theme: colorScheme == .dark
                                        ? .wwdc17(withFont: .init(size: 16))
                                        : .sunset(withFont: .init(size: 16)))
                            )
                            .markdownBlockStyle(\.codeBlock) { configuration in
                                VStack(spacing: 0) {
                                    HStack {
                                        Spacer()
                                        Button {
                                            UIPasteboard.general.string =
                                                configuration.content
                                        } label: {
                                            Image(systemName: "doc.on.doc")
                                        }
                                        .padding(4)
                                    }
                                    .background(
                                        Color(UIColor.secondarySystemFill))
                                    ScrollView(.horizontal) {
                                        configuration.label
                                            .padding(10)
                                            .padding(.trailing, 20)
                                    }
                                    .markdownTextStyle(textStyle: {
                                        FontFamilyVariant(.monospaced)
                                        FontSize(.em(0.65))
                                    })
                                    .background(
                                        Color(UIColor.secondarySystemBackground)
                                    )
                                }
                                .cornerRadius(8)
                            }
                            .markdownTheme(.rolePlay)
                            .padding()
//                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(15)
                            .frame(
                                maxWidth: UIScreen.main.bounds.width * 1,
                                alignment: .leading
                            )
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: BubbleHeightKey.self,
                                        value: geo.size.height)
                                }
                            )
                        }
                    }
                    if viewModel.shouldShowToolbar(message) {
                        HStack(spacing: 16) {
                            // Delete
                            Button(action: {
                                Task {
                                    await self.viewModel.deleteMessage(
                                        message)
                                }
                            }) {
                                Image(systemName: "trash.fill")
                                    .resizable()
                                    .frame(width: 10, height: 10)
                                    .foregroundStyle(Color.accentColor)
                                    .padding(5)
                                    .background(
                                        Circle()
                                            .stroke(
                                                Color.accentColor,
                                                lineWidth: 0.5)
                                    )
                                    .frame(width: 15, height: 15)
                                    .padding(.leading, 8)
                                    .padding(.top, 4)
                            }
                            // Regen
                            Button(action: {
                                Task {
                                    await self.viewModel.regenerateMessage(
                                        message)
                                }
                            }) {
                                Image(systemName: "repeat")
                                    .resizable()
                                    .frame(width: 10, height: 10)
                                    .foregroundStyle(Color.accentColor)
                                    .padding(5)
                                    .background(
                                        Circle()
                                            .stroke(
                                                Color.accentColor,
                                                lineWidth: 0.5)
                                    )
                                    .frame(width: 15, height: 15)
                                    .padding(.leading, 4)
                                    .padding(.top, 4)
                            }
                            // Edit
                            Button(action: {
                                toggleEditing()
                            }) {
                                Image(
                                    systemName: isEditing
                                        ? "checkmark.circle.fill" : "pencil"
                                )
                                .resizable()
                                .frame(width: 10, height: 10)
                                .foregroundStyle(Color.accentColor)
                                .padding(5)
                                .background(
                                    Circle()
                                        .stroke(
                                            Color.accentColor,
                                            lineWidth: 0.5)
                                )
                                .frame(width: 15, height: 15)
                                .padding(.leading, 4)
                                .padding(.top, 4)
                            }

                            // Continue
                            Button(action: {
                                Task {
                                    await self.viewModel.regenerateMessage(
                                        message, continueResponse: true)
                                }
                            }) {
                                Image(systemName: "play.fill")
                                    .resizable()
                                    .frame(width: 10, height: 10)
                                    .foregroundStyle(Color.accentColor)
                                    .padding(5)
                                    .background(
                                        Circle()
                                            .stroke(
                                                Color.accentColor,
                                                lineWidth: 0.5)
                                    )
                                    .frame(width: 15, height: 15)
                                    .padding(.leading, 4)
                                    .padding(.top, 4)
                            }
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.5), value: message.status)
                .onPreferenceChange(BubbleHeightKey.self) { height in
                    if height > 0 && isEditing == false {
                        self.bubbleHeight = height
                    }
                }
                Spacer()
            }

        case .user:
            HStack {
                Spacer()
                VStack(alignment: .trailing) {
                    if isEditing {
                        TextEditor(text: $editedText)
                            .padding(
                                EdgeInsets(
                                    top: 8, leading: 10, bottom: 8,
                                    trailing: 10)
                            )
                            .background(Color(.clear))
                            .cornerRadius(15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color.accentColor, lineWidth: 1)
                            )
                            .frame(minHeight: bubbleHeight + 30)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(
                                maxWidth: UIScreen.main.bounds.width * 0.80,
                                alignment: .leading
                            )
                            .onChange(of: editedText) {
                                viewModel.updateScrollView.toggle()
                            }
                    } else {
                        VStack(alignment: .trailing) {
                            Markdown(
                                message.getRolePlayText(
                                    cardName: viewModel.model?.characterCards.first?.name
                                        ?? "")
                            )
                            .foregroundStyle(.black)
                            .markdownTheme(.userRolePlay)
                            .padding()
                            .background(Color(.secondarySystemFill))
                            .clipShape(
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 15,
                                    bottomLeadingRadius: 15,
                                    bottomTrailingRadius: 0,
                                    topTrailingRadius: 15)
                            )
                            .frame(
                                maxWidth: UIScreen.main.bounds.width * 0.75,
                                alignment: .trailing
                            )
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: BubbleHeightKey.self,
                                        value: geo.size.height)
                                }
                            )
                        }
                    }
                    if viewModel.shouldShowToolbar(message) {
                        HStack(spacing: 16) {
                            // Delete
                                Button(action: {
                                    Task {
                                        await self.viewModel.deleteMessage(
                                            message)
                                    }
                                }) {
                                    Image(systemName: "trash.fill")
                                        .resizable()
                                        .frame(width: 10, height: 10)
                                        .foregroundStyle(Color.accentColor)
                                        .padding(5)
                                        .background(
                                            Circle()
                                                .stroke(
                                                    Color.accentColor,
                                                    lineWidth: 0.5)
                                        )
                                        .frame(width: 15, height: 15)
                                        .padding(.trailing, 4)
                                        .padding(.top, 4)
                                }
                            // Edit
                            Button(action: {
                                toggleEditing()
                            }) {
                                Image(
                                    systemName: isEditing
                                        ? "checkmark.circle.fill" : "pencil"
                                )
                                .resizable()
                                .frame(width: 10, height: 10)
                                .foregroundStyle(Color.accentColor)
                                .padding(5) 
                                .background(
                                    Circle()
                                        .stroke(
                                            Color.accentColor,
                                            lineWidth: 0.5)
                                )
                                .frame(width: 15, height: 15)
                                .padding(.trailing, 4)
                                .padding(.top, 4)
                            }
                        }
                    }
                }
                .onPreferenceChange(BubbleHeightKey.self) { height in
                    if height > 0 && isEditing == false {
                        self.bubbleHeight = height
                    }
                }
            }
        }
    }

    private var shouldShowLoadingBubble: Bool {
        message.status != .done && message.text.isEmpty
    }

    private func toggleEditing() {
        if isEditing {
            Task {
                await viewModel.updateMessage(message, newText: editedText)
            }
            isEditing = false
            viewModel.updateScrollView.toggle()
        } else {
            editedText = message.text
            isEditing = true
            viewModel.editingMessageID = message.id
        }
    }
}
