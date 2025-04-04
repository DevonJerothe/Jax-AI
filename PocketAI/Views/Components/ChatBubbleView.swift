//
//  ChatBubbleView.swift
//  PocketAI
//
//  Created by devon jerothe on 3/13/25.
//

import SwiftUI
import MarkdownUI

struct ChatBubbleView: View {

    var message: MessageModel
    var viewModel: ChatViewModel

    var body: some View {
        switch message.actor {
        case .bot:
            HStack {
                if message.loading {
                    HStack {
                        LoadingIndicator(size: 25)
                    }
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(15)
                    .frame(alignment: .leading)
                } else {
                    VStack(alignment: .leading) {
                        Markdown(message.getRolePlayText())
                            .markdownCodeSyntaxHighlighter(
                                .splash(theme: .wwdc18(withFont: .init(size: 16)))
                            )
                            .markdownBlockStyle(\.codeBlock) { configuration in
                                ScrollView(.horizontal) {
                                    configuration.label
                                        .padding(10)
                                        .padding(.trailing, 20)
                                }
                                .markdownTextStyle(textStyle: {
                                    FontFamilyVariant(.monospaced)
                                    FontSize(.em(0.85))
                                })
                                .background(Color(UIColor.systemGray3))
                                .cornerRadius(8)
                                .padding(.bottom)
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        UIPasteboard.general.string = configuration.content
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                    }
                                    .padding(10)
                                }
                            }
                            .markdownTheme(.rolePlay)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(15)
                            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .leading)
                        if viewModel.shouldShowToolbar(message) {
                            HStack(spacing: 16) {
                                // Delete
                                Button(action: {
                                    Task {
                                        await self.viewModel.deleteMessage(message)
                                    }
                                }) {
                                    Image(systemName: "trash.fill")
                                        .resizable()
                                        .frame(width: 10, height: 10)
                                        .foregroundStyle(Color.accentColor)
                                        .padding(5)
                                        .background(
                                            Circle()
                                                .stroke(Color.accentColor, lineWidth: 0.5)
                                        )
                                        .frame(width: 15, height: 15)
                                        .padding(.leading, 8)
                                        .padding(.top, 4)
                                }
                                // Regen
                                Button(action: {
                                    Task {
                                        await self.viewModel.regenerateMessage(message)
                                    }
                                }) {
                                    Image(systemName: "repeat")
                                        .resizable()
                                        .frame(width: 10, height: 10)
                                        .foregroundStyle(Color.accentColor)
                                        .padding(5)
                                        .background(
                                            Circle()
                                                .stroke(Color.accentColor, lineWidth: 0.5)
                                        )
                                        .frame(width: 15, height: 15)
                                        .padding(.leading, 4)
                                        .padding(.top, 4)
                                }
                                // Continue
                                Button(action: {
                                    Task {
                                        await self.viewModel.regenerateMessage(message, continueResponse: true)
                                    }
                                }) {
                                    Image(systemName: "play.fill")
                                        .resizable()
                                        .frame(width: 10, height: 10)
                                        .foregroundStyle(Color.accentColor)
                                        .padding(5)
                                        .background(
                                            Circle()
                                                .stroke(Color.accentColor, lineWidth: 0.5)
                                        )
                                        .frame(width: 15, height: 15)
                                        .padding(.leading, 4)
                                        .padding(.top, 4)
                                }
                            }
                        }
                    }
                }
                Spacer()
            }

        case .user:
            HStack {
                Spacer()
                VStack(alignment: .trailing) {
                    Markdown(message.getRolePlayText())
                        .foregroundStyle(.black)
                        .markdownTheme(.userRolePlay)
                        .padding()
                        .background(Color(.secondarySystemFill))
                        .clipShape(
                            UnevenRoundedRectangle(topLeadingRadius: 15, bottomLeadingRadius: 15, bottomTrailingRadius: 0, topTrailingRadius: 15)
                        )
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .trailing)
                }
            }
        }
    }
}
