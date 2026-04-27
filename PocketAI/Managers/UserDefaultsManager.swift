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
    
    public func fetchConnectionSettiongs() -> ConnectionSettingsModel? {
        guard let settingsData = userDefaults.data(forKey: SettingsKeys.ConnectionSettings.rawValue) else {
            return nil
        }
        
        let decoder = PropertyListDecoder()
        do {
            let settingsObject = try decoder.decode(ConnectionSettingsModel.self, from: settingsData)
            return settingsObject
        } catch {
            print("UserDefaults Error: Failed to decode ConnectionSettings")
            return nil
        }
    }

    public func fetchBotBooruAuthSettings() -> BotBooruAuthSettings? {
        guard let settingsData = userDefaults.data(forKey: SettingsKeys.BotBooruAuthSettings.rawValue) else {
            return nil
        }

        let decoder = PropertyListDecoder()
        do {
            let settingsObject = try decoder.decode(BotBooruAuthSettings.self, from: settingsData)
            return settingsObject
        } catch {
            print("UserDefaults Error: Failed to decode BotBooruAuthSettings")
            return nil
        }
    }

    public func fetchChubAISettings() -> ChubAISettings? {
        guard let settingsData = userDefaults.data(forKey: SettingsKeys.ChubAISettings.rawValue) else {
            return nil
        }

        let decoder = PropertyListDecoder()
        do {
            let settingsObject = try decoder.decode(ChubAISettings.self, from: settingsData)
            return settingsObject
        } catch {
            print("UserDefaults Error: Failed to decode ChubAISettings")
            return nil
        }
    }
}