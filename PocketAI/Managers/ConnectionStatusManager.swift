import Foundation
import Observation

enum AppConnectionStatus: String, Sendable {
    case connected
    case connecting
    case disconnected
    case failed

    var label: String {
        switch self {
        case .connected:
            "Status: connected"
        case .connecting:
            "Status: connecting"
        case .disconnected:
            "Status: offline"
        case .failed:
            "Status: failed"
        }
    }
}

@MainActor
@Observable
final class ConnectionStatusManager {
    var connectionStatus: AppConnectionStatus = .disconnected
    var footerNote = "Connect to a service to start chatting"
    var connectionSettings: ConnectionSettingsModel
    var maxContextLength: Int

    @ObservationIgnored private var languageModelService: LanguageModelService?
    @ObservationIgnored private var connectionAttemptID = UUID()

    init() {
        var savedSettings = UserDefaultsManager.shared.fetchConnectionSettings() ?? .defaults
        if savedSettings.autoLock, UserDefaultsManager.shared.fetchUserLock() != nil {
            savedSettings.locked = true
        }
        let normalizedSettings = ConnectionStatusManager.normalize(savedSettings)
        self.connectionSettings = normalizedSettings
        self.maxContextLength =
            normalizedSettings.activeMaxContextLength ?? ConnectionSettingsModel.defaults
            .activeMaxContextLength ?? 25600
        UserDefaultsManager.shared.saveSettings(normalizedSettings, forKey: .ConnectionSettings)
    }

    func attachLanguageModelService(_ languageModelService: LanguageModelService) {
        self.languageModelService = languageModelService
        languageModelService.updateConnectionSettings(connectionSettings)
    }

    func updateSettings(_ newSettings: ConnectionSettingsModel) {
        let normalizedSettings = ConnectionStatusManager.normalize(newSettings)
        let shouldDisconnect = normalizedSettings.criticalConnectionSettingsChanged(
            from: connectionSettings)

        if shouldDisconnect {
            disconnect(reason: "Connection settings changed. Press Connect to reconnect.")
        }

        persistSettings(normalizedSettings)
    }

    func update<Value>(
        _ keyPath: WritableKeyPath<ConnectionSettingsModel, Value>,
        to value: Value
    ) {
        var updatedSettings = connectionSettings
        updatedSettings[keyPath: keyPath] = value
        updateSettings(updatedSettings)
    }

    func updateActiveHost(_ value: String?) {
        var updatedSettings = connectionSettings
        updatedSettings.updateActiveHost(value)
        updateSettings(updatedSettings)
    }

    func updateActivePort(_ value: Int?) {
        var updatedSettings = connectionSettings
        updatedSettings.updateActivePort(value)
        updateSettings(updatedSettings)
    }

    func updateActiveContextLength(_ value: Int?) {
        var updatedSettings = connectionSettings
        updatedSettings.updateActiveContextLength(value)
        updateSettings(updatedSettings)
    }

    func updateActiveMaxContextLength(_ value: Int?) {
        var updatedSettings = connectionSettings
        updatedSettings.updateActiveMaxContextLength(value)
        updateSettings(updatedSettings)
    }

    func updateActiveResponseLength(_ value: Int?) {
        var updatedSettings = connectionSettings
        updatedSettings.updateActiveResponseLength(value)
        updateSettings(updatedSettings)
    }

    func updateActiveAPIKey(_ value: String?) {
        var updatedSettings = connectionSettings
        updatedSettings.updateActiveAPIKey(value)
        updateSettings(updatedSettings)
    }

    func updateActiveSelectedModel(_ value: String?) {
        var updatedSettings = connectionSettings
        updatedSettings.updateActiveSelectedModel(value)
        updateSettings(updatedSettings)
    }

    func saveConnectionSettings() {
        persistSettings(ConnectionStatusManager.normalize(connectionSettings))
    }

    func lockForAppResumeIfNeeded() {
        guard connectionSettings.autoLock, UserDefaultsManager.shared.fetchUserLock() != nil else {
            return
        }

        update(\.locked, to: true)
    }

