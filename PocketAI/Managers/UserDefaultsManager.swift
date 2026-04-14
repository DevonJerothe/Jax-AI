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

// add codable conformance for OrderedDictionary
// private struct KeyValuePair<K: Codable, V: Codable>: Codable {
//     let key: K 
//     let value: V
// }

// extension OrderedDictionary: Codable where Key: Codable, Value: Codable {
//     public func encode(to encoder: Encoder) throws {
//         var container = encoder.unkeyedContainer()
//         for (k, v) in self {
//             try container.encode(KeyValuePair(key: k, value: v))
//         }
//     }

//     public init(from decoder: Decoder) throws {
//         var container = try decoder.unkeyedContainer()
//         self.init() 
//         while !container.isAtEnd {
//             let pair = try container.decode(KeyValuePair<Key, Value>.self)
//             self[pair.key] = pair.value
//         }
//     }
// }
