//
//  MediaType.swift
//  Chat
//
//  Created by Bohdan Yankivskyi on 09.11.2025.
//

import UIKit
import AVFoundation

public enum MediaType { case image, video }

public protocol MediaModelProtocol: AnyObject {
    var mediaType: MediaType? { get }
    var duration: CGFloat? { get async }
    func getURL() async -> URL?
    func getThumbnailURL() async -> URL?
    func getData() async throws -> Data?
    func getThumbnailData() async -> Data?
}

public struct Media: Identifiable, Equatable, Sendable {
    public var id = UUID()
    internal let source: MediaModelProtocol
    public static func == (lhs: Media, rhs: Media) -> Bool { lhs.id == rhs.id }
}

public extension Media {
    var type: MediaType { source.mediaType ?? .image }
    var duration: CGFloat? { get async { await source.duration } }
    func getURL() async -> URL? { await source.getURL() }
    func getThumbnailURL() async -> URL? { await source.getThumbnailURL() }
    func getData() async -> Data? { try? await source.getData() }
    func getThumbnailData() async -> Data? { await source.getThumbnailData() }
}

public extension Media {
    static func from(image: UIImage) -> Media { Media(source: ImageMediaModel(image: image)) }
    static func from(videoURL: URL) -> Media { Media(source: VideoMediaModel(url: videoURL)) }
}

final class ImageMediaModel: MediaModelProtocol, @unchecked Sendable {
    private let image: UIImage
    init(image: UIImage) { self.image = image }
    var mediaType: MediaType? { .image }
    var duration: CGFloat? { get async { nil } }
    func getURL() async -> URL? { await Self.writeImageAsJPEGToTemp(image, quality: 0.9) }
    func getThumbnailURL() async -> URL? {
        let thumb = await Self.downscale(image, toMaxEdge: 512)
        return await Self.writeImageAsJPEGToTemp(thumb, quality: 0.8)
    }
    func getData() async throws -> Data? { image.jpegData(compressionQuality: 0.9) }
    func getThumbnailData() async -> Data? {
        let thumb = await Self.downscale(image, toMaxEdge: 512)
        return thumb.jpegData(compressionQuality: 0.8)
    }
    static func writeImageAsJPEGToTemp(_ image: UIImage, quality: CGFloat) async -> URL? {
        guard let data = image.jpegData(compressionQuality: quality) else { return nil }
        return TempWriter.write(data, ext: "jpg")
    }
    private static func downscale(_ image: UIImage, toMaxEdge maxEdge: CGFloat) async -> UIImage {
        let size = image.size
        let maxCurrent = max(size.width, size.height)
        guard maxCurrent > maxEdge, maxCurrent > 0 else { return image }
        let scaleRatio = maxEdge / maxCurrent
        let newSize = CGSize(width: size.width * scaleRatio, height: size.height * scaleRatio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}

final class VideoMediaModel: MediaModelProtocol, @unchecked Sendable {
    private let url: URL
    init(url: URL) { self.url = url }
    var mediaType: MediaType? { .video }
    var duration: CGFloat? { get async { CGFloat(CMTimeGetSeconds(AVAsset(url: url).duration)) } }
    func getURL() async -> URL? { url }
    func getThumbnailURL() async -> URL? {
        guard let frame = await Self.extractVideoFrame(url: url, at: 0.1, maxEdge: 512) else { return nil }
        return await ImageMediaModel.writeImageAsJPEGToTemp(frame, quality: 0.8)
    }
    func getData() async throws -> Data? { try? Data(contentsOf: url) }
    func getThumbnailData() async -> Data? {
        guard let frame = await Self.extractVideoFrame(url: url, at: 0.1, maxEdge: 512) else { return nil }
        return frame.jpegData(compressionQuality: 0.8)
    }
    private static func extractVideoFrame(url: URL, at seconds: Double, maxEdge: CGFloat) async -> UIImage? {
        let asset = AVAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: maxEdge, height: maxEdge)
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        do { return UIImage(cgImage: try gen.copyCGImage(at: time, actualTime: nil)) }
        catch { return nil }
    }
}

private enum TempWriter {
    static func tempURL(ext: String) -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
    }
    static func write(_ data: Data, ext: String = "jpg") -> URL? {
        let url = tempURL(ext: ext)
        do { try data.write(to: url, options: .atomic); return url }
        catch { return nil }
    }
}

public struct Album: Identifiable, Hashable { public let id = UUID(); public let title: String }

public enum MediaPickerMode: Equatable { case photos, albums, album(Album), camera, cameraSelection }

public struct SelectionParamsHolder {
    public enum MediaSelectionType { case any, images, videos }
    public enum MediaSelectionStyle { case multiple, single }
    public var mediaType: MediaSelectionType = .any
    public var selectionStyle: MediaSelectionStyle = .multiple
    public var selectionLimit: Int = 10
    public var showFullscreenPreview: Bool = true
    public init() {}
}