    func connect() async {
        guard let languageModelService else {
            connectionStatus = .failed
            footerNote = "No connection service available"
            return
        }

        let attemptID = UUID()
        connectionAttemptID = attemptID
        languageModelService.updateConnectionSettings(connectionSettings)

        connectionStatus = .connecting
        footerNote = "Connecting to service..."

        let success = await languageModelService.connect()
        guard connectionAttemptID == attemptID else {
            // A newer connection attempt has superseded this one; the newer
            // attempt is responsible for setting the final status. Leave the
            // status untouched so we don't clobber the in-flight attempt.
            return
        }

        if success {
            connectionStatus = .connected
            footerNote =
                languageModelService.selectedModel ?? connectionSettings.activeSelectedModel
                ?? "Connected"
            synchronizeRuntimeSettings(
                selectedModel: languageModelService.selectedModel,
                maxContextLength: connectionSettings.connectionType == .KoboldAPI
                    ? languageModelService.maxContextLength : nil
            )
        } else {
            connectionStatus = .failed
            footerNote = "Failed to connect to service"
        }
    }

    func refreshAvailableModels() async {
        guard
            connectionSettings.connectionType == .OpenRouter
                || connectionSettings.connectionType == .OpenAI
        else {
            return
        }

        await languageModelService?.getAvailableModels()
    }

    func disconnect(reason: String = "Connection disconnected.") {
        connectionAttemptID = UUID()
        languageModelService?.disconnect()
        languageModelService?.updateConnectionSettings(connectionSettings)
        connectionStatus = .disconnected
        footerNote = reason
    }

    private func persistSettings(_ settings: ConnectionSettingsModel) {
        UserDefaultsManager.shared.saveSettings(settings, forKey: .ConnectionSettings)
        connectionSettings = settings
        maxContextLength =
            settings.activeMaxContextLength ?? ConnectionSettingsModel.defaults
            .activeMaxContextLength ?? 25600
        languageModelService?.updateConnectionSettings(settings)
    }

    private func synchronizeRuntimeSettings(
        selectedModel: String?,
        maxContextLength: Int?
    ) {
        var updatedSettings = connectionSettings

        if let selectedModel {
            updatedSettings.updateActiveSelectedModel(selectedModel)
        }

        if let maxContextLength {
            updatedSettings.updateActiveMaxContextLength(maxContextLength)
            updatedSettings.updateActiveContextLength(
                min(
                    updatedSettings.activeContextLength ?? maxContextLength,
                    maxContextLength
                ))
        }

        persistSettings(ConnectionStatusManager.normalize(updatedSettings))
    }

