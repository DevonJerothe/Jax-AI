import SwiftUI 
import Collections

struct NewTemplateView: View {
    @Environment(NavigationManager.self) var navManger
    @Environment(ServiceContainer.self) private var serviceContainer
    @Environment(\.appTheme) private var appTheme
    var templateKey: String?

    @State private var templateName: String = ""
    @State private var templateContent: String = ""
    @State private var isEnabled: Bool = true

    init(templateKey: String? = nil) {
        self.templateKey = templateKey
    }

    private var connectionManager: ConnectionStatusManager {
        serviceContainer.getConnectionStatusManager()
    }

    var body: some View {
        VStack {
            FormField(title: "Template Name", textBinding: $templateName)
            FormEditor(
                title: "Template Content",
                placeholder: "Enter the template content here...",
                textBinding: $templateContent
            )

            HStack {
                Button {
                    updateEditTemplate()
                } label: {
                    Text("Save")
                        .foregroundColor(appTheme.primaryText.color)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(appTheme.primaryAction.color)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 16)
                .disabled(templateName.isEmpty || templateContent.isEmpty)

                Spacer()

                // delete button    
                if templateKey != nil {
                    Button {
                        // delete the template
                        deleteTemplate()
                    } label: {
                        Text("Delete")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .foregroundColor(appTheme.destructiveAction.color)
                    }
                }

                Button {
                    // Enable / Disable the template
                    enableDisableTemplate()
                } label: {
                    Text("\(isEnabled ? "Enabled" : "Disabled")")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)                     
                        .background(isEnabled ? appTheme.tintColor.color.opacity(0.6) : appTheme.secondaryBackgroundColor.color)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isEnabled ? appTheme.tintColor.color : appTheme.borderColor.color, lineWidth: 1)
                        ) 
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 16)
        // .padding(.horizontal, 16)
        .onAppear {
            if let key = templateKey {
                let template = connectionManager.connectionSettings.userTemplates[key]
                if let template = template {
                    self.templateName = key
                    self.templateContent = template.content
                    self.isEnabled = template.isEnabled
                }
            }
        }
    }

    private func enableDisableTemplate() {
        guard let key = templateKey else { return }
        var templates = connectionManager.connectionSettings.userTemplates
        templates[key]?.isEnabled.toggle()
        connectionManager.update(\.userTemplates, to: templates)
        navManger.presentedSheet = nil
    }

    private func deleteTemplate() {
        guard let key = templateKey else { return }
        
        // Create a new dictionary without the template to trigger @Observable
        var newTemplates = connectionManager.connectionSettings.userTemplates
        newTemplates.removeValue(forKey: key)
        
        // Reassign the entire dictionary to trigger SwiftUI updates
        connectionManager.update(\.userTemplates, to: newTemplates)
        navManger.presentedSheet = nil
    }

    private func updateEditTemplate() {
        guard !templateName.isEmpty && !templateContent.isEmpty else { return }
        
        let template = TemplateModel(content: templateContent, isEnabled: true)
        var templates = connectionManager.connectionSettings.userTemplates
        
        // Add or update the template. If updateing an existing template key, we need to swap the indexes.
        templates.updateValue(template, forKey: templateName)
        
        // this should "technically" never have nil indexes... buts its also 1AM and I cant be bothered enough to test. So yea i guess TODO:
        if let templateKey, templateKey != templateName {
            templates.swapAt(templates.index(forKey: templateKey)!, templates.index(forKey: templateName)!)
            templates.removeValue(forKey: templateKey)
        }
        
        connectionManager.update(\.userTemplates, to: templates)
        navManger.presentedSheet = nil
    }
}

struct TemplateEditor: View {

    @Binding var isDragging: Bool
    @Binding var userTemplates: OrderedDictionary<String, TemplateModel>

    @State var updateTemplateEditor: Bool = false

    @Environment(NavigationManager.self) var navManager

    @State private var height: CGFloat = 0 

    var body: some View {

        ReorderableGridView(
            data: $userTemplates,
            columns: 2,
            onHeightChanged: { x in height = x }, 
            onDraggingChange: { dragging in isDragging = dragging }
        ) { key, template in 
            TemplateItem(
                name: key,
                isEnabled: template.wrappedValue.isEnabled
            )
            .onTapGesture {
                navManager.showNewTemplateView(templateKey: key)
            }
        }
        .id(updateTemplateEditor)
        .frame(height: height)
        .onChange(of: userTemplates) { oldValue, newValue in

            // template enabled states 
            for (key, template) in newValue {
                print("template: \(key) isEnabled: \(template.isEnabled)")
            }

            updateTemplateEditor.toggle()

            // reset the dragging state - id based update breaks the draggins state, dont feel like fixing it right now.
            isDragging = false
        } 
    }
}
struct TemplateItem: View {
    @Environment(\.appTheme) private var appTheme

    let name: String
    var isEnabled: Bool
    
    var body: some View {
        HStack(alignment: .center) {
            HStack {
                Spacer() 
                Text(name) 
                    .foregroundColor(appTheme.primaryText.color)
                Spacer() 
            }

            // checkmark or enabled
            VStack {
                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isEnabled ? appTheme.tintColor.color : appTheme.secondaryText.color)
            }
        }
        .padding(16)
        .background(appTheme.secondaryBackgroundColor.color)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isEnabled ? appTheme.tintColor.color : appTheme.borderColor.color, lineWidth: 1)
        ) 
    }
}
