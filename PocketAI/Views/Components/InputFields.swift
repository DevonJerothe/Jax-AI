import SwiftUI 

public struct FormField: View {
    let title: String 
    let textBinding: Binding<String>

    public init(title: String, textBinding: Binding<String>) {
        self.title = title 
        self.textBinding = textBinding
    }

    public var body: some View {
        VStack(alignment: .leading) {
            Text(title) 
                .foregroundColor(.primary)

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
                .foregroundColor(.primary)

            ZStack(alignment: .topLeading) {
                if textBinding.wrappedValue.isEmpty {
                    Text(placeholder)
                        .foregroundColor(.secondary)
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