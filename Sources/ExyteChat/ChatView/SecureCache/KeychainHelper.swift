//
//  KeychainHelper.swift
//  Chat
//
//  Created by Dolya on 04.02.2025.
//

import SwiftUI
import MapKit
import CryptoKit
import Security

actor KeychainHelper {
    static let shared = KeychainHelper()
    
    private init() { }
    
    /// Saves a symmetric key to the Keychain
    func saveSymmetricKey(_ key: SymmetricKey, for keyIdentifier: String) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyIdentifier,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        SecItemDelete(query as CFDictionary) // Remove the existing key if it exists
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw NSError(domain: "KeychainError", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to save the key."])
        }
    }
    
    /// Loads a symmetric key from the Keychain
    func loadSymmetricKey(for keyIdentifier: String) throws -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyIdentifier,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        } else if status != errSecSuccess {
            throw NSError(domain: "KeychainError", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to load the key."])
        }

        guard let data = item as? Data else {
            throw NSError(domain: "KeychainError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid data format."])
        }
        
        return SymmetricKey(data: data)
    }
    
    /// Retrieves an existing key or creates a new one
    func getOrCreateSymmetricKey(for keyIdentifier: String) async throws -> SymmetricKey {
        if let existingKey = try loadSymmetricKey(for: keyIdentifier) {
            return existingKey
        }
        
        let newKey = SymmetricKey(size: .bits256)
        try saveSymmetricKey(newKey, for: keyIdentifier)
        return newKey
    }
    
    /// Encrypts data using a symmetric key
    func encryptData(_ data: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw NSError(domain: "EncryptionError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Encryption failed."])
        }
        return combined
    }

    /// Decrypts data using a symmetric key
    func decryptData(_ encryptedData: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: key)
    }
}
