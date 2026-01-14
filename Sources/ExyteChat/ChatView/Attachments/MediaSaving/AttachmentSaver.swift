////
////  AttachmentSaver.swift
////  Chat
////
////  Created by Sonata on 16.07.2025.
////
//

import UIKit
import Photos

enum AttachmentSaver {

    static func saveToPhotoLibrary(attachment: Attachment, completion: @escaping (Bool) -> Void) {
        Task {
            let ok = await saveToPhotoLibraryAsync(attachment: attachment)
            await MainActor.run { completion(ok) }
        }
    }

    static func saveToPhotoLibraryAsync(attachment: Attachment) async -> Bool {
        let rawURL: URL? = (attachment.key != nil)
            ? AttachmentDecryptor.decryptAttachmentToTempURL(attachment)
            : attachment.full

        guard let srcURL = rawURL else { return false }

        guard await ensureAddOnlyAuthorization() else {
            cleanupTempIfNeeded(srcURL)
            return false
        }

        switch attachment.type {
        case .video:
            return await saveVideoNormalized(srcURL)
        case .image:
            return await saveImageNormalized(srcURL, fallbackData: attachment.thumbnailData)
        default:
            cleanupTempIfNeeded(srcURL)
            return false
        }
    }

    private static func performChangesReturningID(
        _ changeBlock: @escaping (_ capturePlaceholder: @escaping (String?) -> Void) -> Void
    ) async -> (success: Bool, localId: String?) {
        await withCheckedContinuation { (cont: CheckedContinuation<(Bool, String?), Never>) in
            var capturedId: String?
            PHPhotoLibrary.shared().performChanges({
                changeBlock { id in capturedId = id }
            }, completionHandler: { success, _ in
                cont.resume(returning: (success, capturedId))
            })
        }
    }

    private static func saveVideoNormalized(_ srcURL: URL) async -> Bool {
        guard fileOK(srcURL) else { cleanupTempIfNeeded(srcURL); return false }

        let ext = srcURL.pathExtension.lowercased()
        let needsMP4 = ext.isEmpty || (ext != "mp4" && ext != "mov")
        let tmpURL = needsMP4
            ? copyToTmp(srcURL, preferredExt: "mp4", preferredName: "video-\(UUID().uuidString).mp4")
            : copyToTmp(srcURL, preferredExt: ext,  preferredName: "video-\(UUID().uuidString).\(ext)")

        do {
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.none], ofItemAtPath: tmpURL.path)
        } catch { }

        let opts = PHAssetResourceCreationOptions()
        opts.originalFilename = tmpURL.lastPathComponent
        opts.uniformTypeIdentifier = UTType.mpeg4Movie.identifier
        opts.shouldMoveFile = true

        let result = await performChangesReturningID { captureID in
            let req = PHAssetCreationRequest.forAsset()
            captureID(req.placeholderForCreatedAsset?.localIdentifier)
            req.addResource(with: .video, fileURL: tmpURL, options: opts)
        }

        cleanupTempIfNeeded(srcURL)
        if !result.success || result.localId == nil { return false }
        return true
    }

    private static func saveImageNormalized(_ srcURL: URL, fallbackData: Data?) async -> Bool {
        if let data = fallbackData, UIImage(data: data) != nil {
            let opts = PHAssetResourceCreationOptions()
            opts.originalFilename = "image-\(UUID().uuidString).jpg"
            opts.uniformTypeIdentifier = UTType.jpeg.identifier

            let ok = await performChanges { _ in
                let req = PHAssetCreationRequest.forAsset()
                req.addResource(with: .photo, data: data, options: opts)
            }
            cleanupTempIfNeeded(srcURL)
            return ok
        }

        guard fileOK(srcURL) else { cleanupTempIfNeeded(srcURL); return false }
        let data = try? Data(contentsOf: srcURL)
        guard let imgData = data, UIImage(data: imgData) != nil else {
            cleanupTempIfNeeded(srcURL)
            return false
        }

        let isPNG = imgData.starts(with: [0x89, 0x50, 0x4E, 0x47])
        let ext = isPNG ? "png" : "jpg"
        let uti = isPNG ? UTType.png.identifier : UTType.jpeg.identifier

        let extLower = srcURL.pathExtension.lowercased()
        let normalizedURL = (extLower == ext)
            ? srcURL
            : writeCopyToTmp(imgData, preferredExt: ext, preferredName: "image-\(UUID().uuidString).\(ext)")

        let opts = PHAssetResourceCreationOptions()
        opts.originalFilename = normalizedURL.lastPathComponent
        opts.uniformTypeIdentifier = uti

        let ok = await performChanges { _ in
            let req = PHAssetCreationRequest.forAsset()
            req.addResource(with: .photo, fileURL: normalizedURL, options: opts)
        }

        cleanupTempIfNeeded(normalizedURL)
        cleanupTempIfNeeded(srcURL)
        return ok
    }

    private static func performChanges(_ block: @escaping (_ errorOut: UnsafeMutablePointer<NSError?>?) -> Void) async -> Bool {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            PHPhotoLibrary.shared().performChanges({
                block(nil)
            }, completionHandler: { success, _ in
                cont.resume(returning: success)
            })
        }
    }

    private static func ensureAddOnlyAuthorization() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let new = await withCheckedContinuation { (c: CheckedContinuation<PHAuthorizationStatus, Never>) in
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { c.resume(returning: $0) }
            }
            return new == .authorized || new == .limited
        default:
            return false
        }
    }

    @discardableResult
    private static func fileOK(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attrs?[.size] as? NSNumber)?.int64Value ?? -1
        return exists && !isDir.boolValue && size > 0
    }

    private static func copyToTmp(_ src: URL, preferredExt: String, preferredName: String) -> URL {
        let dst = FileManager.default.temporaryDirectory.appendingPathComponent(preferredName)
        try? FileManager.default.removeItem(at: dst)
        do { try FileManager.default.copyItem(at: src, to: dst) } catch { }
        return dst
    }

    private static func writeCopyToTmp(_ data: Data, preferredExt: String, preferredName: String) -> URL {
        let dst = FileManager.default.temporaryDirectory.appendingPathComponent(preferredName)
        try? FileManager.default.removeItem(at: dst)
        do { try data.write(to: dst, options: [.atomic]) } catch { }
        return dst
    }

    private static func cleanupTempIfNeeded(_ url: URL) {
        guard url.isFileURL else { return }
        let tmp = FileManager.default.temporaryDirectory.path
        guard url.path.hasPrefix(tmp) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
