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

struct APIStatusInlineBanner: View {
    @Environment(\.appTheme) private var appTheme

    var title: String
    var message: String
    var recoverySuggestion: String?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.callout)
                .foregroundColor(appTheme.destructiveAction.color)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(appTheme.primaryText.color)

                Text(message)
                    .font(.footnote)
                    .foregroundColor(appTheme.primaryText.color)
                    .fixedSize(horizontal: false, vertical: true)

                if let recoverySuggestion, recoverySuggestion.isEmpty == false {
                    Text(recoverySuggestion)
                        .font(.caption)
                        .foregroundColor(appTheme.destructiveAction.color.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: UIApplication.currentScreenWidth * 0.86, alignment: .leading)
        .background(appTheme.destructiveAction.color.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(appTheme.destructiveAction.color.opacity(0.28), lineWidth: 1)
        )
    }
}
