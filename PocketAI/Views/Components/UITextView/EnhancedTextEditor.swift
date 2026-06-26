//
//  EnhancedTextEditor.swift
//  PocketAI
//
//  Created by devon jerothe on 4/3/25.
//

import SwiftUI
import UIKit

private final class BoundedTextView: UITextView {
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }
}

struct RepresentableTextView: UIViewRepresentable {

    // MARK: - Properties
    @Binding var text: String
    let maxHeight: CGFloat
    var font: UIFont = UIFont.preferredFont(forTextStyle: .body)  // Allow font customization
    var textColor: UIColor = .label  // Allow text color customization

    @Binding var calculatedHeight: CGFloat  // To report height back to SwiftUI

    // MARK: - UIViewRepresentable Methods

    func makeUIView(context: Context) -> UITextView {
        let textView = BoundedTextView()

        // --- Configuration ---
        textView.delegate = context.coordinator
        textView.font = font
        textView.textColor = textColor
        textView.isScrollEnabled = false  // Disable scrolling initially
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(
            top: 8, left: 5, bottom: 8, right: 5)  // Default padding
        textView.contentInsetAdjustmentBehavior = .never
        textView.clipsToBounds = true
        textView.layer.masksToBounds = true
        textView.setContentHuggingPriority(.defaultLow, for: .vertical)
        textView.setContentCompressionResistancePriority(
            .defaultLow, for: .vertical)
        textView.setContentCompressionResistancePriority(
            .defaultLow, for: .horizontal)  // Allow horizontal compression
        textView.inlinePredictionType = .no

        // --- Swipe Down Gesture (Dismiss Keyboard) ---
        let swipeDownGesture = UISwipeGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.handleSwipeDown(_:)))
        swipeDownGesture.direction = .down
        swipeDownGesture.delegate = context.coordinator  // Use delegate to control when it should begin
        textView.addGestureRecognizer(swipeDownGesture)

        // --- Swipe Up Gesture (Present Keyboard) ---
        let swipeUpGesture = UISwipeGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.handleSwipeUp(_:)))
        swipeUpGesture.direction = .up
        // No special delegate logic needed for swipe up generally,
        // unless conflicts arise with other custom gestures.
        textView.addGestureRecognizer(swipeUpGesture)

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != self.text {
            let cursorLocation = uiView.selectedRange  // Store cursor position
            uiView.text = self.text
            // Restore cursor position after text update
            // Ensure location is within new text bounds
            let newLocation = max(0, min(cursorLocation.location, uiView.text.count))
            uiView.selectedRange = NSRange(location: newLocation, length: 0)  // Length 0 for caret
        }

        if uiView.font != self.font {
            uiView.font = self.font
        }

        if uiView.textColor != self.textColor {
            uiView.textColor = self.textColor
        }

        if uiView.contentInsetAdjustmentBehavior != .never {
            uiView.contentInsetAdjustmentBehavior = .never
        }

        if uiView.clipsToBounds == false {
            uiView.clipsToBounds = true
        }

        // Recalculate height (deferred to avoid state modification during view update)
        DispatchQueue.main.async {
            context.coordinator.recalculateHeight(textView: uiView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: UITextView,
        context: Context
    ) -> CGSize? {
        let width = proposal.width ?? uiView.bounds.width
        let measuredSize = uiView.sizeThatFits(
            CGSize(
                width: max(width, 1),
                height: CGFloat.greatestFiniteMagnitude
            )
        )
        // Fill the proposed height so taps register across the entire frame,
        // not just the lines containing text. When no height is proposed, fall
        // back to the measured content height. Overflow beyond maxHeight is
        // handled by enabling scrolling in the coordinator.
        let proposedHeight = proposal.height ?? measuredSize.height
        let height = min(maxHeight, max(proposedHeight, measuredSize.height))

        return CGSize(width: width, height: height)
    }

    // MARK: - Coordinator Class

    class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var parent: RepresentableTextView
        // Keep track of the specific gesture recognizers if needed for delegate methods
        weak var swipeDownGestureRecognizer: UISwipeGestureRecognizer?

        init(_ parent: RepresentableTextView) {
            self.parent = parent
        }

        // MARK: - UITextViewDelegate Methods

        func textViewDidChange(_ textView: UITextView) {
            // Update the binding
            // Avoid infinite loop: Only update if the text actually changed
            if parent.text != textView.text {
                parent.text = textView.text
            }

            // Recalculate and update height
            recalculateHeight(textView: textView)
        }

        // MARK: - Height Calculation

        func recalculateHeight(textView: UITextView) {
            // Ensure layout is up-to-date before calculating size
            textView.layoutIfNeeded()

            let width = max(textView.bounds.width, textView.frame.width, 1)
            let newSize = textView.sizeThatFits(
                CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
            let targetHeight = min(newSize.height, parent.maxHeight)

            // Update height binding only if changed
            if abs(parent.calculatedHeight - targetHeight) > 1 {  // Use a small tolerance
                parent.calculatedHeight = targetHeight
            }

            let shouldEnableScrolling = newSize.height > parent.maxHeight
            if textView.isScrollEnabled != shouldEnableScrolling {
                textView.isScrollEnabled = shouldEnableScrolling
                // If scrolling is enabled, ensure content offset is adjusted if needed,
                // especially if text shrinks back below max height.
                if !shouldEnableScrolling {
                    textView.contentOffset = .zero  // Reset scroll position when disabling
                }
            }
        }
        // MARK: - Gesture Handling

        @objc func handleSwipeDown(_ gesture: UISwipeGestureRecognizer) {
            // This action should only be triggered if scrolling is disabled,
            // enforced by gestureRecognizerShouldBegin.
            guard let textView = gesture.view as? UITextView else { return }
            if !textView.isScrollEnabled {
                textView.resignFirstResponder()  // Dismiss keyboard
            }
        }

        @objc func handleSwipeUp(_ gesture: UISwipeGestureRecognizer) {
            guard let textView = gesture.view as? UITextView else { return }
            // Present keyboard only if it's not already the first responder
            if !textView.isFirstResponder {
                textView.becomeFirstResponder()
            }
        }

        // MARK: - UIGestureRecognizerDelegate

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            // Check if this is *our* swipe down gesture recognizer
            if let swipeGesture = gestureRecognizer as? UISwipeGestureRecognizer,
                swipeGesture.direction == .down
            {
                guard let textView = swipeGesture.view as? UITextView else { return false }
                // Only allow the swipe down (to dismiss keyboard) gesture to begin
                // if the text view is NOT scrollable. Otherwise, let the default
                // scroll pan gesture handle the swipe down.
                let shouldBegin = !textView.isScrollEnabled
                return shouldBegin
            }
            // Allow other gestures (like swipe up or the internal pan gesture) to begin
            return true
        }

        // You might still need this if you have complex interactions,
        // but often gestureRecognizerShouldBegin is sufficient for priority.
        // Test if removing this causes issues. If scrolling works fine without it, remove it.
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            // Generally, we don't want our discrete swipes to interfere with the continuous pan gesture for scrolling.
            // Let's be more specific: only allow simultaneous recognition if *neither* is our swipe down.
            // Or simply return false if gestureRecognizerShouldBegin handles the priority correctly.
            // Let's try returning false initially. If it breaks something, we can refine.

            // Check if it's the text view's internal pan gesture
            guard let textView = gestureRecognizer.view as? UITextView else { return false }
            if otherGestureRecognizer == textView.panGestureRecognizer {
                // Don't recognize our swipes simultaneously with the scroll pan gesture.
                return false
            }
            // Allow simultaneous recognition for other potential gesture combinations if needed.
            return true  // Reverted: Let's allow simultaneous and let UIKit figure it out based on shouldBegin.
        }
    }
}

