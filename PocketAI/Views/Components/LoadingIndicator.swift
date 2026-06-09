//
//  LoadingIndicator.swift
//  PocketAI
//
//  Created by devon jerothe on 3/13/25.
//

import SwiftUI
import Combine


struct LoadingIndicator: View {
    let thinking: Bool 
    let frame: CGSize
    let primaryColor: Color
    let timing: Double
    
    @State private var animatedThinking = false

    init(color: Color = .accentColor, size: CGFloat = 50, speed: Double = 0.5, thinking: Bool = false) {
        timing = speed / 2
        frame = CGSize(width: size, height: size)
        primaryColor = color
        self.thinking = thinking
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                ForEach(0..<3) { index in
                    BouncingDot(
                        color: primaryColor,
                        size: frame.height / 4,
                        delay: Double(index) * timing,
                        timing: timing
                    )
                }
            }

            if animatedThinking {
                Text("thinking...")
                    .font(.callout)
                    .foregroundColor(primaryColor)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(
            width: animatedThinking ? frame.width + 90 : frame.width,
            height: frame.height,
            alignment: .leading
        )
        .onChange(of: thinking) { _, newValue in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                animatedThinking = newValue
            }
        }
        .onAppear {
            animatedThinking = thinking
        }
    }
}

struct BouncingDot: View {
    let color: Color
    let size: CGFloat
    let delay: Double
    let timing: Double
    
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .offset(y: isAnimating ? -size / 2 : size / 2)
            .animation(
                .easeInOut(duration: timing * 2)
                .repeatForever(autoreverses: true)
                .delay(delay),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

#Preview {
    VStack(spacing: 30) {
        VStack {
            Text("Regular Loading")
                .font(.caption)
                .foregroundColor(.secondary)
            LoadingIndicator()
        }
        
        VStack {
            Text("Thinking Mode")
                .font(.caption)
                .foregroundColor(.secondary)
            LoadingIndicator(thinking: true)
        }
    }
    .padding()
}
