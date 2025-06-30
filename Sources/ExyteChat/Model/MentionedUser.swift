//
//  MentionedUser.swift
//  Chat
//
//  Created by Bohdan Yankivskyi on 24.06.2025.
//

import Foundation

public struct MentionedUser: Codable, Identifiable, Hashable {
    public let id: String
    public let displayName: String

    public var snapshot: String {
        "@\(displayName)"
    }

    public init(id: String, displayName: String) {
        if let atIndex = id.firstIndex(of: "@") {
            self.id = String(id.prefix(upTo: atIndex))
        } else {
            self.id = id
        }
        self.displayName = displayName
    }

    public static func == (lhs: MentionedUser, rhs: MentionedUser) -> Bool {
        lhs.id == rhs.id && lhs.displayName == rhs.displayName
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(displayName)
    }
}
