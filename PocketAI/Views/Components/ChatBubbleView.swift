//
//  ChatBubbleView.swift
//  PocketAI
//
//  Created by devon jerothe on 3/13/25.
//

import MarkdownUI
import NetworkImage
import SwiftUI

struct ChatBubbleView: View {

    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @Environment(\.appTheme) private var appTheme

    var message: MessageModel
    let cardName: String
    let personaName: String
    let showToolbar: Bool
    let isOnlyMessage: Bool

    let onDelete: () -> Void
    let onRegenerate: () -> Void
    let onContinue: () -> Void
    let onSaveEdit: (String) -> Void
    let onNavigateGeneration: (Bool) -> Void
    let onScrollToMessage: () -> Void
    let onSetEditing: (Bool) -> Void
    let onScrollViewUpdate: () -> Void

    @State private var isEditing = false
    @State private var bubbleHeight: CGFloat = 0
    @State private var editedText: String = ""

    private enum ToolbarAction: String, Identifiable {
        case delete
        case regenerate
        case edit
        case save
        case continueResponse
        case previousGeneration
        case nextGeneration

        var id: String { rawValue }

        var systemName: String {
            switch self {
            case .delete:
                return "trash.fill"
            case .regenerate:
                return "repeat"
            case .edit:
                return "pencil"
            case .save:
                return "checkmark.circle.fill"
            case .continueResponse:
                return "play.fill"
            case .previousGeneration:
                return "chevron.left"
            case .nextGeneration:
                return "chevron.right"
            }
        }

        var isDestructive: Bool {
            self == .delete
        }
    }

