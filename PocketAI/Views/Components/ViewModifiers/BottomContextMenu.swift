import SwiftUI

struct BottomContextMenu<MenuItems: View>: ViewModifier {
    var menuItems: () -> MenuItems
    
    func body(content: Content) -> some View {
        content
            .contextMenu {
                menuItems()
            }
    }
}

extension View {
    func withBottomContextMenu<MenuItems: View>(@ViewBuilder menuItems: @escaping () -> MenuItems) -> some View {
        self.modifier(BottomContextMenu(menuItems: menuItems))
    }
} 