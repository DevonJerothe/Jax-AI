//
//  ChatSelectionIndicator.swift
//  PocketAI
//
//  Created by devon jerothe on 3/13/25.
//

import SwiftUI

struct SelectionCircle: View {
    let isSelected: Bool

    var body: some View {
        Circle()
            .fill(isSelected ? .white : .white.opacity(0.1))
            .stroke(Color.white, lineWidth: 0.5)
            .frame(minWidth: 24, maxWidth: 24)
            .animation(.spring(response: 0.2), value: isSelected)
    }
}