    private static func normalize(_ settings: ConnectionSettingsModel) -> ConnectionSettingsModel {
        var normalized = settings

        let defaultSettings = ConnectionSettingsModel.defaults
        let defaultKobold = defaultSettings.koboldCPPSettings ?? .init()
        let defaultOpenRouter = defaultSettings.openRouterSettings ?? .init()
        let defaultOpenAI = defaultSettings.openAISettings ?? .init()

        var koboldSettings =
            normalized.koboldCPPSettings
            ?? .init(
                host: defaultKobold.host,
                port: defaultKobold.port,
                maxContextLength: defaultKobold.maxContextLength,
                contextLength: defaultKobold.contextLength,
                responseLength: defaultKobold.responseLength,
                selectedModel: defaultKobold.selectedModel
            )
        var openRouterSettings =
            normalized.openRouterSettings
            ?? .init(
                maxContextLength: defaultOpenRouter.maxContextLength,
                contextLength: defaultOpenRouter.contextLength,
                responseLength: defaultOpenRouter.responseLength,
                apiKey: defaultOpenRouter.apiKey,
                selectedModel: defaultOpenRouter.selectedModel
            )
        var openAISettings = normalized.openAISettings ?? defaultOpenAI

        let koboldMaxContextLength = max(
            koboldSettings.maxContextLength ?? defaultKobold.maxContextLength ?? 25600, 1024)
        let openRouterMaxContextLength = max(
            openRouterSettings.maxContextLength ?? defaultOpenRouter.maxContextLength ?? 256000,
            1024)
        let openAIMaxContextLength = max(
            openAISettings.maxContextLength ?? defaultOpenAI.maxContextLength ?? 256000, 1024)

        koboldSettings.maxContextLength = koboldMaxContextLength
        koboldSettings.contextLength = min(
            max(koboldSettings.contextLength ?? defaultKobold.contextLength ?? 6144, 1024),
            koboldMaxContextLength)
        koboldSettings.responseLength = min(
            max(koboldSettings.responseLength ?? defaultKobold.responseLength ?? 300, 120), 3000)

        openRouterSettings.maxContextLength = openRouterMaxContextLength
        openRouterSettings.contextLength = min(
            max(openRouterSettings.contextLength ?? defaultOpenRouter.contextLength ?? 6144, 1024),
            openRouterMaxContextLength)
        openRouterSettings.responseLength = min(
            max(openRouterSettings.responseLength ?? defaultOpenRouter.responseLength ?? 300, 120),
            3000)

        openAISettings.maxContextLength = openAIMaxContextLength
        openAISettings.contextLength = min(
            max(openAISettings.contextLength ?? defaultOpenAI.contextLength ?? 6144, 1024),
            openAIMaxContextLength)
        openAISettings.responseLength = min(
            max(openAISettings.responseLength ?? defaultOpenAI.responseLength ?? 300, 120), 3000)

        normalized.ensureNonEmptySequences()

        let trimmedHost = koboldSettings.host?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // Allow an empty host while editing so the field can be cleared and retyped.
        // The default host is only seeded on first launch via ConnectionSettingsModel.defaults;
        // a nil/empty host here simply leaves koboldManager unset until the user provides one.
        koboldSettings.host = trimmedHost.isEmpty ? nil : trimmedHost
        koboldSettings.port = koboldSettings.port.map { max($0, 1) }

        let trimmedOpenRouterAPIKey = openRouterSettings.apiKey?.trimmingCharacters(
            in: .whitespacesAndNewlines)
        let trimmedOpenRouterSelectedModel =
            openRouterSettings.selectedModel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        openRouterSettings.apiKey =
            trimmedOpenRouterAPIKey?.isEmpty == true ? nil : trimmedOpenRouterAPIKey
        openRouterSettings.selectedModel =
            trimmedOpenRouterSelectedModel.isEmpty
            ? defaultOpenRouter.selectedModel : trimmedOpenRouterSelectedModel

        let trimmedOpenAIBaseURL =
            openAISettings.baseURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedOpenAIAPIKey = openAISettings.apiKey?.trimmingCharacters(
            in: .whitespacesAndNewlines)
        let trimmedOpenAISelectedModel =
            openAISettings.selectedModel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        openAISettings.baseURL = trimmedOpenAIBaseURL.isEmpty ? nil : trimmedOpenAIBaseURL
        openAISettings.apiKey = trimmedOpenAIAPIKey?.isEmpty == true ? nil : trimmedOpenAIAPIKey
        openAISettings.selectedModel =
            trimmedOpenAISelectedModel.isEmpty ? nil : trimmedOpenAISelectedModel

        normalized.koboldCPPSettings = koboldSettings
        normalized.openRouterSettings = openRouterSettings
        normalized.openAISettings = openAISettings

        if normalized.userTemplates.isEmpty {
            normalized.userTemplates = ConnectionSettingsModel.defaultUserTemplates
        }

        return normalized
    }
}

extension ConnectionSettingsModel {
    fileprivate func criticalConnectionSettingsChanged(from oldSettings: ConnectionSettingsModel)
        -> Bool
    {
        if connectionType != oldSettings.connectionType {
            return true
        }

        switch connectionType {
        case .KoboldAPI:
            return activeHost != oldSettings.activeHost || activePort != oldSettings.activePort
        case .OpenRouter:
            return activeAPIKey != oldSettings.activeAPIKey
                || activeSelectedModel != oldSettings.activeSelectedModel
        case .OpenAI:
            return openAISettings?.baseURL != oldSettings.openAISettings?.baseURL
                || activeAPIKey != oldSettings.activeAPIKey
                || activeSelectedModel != oldSettings.activeSelectedModel
        }
    }
}
