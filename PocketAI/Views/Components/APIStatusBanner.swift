//
//  APIStatusBanner.swift
//  PocketAI
//
//  Created by devon jerothe on 6/4/25.
//

import SwiftUI

struct APIStatusBanner: View {
    @Environment(NavigationManager.self) var navManager
    @Environment(\.appTheme) private var appTheme
    var stayOnPath: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: "wifi.slash")
                .foregroundColor(appTheme.destructiveAction.color)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("API Disconnected")
                    .font(.headline)
                    .foregroundColor(appTheme.primaryText.color)
                
                Text("Tap to connect in Settings")
                    .font(.subheadline)
                    .foregroundColor(appTheme.destructiveAction.color.opacity(0.75))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(appTheme.destructiveAction.color)
                .font(.caption)
        }
        .padding(16)
        .background(appTheme.destructiveAction.color.opacity(0.18))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(appTheme.destructiveAction.color.opacity(0.3), lineWidth: 1)
        )
        .onTapGesture {
            navManager.navigateToConnectionSettings(keepCurrentPath: self.stayOnPath)
        }
        .glassEffect(
            .regular.interactive(),
            in: RoundedRectangle(cornerRadius: 12)
        )
    }
}
