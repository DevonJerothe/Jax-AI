//
//  ChatHeaderView.swift
//  PocketAI
//
//  Created by devon jerothe on 3/13/25.
//

import SwiftUI

struct ChatViewHeader: View {

    var leadingButtonIcon: String
    var leadingIconColor: Color = .white
    var trailingButtonIcon: String
    var title: String = "Pocket AI"

    var leadingButtonAction: (() -> Void)
    var trailingButtonAction: (() -> Void)

    var body: some View {
        VStack {
            HStack(alignment: .center) {
                Button(action: leadingButtonAction) {
                    Image(systemName: leadingButtonIcon)
                        .foregroundStyle(leadingIconColor)
                        .frame(width: 15, height: 15)
                        .padding(10)
                        .background(
                            Circle()
                                .stroke(Color.white, lineWidth: 0.5)
                        )
                }

                Spacer()
                Text(title)
                Spacer()

                Button(
                    action: trailingButtonAction,
                    label: {
                        Image(systemName: trailingButtonIcon)
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
