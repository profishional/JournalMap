//
//  AppConfig.swift
//  JournalMap
//
//  Created by Daniel Farahani on 2/1/2026.
//

import Foundation
import Security

class AppConfig {
    static let shared = AppConfig()

    private let apiKeyKey = "openai_api_key"

    private init() {}

    var openAIApiKey: String? {
        get {
            return getKeychainValue(for: apiKeyKey)
        }
        set {
            if let value = newValue {
                setKeychainValue(value, for: apiKeyKey)
            } else {
                deleteKeychainValue(for: apiKeyKey)
            }
        }
    }

    private func getKeychainValue(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    private func setKeychainValue(_ value: String, for key: String) {
        let data = value.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        // Add new item
        SecItemAdd(query as CFDictionary, nil)
    }

    private func deleteKeychainValue(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
