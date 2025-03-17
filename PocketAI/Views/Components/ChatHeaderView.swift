//
//  ChatHeaderView.swift
//  PocketAI
//
//  Created by devon jerothe on 3/13/25.
//

import SwiftUI

struct ChatViewHeader: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(NavigationManager.self) var navManager

    var viewModel: ChatViewModel

    var body: some View {
        VStack {
            HStack(alignment: .center) {
                Button(action: {
                    if viewModel.selectionModeActive {
                        Task {
                            await viewModel.deleteMessages()
                        }
                    } else {
                        dismiss()
                    }
                }) {
                    Image(
                        systemName: viewModel.selectionModeActive
                        ? "trash.fill" : "arrow.left"
                    )
                    .foregroundStyle(.white)
                    .frame(width: 15, height: 15)
                    .padding(10)
                    .background(
                        Circle()
                            .stroke(Color.white, lineWidth: 0.5)
                    )
                }

                Spacer()
                Text(viewModel.model.chatTitle)
                Spacer()

                Button(
                    action: {
                        if viewModel.selectionModeActive {
                            viewModel.cancelDeleteMessages()
                        } else {
                            viewModel.showSettings.toggle()
                        }
                    },
                    label: {
                        Image(
                            systemName: viewModel.selectionModeActive
                            ? "xmark" : "list.dash"
                        )
                        .foregroundStyle(.white)
                        .frame(width: 15, height: 15)
                        .padding(10)
                        .background(
                            Circle()
                                .stroke(Color.white, lineWidth: 0.5)
                        )
                    })
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            Divider()
                .frame(height: 0.5)
                .overlay(.white)
        }
    }
}