    private var editorMaxHeight: CGFloat {
        min(UIApplication.currentScreenHeight * 0.45, 360)
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
                            editingTextView(maxWidth: UIApplication.currentScreenWidth)
                        } else {
                            Markdown(
                                message.getRolePlayText(
                                    cardName: cardName,
                                    personaName: personaName
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
                                        Text(configuration.language ?? "")
                                            .foregroundColor(appTheme.primaryText.color)
                                            .font(.caption)
                                            .padding(4)
                                            .padding(.leading, 8)
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
                            .markdownImageProvider(AsyncImageProvider())
                            .markdownInlineImageProvider(AsyncInlineImageProvider())
                            .padding()
                            .cornerRadius(15)
                            .frame(
                                maxWidth: UIApplication.currentScreenWidth * 1,
                                alignment: .leading
                            )
                            .onGeometryChange(for: CGFloat.self) { geo in
                                geo.size.height
                            } action: { newHeight in
                                if newHeight > 0 && isEditing == false {
                                    bubbleHeight = newHeight
                                }
                            }
                        }
                    }
                    messageToolbar
                }
                .animation(.easeInOut(duration: 0.5), value: message.status)
                .simultaneousGesture(generationSwipeGesture)
                Spacer()
            }

        case .user:
            HStack {
                Spacer()
                VStack(alignment: .trailing) {
                    if isEditing {
                        editingTextView(maxWidth: UIApplication.currentScreenWidth * 0.80)
                    } else {
                        VStack(alignment: .trailing) {
                            Markdown(
                                message.getRolePlayText(
                                    cardName: cardName,
                                    personaName: personaName
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
                                maxWidth: UIApplication.currentScreenWidth * 0.75,
                                alignment: .trailing
                            )
                            .onGeometryChange(for: CGFloat.self) { geo in
                                geo.size.height
                            } action: { newHeight in
                                if newHeight > 0 && isEditing == false {
                                    bubbleHeight = newHeight
                                }
                            }
                        }
                    }
                    messageToolbar
                }
                .simultaneousGesture(generationSwipeGesture)
            }
        }
    }

    private var shouldShowLoadingBubble: Bool {
        message.status != .done && message.text.isEmpty
    }

    @ViewBuilder
    private var messageToolbar: some View {
        let actions = toolbarActions

        if actions.isEmpty == false || (message.textGenerationHistory.isEmpty == false && isOnlyMessage) {
            toolbarContent(actions)
        }
    }

    @ViewBuilder
    private func toolbarContent(_ actions: [ToolbarAction]) -> some View {
        if message.actor == .user && shouldShowGenerationNavigation == false {
            HStack(spacing: 16) {
                ForEach(actions) { action in
                    toolbarButton(for: action)
                }
            }
        } else {
            HStack(spacing: 16) {
                ForEach(actions) { action in
                    toolbarButton(for: action)
                }

                Spacer()

                generationNavigation
            }
            .frame(maxWidth: toolbarMaxWidth)
        }
    }

    private var toolbarActions: [ToolbarAction] {
        var actions: [ToolbarAction] = []

        if isEditing {
            if message.actor == .user && showToolbar {
                actions.append(.delete)
            }

            actions.append(.save)
            return actions
        }

        guard showToolbar else {
            return actions
        }

        actions.append(.delete)

        switch message.actor {
        case .bot:
            actions.append(.regenerate)
            actions.append(.edit)
            actions.append(.continueResponse)
        case .user:
            actions.append(.edit)
        }

        return actions
    }

    private func performToolbarAction(_ action: ToolbarAction) {
        switch action {
        case .delete:
            onDelete()
        case .regenerate:
            onRegenerate()
        case .edit, .save:
            toggleEditing()
        case .continueResponse:
            onContinue()
        case .previousGeneration:
            navigateGeneration(forward: false)
        case .nextGeneration:
            navigateGeneration(forward: true)
        }
    }

    private var generationSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                let horizontalDistance = value.translation.width
                let verticalDistance = value.translation.height

                guard abs(horizontalDistance) > abs(verticalDistance) * 1.5 else {
                    return
                }

                navigateGeneration(forward: horizontalDistance < 0)
            }
    }

    private func navigateGeneration(forward: Bool) {
        guard isEditing == false, message.status == .done, message.hasMoreGenerations(before: forward == false) else {
            return
        }

        onNavigateGeneration(forward)
    }

    @ViewBuilder
    private var generationNavigation: some View {
        if shouldShowGenerationNavigation {
            HStack(spacing: 8) {
                if message.hasMoreGenerations(before: true) {
                    toolbarButton(for: .previousGeneration)
                }

                Text("\(message.generationPosition ?? 1)/\(message.generationCount)")
                    .font(.caption2)
                    .foregroundStyle(appTheme.secondaryText.color)
                    .monospacedDigit()

                if message.hasMoreGenerations(before: false) {
                    toolbarButton(for: .nextGeneration)
                }
            }
        }
    }

    private var shouldShowGenerationNavigation: Bool {
        isEditing == false && message.generationPosition != nil
    }

    private func toolbarButton(for action: ToolbarAction) -> some View {
        let color = toolbarColor(for: action)

        return Button {
            performToolbarAction(action)
        } label: {
            Image(systemName: action.systemName)
                .resizable()
                .frame(width: 10, height: 10)
                .foregroundStyle(color)
                .padding(5)
                .background(
                    Circle()
                        .stroke(color, lineWidth: 0.5)
                )
                .frame(width: 15, height: 15)
                .padding(toolbarHorizontalEdge, 4)
                .padding(.top, 4)
        }
    }

    private var toolbarHorizontalEdge: Edge.Set {
        message.actor == .bot ? .leading : .trailing
    }

    private var toolbarMaxWidth: CGFloat {
        switch message.actor {
        case .bot:
            return UIApplication.currentScreenWidth
        case .user:
            return UIApplication.currentScreenWidth * 0.75
        }
    }

    private func toolbarColor(for action: ToolbarAction) -> Color {
        action.isDestructive ? appTheme.destructiveAction.color : appTheme.tintColor.color
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
            onSaveEdit(editedText)
            isEditing = false
            onSetEditing(false)
            onScrollViewUpdate()
        } else {
            editedText = message.text
            isEditing = true
            onSetEditing(true)
            scrollToEditedMessage()
        }
    }

    private func scrollToEditedMessage() {
        onScrollToMessage()
    }
}
