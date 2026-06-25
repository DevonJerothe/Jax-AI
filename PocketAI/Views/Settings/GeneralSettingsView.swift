import SwiftUI

struct GeneralSettingsView: View {
    @Environment(ServiceContainer.self) private var serviceContainer
    @Environment(\.appTheme) private var appTheme
    @State private var passcode = ""
    @State private var confirmPasscode = ""
    @State private var passcodeError: String?
    @State private var showSetPasscodeAlert = false
    @State private var showUnlockAlert = false

    #if !APPSTORE
        @State private var booruViewModel: BotBooruViewModel = .init()
        @State private var chubViewModel: ChubAIViewModel = .init()
    #endif

    private var connectionManager: ConnectionStatusManager {
        serviceContainer.getConnectionStatusManager()
    }

    private var savedPasscode: String? {
        UserDefaultsManager.shared.fetchUserLock()
    }

    private var currentThemeName: String {
        AvailableThemes.themeCase(for: connectionManager.connectionSettings.currentTheme).rawValue
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsCard("Core") {
                    NavigationLink {
                        ConnectionSettingsView()
                    } label: {
                        SettingsNavigationRow(
                            title: "Connection",
                            subtitle: "Provider, model, context, and response length",
                            systemImage: "network"
                        )
                    }
                    .buttonStyle(.plain)

                    Divider()

                    NavigationLink {
                        SamplerSettingsView()
                    } label: {
                        SettingsNavigationRow(
                            title: "Sampler",
                            subtitle: "Control how responses are sent and received",
                            systemImage: "sparkles"
                        )
                    }
                    .buttonStyle(.plain)

                    Divider()

                    NavigationLink {
                        UserPersonaView(personaStore: serviceContainer.getPersonaStore())
                    } label: {
                        SettingsNavigationRow(
                            title: "Persona",
                            subtitle: "Manage your persona",
                            systemImage: "person"
                        )
                    }
                }

                #if !APPSTORE
                    SettingsCard("Browsers") {
                        NavigationLink {
                            BooruBrowserSettingsView(viewModel: booruViewModel)
                        } label: {
                            SettingsNavigationRow(
                                title: "BotBooru",
                                subtitle: "Account login and browsing filters",
                                systemImage: "photo.on.rectangle"
                            )
                        }
                        .buttonStyle(.plain)

                        Divider()

                        NavigationLink {
                            ChubAISettingsView(viewModel: chubViewModel)
                        } label: {
                            SettingsNavigationRow(
                                title: "Chub AI",
                                subtitle: "Content filters and excluded topics",
                                systemImage: "person.2.crop.square.stack"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                #endif

                SettingsCard("App Settings") {
                    appLockSection

                    // auto connect toggle
                    Toggle(
                        isOn: Binding(
                            get: { connectionManager.connectionSettings.autoConnect },
                            set: { connectionManager.update(\.autoConnect, to: $0) }
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-Connect on Reopen")
                            Text("Connect to the last used service when the app is opened again.")
                                .font(.caption)
                                .foregroundStyle(appTheme.secondaryText.color)
                        }
                    }
                    .tint(appTheme.tintColor.color)

                    Divider()

                    Toggle(
                        isOn: Binding(
                            get: { connectionManager.connectionSettings.autoScrollChat },
                            set: { connectionManager.update(\.autoScrollChat, to: $0) }
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Scroll With Response")
                            Text("Auto scroll the chat view as content is streamed.")
                                .font(.caption)
                                .foregroundStyle(appTheme.secondaryText.color)
                        }
                    }
                    .tint(appTheme.tintColor.color)

                    Divider()

                    NavigationLink {
                        ThemeSettingsView()
                    } label: {
                        SettingsNavigationRow(
                            title: "App Theme",
                            subtitle: "Currently \(currentThemeName)",
                            systemImage: "paintpalette.fill"
                        )
                    }
                }
            }
            .padding(16)
        }
        .background(appTheme.backgroundColor.color)
        .scrollIndicators(.hidden)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert("Set App Lock Passcode", isPresented: $showSetPasscodeAlert) {
            SecureField("New Passcode", text: $passcode)
                .textContentType(.newPassword)
                .keyboardType(.numberPad)

            SecureField("Confirm Passcode", text: $confirmPasscode)
                .textContentType(.newPassword)
                .keyboardType(.numberPad)

            Button("Set Passcode") {
                saveInitialPasscode()
            }

            Button("Cancel", role: .cancel) {
                resetPasscodeEntry()
            }
        } message: {
            Text("Passcodes cannot be reset without resetting the app.")
        }
        .alert("Unlock App", isPresented: $showUnlockAlert) {
            SecureField("Passcode", text: $passcode)
                .textContentType(.password)
                .keyboardType(.numberPad)

            Button("Unlock") {
                authenticateAndUnlock()
            }

            Button("Cancel", role: .cancel) {
                resetPasscodeEntry()
            }
        } message: {
            Text("Enter your app lock passcode to show private content.")
        }
    }

    private var appLockSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(
                    systemName: connectionManager.connectionSettings.locked
                        ? "lock.fill" : "lock.open"
                )
                .font(.headline)
                .foregroundStyle(appTheme.primaryText.color)
                .frame(width: 30, height: 30)
                .background(appTheme.secondaryAction.color)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        connectionManager.connectionSettings.locked ? "App Locked" : "App Unlocked"
                    )
                    .foregroundStyle(appTheme.primaryText.color)

