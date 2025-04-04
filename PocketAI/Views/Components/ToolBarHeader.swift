//
//  ChatHeaderView.swift
//  PocketAI
//
//  Created by devon jerothe on 3/13/25.
//

import SwiftUI

struct ToolBarHeader: ToolbarContent {

    var leadingButtonIcon: String
    var leadingIconColor: Color = .accentColor
    var trailingButtonIcon: String

    var leadingButtonAction: (() -> Void)
    var trailingButtonAction: (() -> Void)

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(action: leadingButtonAction) {
                Image(systemName: leadingButtonIcon)
                    .foregroundStyle(leadingIconColor)
                    .frame(width: 15, height: 15)
                    .padding(10)
                    .background(
                        Circle()
                            .stroke(Color.accentColor, lineWidth: 0.5)
                    )
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(
                action: trailingButtonAction,
                label: {
                    Image(systemName: trailingButtonIcon)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 15, height: 15)
                        .padding(10)
                        .background(
                            Circle()
                                .stroke(Color.accentColor, lineWidth: 0.5)
                        )
                })
        }
    }
}
