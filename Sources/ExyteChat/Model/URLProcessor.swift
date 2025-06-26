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

    public func extractURLs() -> [URL] {
        var urls: [URL] = []
        let pattern = #"(https?://[a-zA-Z0-9\.\-_/]+(?:\?[a-zA-Z0-9_\-=%&]+)?)"#
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: nsRange)

        for match in matches {
            if let range = Range(match.range, in: text),
               let url = URL(string: String(text[range])) {
                urls.append(url)
            }
        }
        return urls
    }

    public func formatURLs(in attributed: NSMutableAttributedString) {
        let pattern = #"(https?://[a-zA-Z0-9\.\-_/]+(?:\?[a-zA-Z0-9_\-=%&]+)?)"#
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let nsString = attributed.string as NSString
        let matches = regex.matches(in: attributed.string, options: [], range: NSRange(location: 0, length: nsString.length))

        for match in matches.reversed() {
            let fullRange = match.range
            let urlString = nsString.substring(with: fullRange)

            if let url = URL(string: urlString) {
                let color = inbound ? darkLinkColor.uiColor : anyLinkColor.uiColor

                if shouldAddLinks {
                    attributed.addAttribute(.link, value: url, range: fullRange)
                }

                attributed.addAttribute(.foregroundColor, value: color, range: fullRange)
                attributed.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: fullRange)
            }
        }
    }
}
