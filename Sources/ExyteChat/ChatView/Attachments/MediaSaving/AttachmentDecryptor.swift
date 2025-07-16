//
//  AttachmentDecryptor.swift
//  Chat
//
//  Created by Sonata on 16.07.2025.
//

import Foundation
import CryptoKit

enum AttachmentDecryptor {

    /// Decrypts AES-GCM encrypted attachment and writes the result to a temporary file.
    static func decryptAttachmentToTempURL(_ attachment: Attachment) -> URL? {
        guard let keyData = attachment.key,
              let ivData = attachment.iv else {
            // Required encryption key or IV is missing
            return nil
        }

        do {
            let encryptedData = try Data(contentsOf: attachment.full)

            guard let decryptedData = decryptGCM(
                encryptedData: encryptedData,
                key: keyData,
                iv: ivData
            ) else {
                // Decryption failed
                return nil
            }

            let ext = fileExtension(from: attachment.mimeType) ?? "dat"
            let tempURL = tempFileURL(withExtension: ext)

            try decryptedData.write(to: tempURL)
            return tempURL

        } catch {
            // Decryption process failed due to file access or crypto error
            return nil
        }
    }

    /// Performs AES-GCM decryption using CryptoKit
    private static func decryptGCM(encryptedData: Data, key: Data, iv: Data) -> Data? {
        guard encryptedData.count > 16 else {
            // Not enough data to include ciphertext and tag
            return nil
        }

        let tagLength = 16
        let ciphertext = encryptedData.dropLast(tagLength)
        let tag = encryptedData.suffix(tagLength)

        do {
            let sealedBox = try AES.GCM.SealedBox(
                nonce: AES.GCM.Nonce(data: iv),
                ciphertext: ciphertext,
                tag: tag
            )
            let symmetricKey = SymmetricKey(data: key)
            return try AES.GCM.open(sealedBox, using: symmetricKey)
        } catch {
            // GCM decryption failed
            return nil
        }
    }

    /// Maps common MIME types to file extensions
    private static func fileExtension(from mimeType: String?) -> String? {
        guard let mimeType else { return nil }

        let map: [String: String] = [
            "mp4": "mp4", "mov": "mov",
            "jpeg": "jpg", "jpg": "jpg", "png": "png"
        ]
        return map.first(where: { mimeType.contains($0.key) })?.value
    }

    /// Generates a unique temporary file URL with a given extension
    private static func tempFileURL(withExtension ext: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
    }
}
