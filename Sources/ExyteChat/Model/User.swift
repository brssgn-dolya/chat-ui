//
//  Created by Alex.M on 17.06.2022.
//

import Foundation
import UIKit

public struct User: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let avatarURL: URL?
    public let avatarCachedImage: UIImage?
    public let isCurrentUser: Bool

    public init(id: String, name: String, avatarURL: URL?, avatarCachedImage: UIImage?, isCurrentUser: Bool) {
        self.id = id
        self.name = name
        self.avatarURL = avatarURL
        self.avatarCachedImage = avatarCachedImage
        self.isCurrentUser = isCurrentUser
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case avatarURL
        case avatarCachedImageData
        case isCurrentUser
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(avatarURL, forKey: .avatarURL)
        try container.encode(isCurrentUser, forKey: .isCurrentUser)
        let imageData = avatarCachedImage?.pngData()
        try container.encode(imageData, forKey: .avatarCachedImageData)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        avatarURL = try container.decode(URL?.self, forKey: .avatarURL)
        isCurrentUser = try container.decode(Bool.self, forKey: .isCurrentUser)
        if let imageData = try container.decodeIfPresent(Data.self, forKey: .avatarCachedImageData) {
            avatarCachedImage = UIImage(data: imageData)
        } else {
            avatarCachedImage = nil
        }
    }
}
