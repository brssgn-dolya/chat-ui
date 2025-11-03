//
//  URLProcessor.swift
//  Chat
//
//  Created by Dolya on 12.02.2025.
//

import SwiftUI

// MARK: - URLProcessor (Handles URL Detection and Styling)
public struct URLProcessor {
    public let text: String
    public let inbound: Bool
    public let anyLinkColor: Color
    public let darkLinkColor: Color
    public let shouldAddLinks: Bool

    public init(
        text: String,
        inbound: Bool = false,
        anyLinkColor: Color = .accentColor,
        darkLinkColor: Color = .gray,
        shouldAddLinks: Bool = true
    ) {
        self.text = text
        self.inbound = inbound
        self.anyLinkColor = anyLinkColor
        self.darkLinkColor = darkLinkColor
        self.shouldAddLinks = shouldAddLinks
    }

    /// Extracts all URLs using NSDataDetector
    public func extractURLs() -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector
            .matches(in: text, options: [], range: fullRange)
            .compactMap { $0.url }
    }

    /// Styles and (optionally) links all detected URLs in the attributed string.
    /// - Important: Uses detector-provided URL/range; does not re-encode or mutate the URL string.
    public func formatURLs(in attributed: NSMutableAttributedString) {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return
        }

        let nsString = attributed.string as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        let matches = detector.matches(in: attributed.string, options: [], range: fullRange)

        // Apply from the end to keep ranges stable (defensive; we don't replace text here).
        for match in matches.reversed() {
            guard let url = match.url else { continue }
            let range = match.range

            // Clickable link (only if enabled), otherwise ensure .link is removed.
            if shouldAddLinks {
                attributed.addAttribute(.link, value: url, range: range)
            } else {
                attributed.removeAttribute(.link, range: range)
            }

            // Visual styling for the entire detected URL range.
            let color = inbound ? darkLinkColor.uiColor : anyLinkColor.uiColor
            attributed.addAttribute(.foregroundColor, value: color, range: range)
            attributed.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
    }
}
