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
    @Environment(\.appTheme) private var appTheme

    var message: MessageModel
    var viewModel: ChatViewModel
    @State private var isEditing = false
    @State private var bubbleHeight: CGFloat = 0
    @State private var editedText: String = ""

    private var editorMaxHeight: CGFloat {
        min(UIScreen.main.bounds.height * 0.45, 360)
    }

    private var editorMinHeight: CGFloat {
        max(44, min(bubbleHeight, editorMaxHeight))
    }

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
                        .cornerRadius(15)
                        .frame(alignment: .leading)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    } else {
                        if isEditing {
                            editingTextView(maxWidth: UIScreen.main.bounds.width)
                        } else {
                            Markdown(
                                message.getRolePlayText(
                                    cardName: viewModel.model?.characterCards.first?.name ?? "",
                                    personaName: ServiceContainer.shared.getPersonaName
                                )
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
                                        appTheme.secondaryAction.color)
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
                                        appTheme.secondaryBackgroundColor.color
                                    )
                                }
                                .cornerRadius(8)
                            }
                            .markdownTheme(.rolePlay(appTheme))
                            .padding()
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
                    if viewModel.shouldShowToolbar(message) && isEditing == false {
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
                                    .foregroundStyle(appTheme.destructiveAction.color)
                                    .padding(5)
                                    .background(
                                        Circle()
                                            .stroke(
                                                appTheme.destructiveAction.color,
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
                                    .foregroundStyle(appTheme.tintColor.color)
                                    .padding(5)
                                    .background(
                                        Circle()
                                            .stroke(
                                                appTheme.tintColor.color,
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
                                .foregroundStyle(appTheme.tintColor.color)
                                .padding(5)
                                .background(
                                    Circle()
                                        .stroke(
                                            appTheme.tintColor.color,
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
                                    .foregroundStyle(appTheme.tintColor.color)
                                    .padding(5)
                                    .background(
                                        Circle()
                                            .stroke(
                                                appTheme.tintColor.color,
                                                lineWidth: 0.5)
                                    )
                                    .frame(width: 15, height: 15)
                                    .padding(.leading, 4)
                                    .padding(.top, 4)
                            }
                        }
                    } else if isEditing == true {
                        Button(action: {
                            toggleEditing()
                        }) {
                            Image(
                                systemName: "checkmark.circle.fill"
                            )
                            .resizable()
                            .frame(width: 10, height: 10)
                            .foregroundStyle(appTheme.tintColor.color)
                            .padding(5)
                            .background(
                                Circle()
                                    .stroke(
                                        appTheme.tintColor.color,
                                        lineWidth: 0.5)
                            )
                            .frame(width: 15, height: 15)
                            .padding(.leading, 4)
                            .padding(.top, 4)
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
                        editingTextView(maxWidth: UIScreen.main.bounds.width * 0.80)
                    } else {
                        VStack(alignment: .trailing) {
                            Markdown(
                                message.getRolePlayText(
                                    cardName: viewModel.model?.characterCards.first?.name ?? "",
                                    personaName: ServiceContainer.shared.getPersonaName
                                )
                            )
                            .foregroundStyle(appTheme.primaryText.color)
                            .markdownTheme(.userRolePlay(appTheme))
                            .padding()
                            .background(appTheme.secondaryAction.color)
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
                                        .foregroundStyle(appTheme.destructiveAction.color)
                                        .padding(5)
                                        .background(
                                            Circle()
                                                .stroke(
                                                    appTheme.destructiveAction.color,
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
                                .foregroundStyle(appTheme.tintColor.color)
                                .padding(5) 
                                .background(
                                    Circle()
                                        .stroke(
                                            appTheme.tintColor.color,
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

    private func editingTextView(maxWidth: CGFloat) -> some View {
        EnhancedTextEditor(
            text: $editedText,
            placeholder: "",
            maxHeight: editorMaxHeight,
            minHeight: editorMinHeight,
            textColor: UIColor(appTheme.primaryText.color)
        )
        .padding(.vertical, 2)
        .background(appTheme.secondaryBackgroundColor.color.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(appTheme.tintColor.color.opacity(0.55), lineWidth: 1)
        )
        .frame(maxWidth: maxWidth, alignment: .leading)
        .onChange(of: editedText) {
            scrollToEditedMessage()
        }
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
            scrollToEditedMessage()
        }
    }

    private func scrollToEditedMessage() {
        viewModel.editingMessageID = message.id
    }
}