                    Text("Private chats and characters are hidden while locked.")
                        .font(.caption)
                        .foregroundStyle(appTheme.secondaryText.color)
                }
            }

            Divider()

            if savedPasscode == nil {
                Button {
                    resetPasscodeEntry()
                    showSetPasscodeAlert = true
                } label: {
                    Label("Set Passcode and Lock App", systemImage: "lock")
                }
                .buttonStyle(.borderedProminent)
                .tint(appTheme.primaryAction.color)

                Text("Passcodes cannot be reset without resetting the app.")
                    .font(.caption)
                    .foregroundStyle(appTheme.secondaryText.color)
            } else {
                Button {
                    handleLockButtonTapped()
                } label: {
                    Label(
                        connectionManager.connectionSettings.locked ? "Unlock App" : "Lock App",
                        systemImage: connectionManager.connectionSettings.locked
                            ? "lock.open" : "lock"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(appTheme.primaryAction.color)

                Toggle(
                    isOn: Binding(
                        get: { connectionManager.connectionSettings.autoLock },
                        set: { connectionManager.update(\.autoLock, to: $0) }
                    )
                ) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-Lock on Reopen")
                        Text("Lock the app whenever it is opened again.")
                            .font(.caption)
                            .foregroundStyle(appTheme.secondaryText.color)
                    }
                }
                .tint(appTheme.tintColor.color)
            }

            if let passcodeError {
                Text(passcodeError)
                    .font(.caption)
                    .foregroundStyle(appTheme.destructiveAction.color)
            }
        }
    }

    private func saveInitialPasscode() {
        guard passcode.isEmpty == false, confirmPasscode.isEmpty == false else {
            passcodeError = "Enter and confirm a passcode."
            resetPasscodeEntry()
            return
        }

        guard passcode == confirmPasscode else {
            passcodeError = "Passcodes do not match."
            resetPasscodeEntry()
            return
        }

        UserDefaultsManager.shared.saveUserLock(pass: passcode)
        connectionManager.update(\.locked, to: true)
        passcodeError = nil
        resetPasscodeEntry()
    }

    private func handleLockButtonTapped() {
        if connectionManager.connectionSettings.locked {
            resetPasscodeEntry()
            showUnlockAlert = true
        } else {
            connectionManager.update(\.locked, to: true)
            passcodeError = nil
        }
    }

    private func authenticateAndUnlock() {
        guard passcode.isEmpty == false else {
            passcodeError = "Enter your passcode."
            resetPasscodeEntry()
            return
        }

        guard passcode == savedPasscode else {
            passcodeError = "Incorrect passcode."
            resetPasscodeEntry()
            return
        }

        connectionManager.update(\.locked, to: false)
        passcodeError = nil
        resetPasscodeEntry()
    }

    private func resetPasscodeEntry() {
        passcode = ""
        confirmPasscode = ""
    }
}

struct ThemeSettingsView: View {
    @Environment(ServiceContainer.self) private var serviceContainer
    @Environment(\.appTheme) private var appTheme
    @Environment(\.colorScheme) private var colorScheme

    private var connectionManager: ConnectionStatusManager {
        serviceContainer.getConnectionStatusManager()
    }

    private var selectedTheme: AvailableThemes {
        AvailableThemes.themeCase(for: connectionManager.connectionSettings.currentTheme)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsCard("Current Theme") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: "paintpalette.fill")
                                .font(.headline)
                                .foregroundStyle(appTheme.primaryText.color)
                                .frame(width: 30, height: 30)
                                .background(appTheme.secondaryAction.color)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(selectedTheme.rawValue)
                                    .foregroundStyle(appTheme.primaryText.color)

