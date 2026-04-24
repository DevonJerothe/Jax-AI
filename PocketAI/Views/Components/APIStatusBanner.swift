//
//  APIStatusBanner.swift
//  PocketAI
//
//  Created by devon jerothe on 6/4/25.
//

import SwiftUI

struct APIStatusBanner: View {
    @Environment(NavigationManager.self) var navManager
    var stayOnPath: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: "wifi.slash")
                .foregroundColor(.red)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("API Disconnected")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Tap to connect in Settings")
                    .font(.subheadline)
                    .foregroundColor(.red.opacity(0.6))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.red)
                .font(.caption)
        }
        .padding(16)
        .background(Color.red.opacity(0.2))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
        .onTapGesture {
            // Navigate to settings
            navManager.navigateToSettings(keepCurrentPath: self.stayOnPath)
        }
        .glassEffect(
            .regular.interactive(),
            in: RoundedRectangle(cornerRadius: 12)
        )
    }
}
