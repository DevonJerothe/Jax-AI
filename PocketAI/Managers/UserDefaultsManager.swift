//
//  UserDefaultsManager.swift
//  PocketAI
//
//  Created by devon jerothe on 4/4/25.
//

import Foundation

public class UserDefaultsManager {
    
    public static let shared = UserDefaultsManager()
    private let userDefaults = UserDefaults.standard
    
    public enum SettingsKeys: String {
        case ConnectionSettings
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
}
