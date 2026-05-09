import Foundation
import SwiftUI
import UIKit

struct ScrollViewHelper: UIViewRepresentable {
    let onFound: (UIScrollView) -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            var current: UIView? = view
            while let parent = current?.superview {
                if let scrollView = parent as? UIScrollView {
                    onFound(scrollView)
                    break
                }
                current = parent
            }
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}