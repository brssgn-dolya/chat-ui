//
//  MapSnapshotFileCache.swift
//  Chat
//
//  Created by Dolya on 04.02.2025.
//

import SwiftUI

actor MapSnapshotFileCache {
    static let shared = MapSnapshotFileCache()

    private init() { }

    /// Retrieves the file path in the cache directory
    private func fileURL(for key: String) throws -> URL {
        guard let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "FileCacheError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to retrieve cache directory path"])
        }
        return cachesDirectory.appendingPathComponent("\(key).dat")
    }

    /// Retrieves cached encrypted image data
    func encryptedImageData(forKey key: String) async throws -> Data? {
        let url = try fileURL(for: key)
        return try? Data(contentsOf: url)
    }

    /// Saves encrypted image data to the cache
    func setEncryptedImageData(_ data: Data, forKey key: String) async throws {
        let url = try fileURL(for: key)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw NSError(domain: "FileCacheError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Error writing data: \(error.localizedDescription)"])
        }
    }

    /// Removes cached encrypted image data
    func removeEncryptedImageData(forKey key: String) async throws {
        let url = try fileURL(for: key)
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            throw NSError(domain: "FileCacheError", code: -3, userInfo: [NSLocalizedDescriptionKey: "Error removing file: \(error.localizedDescription)"])
        }
    }

    /// Clears all cache files
    func clearCache() async throws {
        guard let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "FileCacheError", code: -4, userInfo: [NSLocalizedDescriptionKey: "Failed to retrieve cache directory path"])
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: cachesDirectory, includingPropertiesForKeys: nil, options: [])
            for file in files where file.pathExtension == "dat" {
                try FileManager.default.removeItem(at: file)
            }
        } catch {
            throw NSError(domain: "FileCacheError", code: -5, userInfo: [NSLocalizedDescriptionKey: "Error clearing cache: \(error.localizedDescription)"])
        }
    }

    /// Limits cache size by removing the oldest files if `maxSize` is exceeded
    func limitCacheSize(to maxSize: UInt64) async throws {
        guard let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "FileCacheError", code: -6, userInfo: [NSLocalizedDescriptionKey: "Failed to retrieve cache directory path"])
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(at: cachesDirectory, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey], options: [])
            var totalSize: UInt64 = 0
            var fileInfos: [(url: URL, size: UInt64, creationDate: Date)] = []

            for file in files where file.pathExtension == "dat" {
                let resourceValues = try file.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
                if let fileSize = resourceValues.fileSize, let creationDate = resourceValues.creationDate {
                    totalSize += UInt64(fileSize)
                    fileInfos.append((url: file, size: UInt64(fileSize), creationDate: creationDate))
                }
            }

            if totalSize > maxSize {
                let sortedFiles = fileInfos.sorted { $0.creationDate < $1.creationDate }
                for file in sortedFiles {
                    try FileManager.default.removeItem(at: file.url)
                    totalSize -= file.size
                    if totalSize <= maxSize {
                        break
                    }
                }
            }
        } catch {
            throw NSError(domain: "FileCacheError", code: -7, userInfo: [NSLocalizedDescriptionKey: "Error managing cache size: \(error.localizedDescription)"])
        }
    }
}
