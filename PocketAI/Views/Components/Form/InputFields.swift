import SwiftUI 

public struct FormField: View {
    let title: String 
    let textBinding: Binding<String>

    public init(title: String, textBinding: Binding<String>) {
        self.title = title 
        self.textBinding = textBinding
    }

    public var body: some View {
        ThemedTextField(
            title: title,
            placeholder: title,
            text: textBinding,
            autocapitalization: .never
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

public struct FormEditor: View {
    let title: String 
    let placeholder: String 
    let textBinding: Binding<String>

    public init(title: String, placeholder: String, textBinding: Binding<String>) {
        self.title = title 
        self.placeholder = placeholder 
        self.textBinding = textBinding
    }

    public var body: some View {
        ThemedTextEditor(
            title: title,
            placeholder: placeholder,
            text: textBinding,
            height: 275
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
