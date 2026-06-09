//
//  UserDefaultsManager.swift
//  PocketAI
//
//  Created by devon jerothe on 4/4/25.
//

import Foundation
import Collections
public class UserDefaultsManager {
    
    public static let shared = UserDefaultsManager()
    private let userDefaults = UserDefaults.standard
    
    public enum SettingsKeys: String {
        case ConnectionSettings
        case BotBooruAuthSettings
        case ChubAISettings
    }
    
    /// Save `Codable` settings objects
    public func saveSettings<T: Codable>(_ settings: T, forKey key: SettingsKeys) {
        let encoder = PropertyListEncoder()
        do {
            let data = try encoder.encode(settings)
            userDefaults.set(data, forKey: key.rawValue)
        } catch {
            print("UserDefaults Error: Failed to encode and save \(T.self) for \(key)")
        }
    }
    
    public func fetchConnectionSettings() -> ConnectionSettingsModel? {
        fetchSettings(ConnectionSettingsModel.self, forKey: .ConnectionSettings)
    }

    public func fetchBotBooruAuthSettings() -> BotBooruAuthSettings? {
        fetchSettings(BotBooruAuthSettings.self, forKey: .BotBooruAuthSettings)
    }

    public func fetchChubAISettings() -> ChubAISettings? {
        fetchSettings(ChubAISettings.self, forKey: .ChubAISettings)
    }

    private func fetchSettings<T: Codable>(_ type: T.Type, forKey key: SettingsKeys) -> T? {
        guard let settingsData = userDefaults.data(forKey: key.rawValue) else {
            return nil
        }

        let decoder = PropertyListDecoder()
        do {
            return try decoder.decode(T.self, from: settingsData)
        } catch {
            print("UserDefaults Error: Failed to decode \(T.self)")
            return nil
        }
    }

    // User Lock Settings
    public func saveUserLock(pass: String) {
        userDefaults.set(pass, forKey: "UserLock")
    }

    public func fetchUserLock() -> String? {
        userDefaults.string(forKey: "UserLock") ?? userDefaults.string(forKey: "userLock")
    }
}