// MARK: - SwiftUI View (`EnhancedTextEditor`)

struct EnhancedTextEditor: View {
    @Binding var text: String
    let placeholder: String
    var maxHeight: CGFloat = 200  // Default max height
    var minHeight: CGFloat = 44  // Default min height (approx 1 line)

    // Configuration options (optional)
    var font: UIFont = UIFont.preferredFont(forTextStyle: .body)
    var textColor: UIColor = .label
    var placeholderColor: UIColor = .placeholderText
    var backgroundColor: Color = Color(.clear)  // Background for the frame

    @State private var calculatedHeight: CGFloat

    // Initialize calculatedHeight with minHeight
    init(
        text: Binding<String>, placeholder: String, maxHeight: CGFloat = 200,
        minHeight: CGFloat = 44,
        font: UIFont = UIFont.preferredFont(forTextStyle: .body),
        textColor: UIColor = .label,
        placeholderColor: UIColor = .placeholderText,
        backgroundColor: Color = Color(.clear)
    ) {
        self._text = text
        self.placeholder = placeholder
        self.maxHeight = maxHeight
        self.minHeight = minHeight
        self.font = font
        self.textColor = textColor
        self.placeholderColor = placeholderColor
        self.backgroundColor = backgroundColor
        self._calculatedHeight = State(initialValue: minHeight)  // Use minHeight for initial state
    }

    var body: some View {
        let editorHeight = min(maxHeight, max(minHeight, calculatedHeight))

        RepresentableTextView(
            text: $text,
            maxHeight: maxHeight,
            font: font,
            textColor: textColor,
            calculatedHeight: $calculatedHeight
        )
        .frame(height: editorHeight, alignment: .topLeading)
        .overlay(
            alignment: .topLeading,
            content: {
                if text.isEmpty && placeholder.isEmpty == false {
                    Text(placeholder)
                        .foregroundStyle(Color(placeholderColor))
                        .padding(.leading, 14)
                        .padding(.top, 14)
                        .allowsHitTesting(false)
                }
            }
        )
        .cornerRadius(8)
        .clipped()
    }
}
