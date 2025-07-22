//
//  AttachmentSaver.swift
//  Chat
//
//  Created by Sonata on 16.07.2025.
//

import UIKit
import AVFoundation

enum AttachmentSaver {

    static func saveToPhotoLibrary(attachment: Attachment, completion: @escaping (Bool) -> Void) {
        let mediaURL = attachment.key != nil
            ? AttachmentDecryptor.decryptAttachmentToTempURL(attachment)
            : attachment.full

        guard let mediaURL else {
            completion(false)
            return
        }

        switch attachment.type {
        case .video:
            saveVideo(mediaURL, completion: completion)

        case .image:
            saveImage(from: mediaURL, fallbackData: attachment.thumbnailData, completion: completion)

        default:
            cleanupTempFile(mediaURL)
            completion(false)
        }
    }

    private static func saveVideo(_ url: URL, completion: @escaping (Bool) -> Void) {
        let asset = AVAsset(url: url)
        guard asset.isPlayable, asset.tracks(withMediaType: .video).count > 0 else {
            cleanupTempFile(url)
            completion(false)
            return
        }

        let exportURL = tempFileURL(withExtension: "mp4")

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            cleanupTempFile(url)
            completion(false)
            return
        }

        exportSession.outputURL = exportURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true

        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                // Save exported file to photo library
                UISaveVideoAtPathToSavedPhotosAlbum(exportURL.path, nil, nil, nil)

                // Remove temporary files after short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    cleanupTempFile(exportURL)
                    cleanupTempFile(url)
                }

                completion(true)

            case .failed, .cancelled:
                cleanupTempFile(exportURL)
                cleanupTempFile(url)
                completion(false)

            default:
                break
            }
        }
    }

    private static func saveImage(from url: URL, fallbackData: Data?, completion: @escaping (Bool) -> Void) {
        if let data = fallbackData, let image = UIImage(data: data) {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            completion(true)
            return
        }

        if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)

            // Cleanup decrypted temp file after saving
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                cleanupTempFile(url)
            }

            completion(true)
            return
        }

        cleanupTempFile(url)
        completion(false)
    }

    private static func tempFileURL(withExtension ext: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
    }

    private static func cleanupTempFile(_ url: URL) {
        guard url.isFileURL else { return }
        let tmpPath = FileManager.default.temporaryDirectory.path
        guard url.path.hasPrefix(tmpPath) else { return }

        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            // Ignore cleanup failure
            print("Failed to delete temp file: \(url.lastPathComponent), error: \(error.localizedDescription)")
        }
    }
}
