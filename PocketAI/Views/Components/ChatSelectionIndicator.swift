//
//  ChatSelectionIndicator.swift
//  PocketAI
//
//  Created by devon jerothe on 3/13/25.
//

import SwiftUI

struct SelectionCircle: View {
    @Environment(\.appTheme) private var appTheme

    let isSelected: Bool

    var body: some View {
        Circle()
            .fill(isSelected ? appTheme.tintColor.color : appTheme.secondaryBackgroundColor.color.opacity(0.6))
            .stroke(appTheme.tintColor.color, lineWidth: 0.5)
            .frame(minWidth: 24, maxWidth: 24)
            .animation(.spring(response: 0.2), value: isSelected)
    }
}
