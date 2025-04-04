//
//  LoadingIndicator.swift
//  PocketAI
//
//  Created by devon jerothe on 3/13/25.
//

import SwiftUI
import Combine


struct LoadingIndicator: View {

    let timer: Publishers.Autoconnect<Timer.TimerPublisher>
    let timing: Double

    @State var counter = 0

    let frame: CGSize
    let primaryColor: Color

    init(color: Color = .accentColor, size: CGFloat = 50, speed: Double = 0.5) {
        timing = speed / 2
        timer = Timer.publish(every: timing, on: .main, in: .common).autoconnect()
        frame = CGSize(width: size, height: size)
        primaryColor = color
    }

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { index in
                Circle()
                    .offset(y: counter == index ? -frame.height / 10 : frame.height / 10)
                    .fill(primaryColor)
            }
        }
        .frame(width: frame.width, height: frame.height, alignment: .center)
        .onReceive(timer, perform: { _ in
            withAnimation(.easeInOut(duration: timing * 2)) {
                counter = counter == (3 - 1) ? 0 : counter + 1
            }
        })
    }
}

#Preview {
    LoadingIndicator()
}
