import SwiftUI

struct GeneralSettingsView: View {
    @Environment(ServiceContainer.self) private var serviceContainer
    @State private var booruViewModel: BotBooruViewModel = .init(loadPosts: false)
    @State private var chubViewModel: ChubAIViewModel = .init(loadCards: false)
    @State private var passcode = ""
    @State private var confirmPasscode = ""
    @State private var passcodeError: String?
    @State private var showSetPasscodeAlert = false
    @State private var showUnlockAlert = false

    private var connectionManager: ConnectionStatusManager {
        serviceContainer.getConnectionStatusManager()
    }

    private var savedPasscode: String? {
        UserDefaultsManager.shared.fetchUserLock()
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
                }

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

                SettingsCard("App Settings") {
                    appLockSection

                    // auto connect toggle 
                    Toggle(isOn: Binding(
                        get: { connectionManager.connectionSettings.autoConnect },
                        set: { connectionManager.update(\.autoConnect, to: $0) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-Connect on Reopen")
                            Text("Connect to the last used service when the app is opened again.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
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
                Image(systemName: connectionManager.connectionSettings.locked ? "lock.fill" : "lock.open")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(width: 30, height: 30)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(connectionManager.connectionSettings.locked ? "App Locked" : "App Unlocked")
                        .foregroundStyle(.primary)

                    Text("Private chats and characters are hidden while locked.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

                Text("Passcodes cannot be reset without resetting the app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    handleLockButtonTapped()
                } label: {
                    Label(
                        connectionManager.connectionSettings.locked ? "Unlock App" : "Lock App",
                        systemImage: connectionManager.connectionSettings.locked ? "lock.open" : "lock"
                    )
                }
                .buttonStyle(.borderedProminent)

                Toggle(isOn: Binding(
                    get: { connectionManager.connectionSettings.autoLock },
                    set: { connectionManager.update(\.autoLock, to: $0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-Lock on Reopen")
                        Text("Lock the app whenever it is opened again.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let passcodeError {
                Text(passcodeError)
                    .font(.caption)
                    .foregroundStyle(.red)
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
