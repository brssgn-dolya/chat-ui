//
//  Created by Alex.M on 16.06.2022.
//

import Foundation
import ExyteMediaPicker

public enum AttachmentType: String, Codable {
    case image
    case video

    public var title: String {
        switch self {
        case .image:
            return "Image"
        default:
            return "Video"
        }
    }

    public init(mediaType: MediaType) {
        switch mediaType {
        case .image:
            self = .image
        default:
            self = .video
        }
    }
}

public struct Attachment: Codable, Identifiable, Hashable {
    public let id: String
    public let thumbnail: URL
    public let full: URL
    public let type: AttachmentType
    public let aspectRatio: CGFloat?
    public let mimeType: String?

    public init(id: String, thumbnail: URL, full: URL, type: AttachmentType, aspectRatio: CGFloat? = nil, mimeType: String? = nil) {
        self.id = id
        self.thumbnail = thumbnail
        self.full = full
        self.type = type
        self.aspectRatio = aspectRatio
        self.mimeType = mimeType
    }

    public init(id: String, url: URL, type: AttachmentType) {
        self.init(id: id, thumbnail: url, full: url, type: type)
    }
}
