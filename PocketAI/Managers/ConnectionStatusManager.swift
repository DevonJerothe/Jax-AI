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
        let savedSettings = UserDefaultsManager.shared.fetchConnectionSettiongs() ?? .defaults
        let normalizedSettings = ConnectionStatusManager.normalize(savedSettings)
        self.connectionSettings = normalizedSettings
        self.maxContextLength = normalizedSettings.maxContextLength ?? ConnectionSettingsModel.defaults.maxContextLength ?? 25600
    }

    func attachLanguageModelService(_ languageModelService: LanguageModelService) {
        self.languageModelService = languageModelService
        languageModelService.updateConnectionSettings(connectionSettings)
    }

    func updateSettings(_ newSettings: ConnectionSettingsModel) {
        let normalizedSettings = ConnectionStatusManager.normalize(newSettings)
        let shouldDisconnect = normalizedSettings.criticalConnectionSettingsChanged(from: connectionSettings)

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

    func saveConnectionSettings() {
        persistSettings(ConnectionStatusManager.normalize(connectionSettings))
    }

    func connect() async {
        guard let languageModelService else {
            return
        }

        let attemptID = UUID()
        connectionAttemptID = attemptID
        languageModelService.updateConnectionSettings(connectionSettings)

        connectionStatus = .connecting
        footerNote = "Connecting to service..."

        let success = await languageModelService.connect()
        guard connectionAttemptID == attemptID else {
            return
        }

        if success {
            connectionStatus = .connected
            footerNote = languageModelService.selectedModel ?? connectionSettings.selectedModel ?? "Connected"
            synchronizeRuntimeSettings(
                selectedModel: languageModelService.selectedModel,
                maxContextLength: connectionSettings.connectionType == .KoboldAPI ? languageModelService.maxContextLength : nil
            )
        } else {
            connectionStatus = .failed
            footerNote = "Failed to connect to service"
        }
    }

    func refreshAvailableModels() async {
        guard connectionSettings.connectionType == .OpenRouter else {
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
        maxContextLength = settings.maxContextLength ?? ConnectionSettingsModel.defaults.maxContextLength ?? 25600
        languageModelService?.updateConnectionSettings(settings)
    }

    private func synchronizeRuntimeSettings(
        selectedModel: String?,
        maxContextLength: Int?
    ) {
        var updatedSettings = connectionSettings

        if let selectedModel {
            updatedSettings.selectedModel = selectedModel
        }

        if let maxContextLength {
            updatedSettings.maxContextLength = maxContextLength
            updatedSettings.contextLength = min(
                updatedSettings.contextLength ?? maxContextLength,
                maxContextLength
            )
        }

        persistSettings(ConnectionStatusManager.normalize(updatedSettings))
    }

    private static func normalize(_ settings: ConnectionSettingsModel) -> ConnectionSettingsModel {
        var normalized = settings

        let defaultSettings = ConnectionSettingsModel.defaults
        let resolvedMaxContextLength = max(normalized.maxContextLength ?? defaultSettings.maxContextLength ?? 25600, 1024)
        let resolvedContextLength = min(max(normalized.contextLength ?? defaultSettings.contextLength ?? 6144, 1024), resolvedMaxContextLength)
        let resolvedResponseLength = min(max(normalized.responseLength ?? defaultSettings.responseLength ?? 300, 120), 3000)

        normalized.maxContextLength = resolvedMaxContextLength
        normalized.contextLength = resolvedContextLength
        normalized.responseLength = resolvedResponseLength

        if normalized.connectionType == .KoboldAPI {
            let trimmedHost = normalized.host?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            normalized.host = trimmedHost.isEmpty ? defaultSettings.host : trimmedHost
            normalized.port = max(normalized.port ?? defaultSettings.port ?? 5001, 1)
        }

        if normalized.connectionType == .OpenRouter {
            let trimmedAPIKey = normalized.apiKey?.trimmingCharacters(in: .whitespacesAndNewlines)
            normalized.apiKey = trimmedAPIKey?.isEmpty == true ? nil : trimmedAPIKey
        }

        normalized.temperature = normalized.temperature ?? defaultSettings.temperature
        normalized.topP = normalized.topP ?? defaultSettings.topP
        normalized.topK = normalized.topK ?? defaultSettings.topK
        normalized.typicalP = normalized.typicalP ?? defaultSettings.typicalP
        normalized.repetitionPenalty = normalized.repetitionPenalty ?? defaultSettings.repetitionPenalty
        normalized.repetitionRange = normalized.repetitionRange ?? defaultSettings.repetitionRange

        if normalized.userTemplates.isEmpty {
            normalized.userTemplates = ConnectionSettingsModel.defaultUserTemplates
        }

        return normalized
    }
}

private extension ConnectionSettingsModel {
    func criticalConnectionSettingsChanged(from oldSettings: ConnectionSettingsModel) -> Bool {
        host != oldSettings.host ||
        port != oldSettings.port ||
        apiKey != oldSettings.apiKey ||
        selectedModel != oldSettings.selectedModel ||
        connectionType != oldSettings.connectionType
    }
}
