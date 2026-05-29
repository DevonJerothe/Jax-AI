import SwiftUI
import Collections

struct NewTemplateView: View {
    @Environment(NavigationManager.self) var navManager
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
        AppSheetContainer {
            VStack(alignment: .leading, spacing: 20) {
                AppSheetHeader(
                    title: templateKey == nil ? "New Template" : "Edit Template",
                    subtitle: "Name the template and define the instructions added to chat context."
                )

                VStack(alignment: .leading, spacing: 16) {
                    AppSheetField(
                        title: "Template Name",
                        placeholder: "Roleplay",
                        text: $templateName
                    )

                    AppSheetEditor(
                        title: "Template Content",
                        placeholder: "Enter template instructions...",
                        text: $templateContent
                    )

                    AppSheetOptionCard {
                        Toggle(isOn: $isEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Enabled")
                                    .foregroundStyle(appTheme.primaryText.color)

                                Text("Include this template in new model context.")
                                    .font(.caption)
                                    .foregroundStyle(appTheme.secondaryText.color)
                            }
                        }
                        .tint(appTheme.tintColor.color)
                    }
                }

                actionRow
            }
        }
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

    private var actionRow: some View {
        HStack(spacing: 12) {
            if templateKey != nil {
                Button {
                    deleteTemplate()
                } label: {
                    Label("Delete", systemImage: "trash")
                        .labelStyle(.iconOnly)
                        .frame(width: 44, height: 44)
                }
                .foregroundStyle(appTheme.destructiveAction.color)
                .background(appTheme.secondaryBackgroundColor.color)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel("Delete Template")
            }

            Spacer()

            Button {
                navManager.presentedSheet = nil
            } label: {
                Text("Cancel")
                    .fontWeight(.semibold)
                    .frame(minWidth: 84)
            }
            .buttonStyle(AppSheetButtonStyle(kind: .secondary))

            Button {
                updateEditTemplate()
            } label: {
                Text("Save")
                    .fontWeight(.semibold)
                    .frame(minWidth: 84)
            }
            .buttonStyle(AppSheetButtonStyle(kind: .primary))
            .disabled(
                templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    templateContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
    }

    private func deleteTemplate() {
        guard let key = templateKey else { return }
        
        // Create a new dictionary without the template to trigger @Observable
        var newTemplates = connectionManager.connectionSettings.userTemplates
        newTemplates.removeValue(forKey: key)
        
        // Reassign the entire dictionary to trigger SwiftUI updates
        connectionManager.update(\.userTemplates, to: newTemplates)
        navManager.presentedSheet = nil
    }

    private func updateEditTemplate() {
        let trimmedName = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = templateContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty && !trimmedContent.isEmpty else { return }
        
        let template = TemplateModel(content: templateContent, isEnabled: isEnabled)
        var templates = connectionManager.connectionSettings.userTemplates
        
        // Add or update the template. If updating an existing template key, keep its original position.
        templates.updateValue(template, forKey: trimmedName)
        
        if let templateKey,
           templateKey != trimmedName,
           let oldIndex = templates.index(forKey: templateKey),
           let newIndex = templates.index(forKey: trimmedName) {
            templates.swapAt(oldIndex, newIndex)
            templates.removeValue(forKey: templateKey)
        }
        
        connectionManager.update(\.userTemplates, to: templates)
        navManager.presentedSheet = nil
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