                                Text("Used across navigation, controls, and surfaces.")
                                    .font(.caption)
                                    .foregroundStyle(appTheme.secondaryText.color)
                            }

                            Spacer()

                            HStack(spacing: 8) {
                                ForEach(
                                    themePreviewColors(
                                        for: connectionManager.connectionSettings.currentTheme
                                    ).indices, id: \.self
                                ) { index in
                                    Circle()
                                        .fill(
                                            themePreviewColors(
                                                for: connectionManager.connectionSettings
                                                    .currentTheme)[index]
                                        )
                                        .frame(width: 16, height: 16)
                                        .overlay {
                                            Circle()
                                                .stroke(
                                                    appTheme.borderColor.color.opacity(0.45),
                                                    lineWidth: 1)
                                        }
                                }
                            }
                        }

                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                connectionManager.connectionSettings.currentTheme
                                    .secondaryBackgroundColor.color(for: colorScheme)
                            )
                            .frame(height: 84)
                            .overlay(alignment: .topLeading) {
                                VStack(alignment: .leading, spacing: 10) {
                                    Capsule()
                                        .fill(
                                            connectionManager.connectionSettings.currentTheme
                                                .primaryAction.color(for: colorScheme)
                                        )
                                        .frame(width: 96, height: 10)

                                    HStack(spacing: 10) {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(
                                                connectionManager.connectionSettings.currentTheme
                                                    .tintColor.color(for: colorScheme)
                                            )
                                            .frame(width: 72, height: 32)

                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(
                                                connectionManager.connectionSettings.currentTheme
                                                    .borderColor.color(for: colorScheme),
                                                lineWidth: 1
                                            )
                                            .background(
                                                RoundedRectangle(
                                                    cornerRadius: 10, style: .continuous
                                                )
                                                .fill(
                                                    connectionManager.connectionSettings
                                                        .currentTheme.backgroundColor.color(
                                                            for: colorScheme))
                                            )
                                            .frame(width: 92, height: 32)
                                    }
                                }
                                .padding(14)
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(appTheme.borderColor.color.opacity(0.5), lineWidth: 1)
                            }
                    }
                }

                SettingsCard("Available Themes") {
                    Text(
                        "Pick the palette that feels right. Changes apply immediately throughout the app."
                    )
                    .font(.caption)
                    .foregroundStyle(appTheme.secondaryText.color)

                    ForEach(AvailableThemes.allCases) { themeOption in
                        if themeOption != AvailableThemes.allCases.first {
                            Divider()
                        }

                        Button {
                            connectionManager.update(\.currentTheme, to: themeOption.theme)
                        } label: {
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        Text(themeOption.rawValue)
                                            .foregroundStyle(appTheme.primaryText.color)

                                        if themeOption == selectedTheme {
                                            Text("Selected")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(
                                                    themeOption.theme.primaryAction.color(
                                                        for: colorScheme)
                                                )
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(
                                                    themeOption.theme.secondaryAction.color(
                                                        for: colorScheme)
                                                )
                                                .clipShape(Capsule())
                                        }
                                    }

                                    HStack(spacing: 8) {
                                        ForEach(
                                            themePreviewColors(for: themeOption.theme).indices,
                                            id: \.self
                                        ) { index in
                                            Circle()
                                                .fill(
                                                    themePreviewColors(for: themeOption.theme)[
                                                        index]
                                                )
                                                .frame(width: 18, height: 18)
                                                .overlay {
                                                    Circle()
                                                        .stroke(
                                                            appTheme.borderColor.color.opacity(
                                                                0.45), lineWidth: 1)
                                                }
                                        }
                                    }
                                }

                                Spacer()

                                Image(
                                    systemName: themeOption == selectedTheme
                                        ? "checkmark.circle.fill" : "circle"
                                )
                                .font(.title3)
                                .foregroundStyle(
                                    themeOption == selectedTheme
                                        ? themeOption.theme.primaryAction.color(for: colorScheme)
                                        : appTheme.borderColor.color
                                )
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                themeOption.theme.secondaryBackgroundColor.color(for: colorScheme)
                                    .opacity(0.9)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        themeOption == selectedTheme
                                            ? themeOption.theme.primaryAction.color(
                                                for: colorScheme)
                                            : appTheme.borderColor.color.opacity(0.65),
                                        lineWidth: themeOption == selectedTheme ? 1.5 : 1
                                    )
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .background(appTheme.backgroundColor.color)
        .scrollIndicators(.hidden)
        .navigationTitle("Theme")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func themePreviewColors(for theme: AppTheme) -> [Color] {
        [
            theme.primaryAction.color(for: colorScheme),
            theme.tintColor.color(for: colorScheme),
            theme.secondaryAction.color(for: colorScheme),
            theme.backgroundColor.color(for: colorScheme),
        ]
    }
}
