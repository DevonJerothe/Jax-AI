import SwiftUI 

public struct FormField: View {
    @Environment(\.appTheme) private var appTheme

    let title: String 
    let textBinding: Binding<String>

    public init(title: String, textBinding: Binding<String>) {
        self.title = title 
        self.textBinding = textBinding
    }

    public var body: some View {
        VStack(alignment: .leading) {
            Text(title) 
                .foregroundColor(appTheme.primaryText.color)

            TextField(title, text: textBinding)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .styledFormField()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

public struct FormEditor: View {
    @Environment(\.appTheme) private var appTheme

    let title: String 
    let placeholder: String 
    let textBinding: Binding<String>

    public init(title: String, placeholder: String, textBinding: Binding<String>) {
        self.title = title 
        self.placeholder = placeholder 
        self.textBinding = textBinding
    }

    public var body: some View {
        VStack(alignment: .leading) {
            Text(title) 
                .foregroundColor(appTheme.primaryText.color)

            ZStack(alignment: .topLeading) {
                if textBinding.wrappedValue.isEmpty {
                    Text(placeholder)
                        .foregroundColor(appTheme.secondaryText.color)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                }

                TextEditor(text: textBinding)
                    .frame(height: 275)
                    .scrollContentBackground(.hidden)  
            }
            .styledFormField()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
