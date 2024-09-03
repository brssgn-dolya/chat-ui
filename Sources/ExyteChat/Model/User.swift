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
}
