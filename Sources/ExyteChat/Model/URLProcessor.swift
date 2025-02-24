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

    public init(
        text: String,
        inbound: Bool = false,
        anyLinkColor: Color = .accentColor,
        darkLinkColor: Color = .gray
    ) {
        self.text = text
        self.inbound = inbound
        self.anyLinkColor = anyLinkColor
        self.darkLinkColor = darkLinkColor
    }

    /// Extracts all URLs found in the text.
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

    /// Applies URL styling, including color and underline formatting.
    public func formatURLs(in attributed: NSMutableAttributedString) {
        let pattern = #"(https?://[a-zA-Z0-9\.\-_/]+(?:\?[a-zA-Z0-9_\-=%&]+)?)"#
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let nsString = attributed.string as NSString
        let matches = regex.matches(in: attributed.string, options: [], range: NSRange(location: 0, length: nsString.length))

        for match in matches.reversed() {
            let fullRange = match.range
            let urlString = nsString.substring(with: fullRange)
            if let url = URL(string: urlString) {
                // Apply link attribute
                attributed.addAttribute(.link, value: url, range: fullRange)

                // Determine color based on inbound flag
                let color = inbound ? darkLinkColor.uiColor : anyLinkColor.uiColor
                attributed.addAttribute(.foregroundColor, value: color, range: fullRange)

                // Apply underline style
                attributed.addAttribute(.underlineStyle,
                                        value: NSUnderlineStyle.single.rawValue,
                                        range: fullRange)
            }
        }
    }
}
