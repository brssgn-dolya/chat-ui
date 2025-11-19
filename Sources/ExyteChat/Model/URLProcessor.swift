//
//  URLProcessor.swift
//  Chat
//
//  Created by Dolya on 12.02.2025.
//

import SwiftUI

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

    public func formatURLs(in attributed: NSMutableAttributedString) {
        assert(Thread.isMainThread, "formatURLs must be called on main thread")

        let nsString = attributed.string as NSString
        let length = nsString.length
        guard length > 0 else { return }

        let pattern = #"(https?://[^\s<>"']+)"#

        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else {
            return
        }

        let fullRange = NSRange(location: 0, length: length)
        let matches = regex.matches(
            in: nsString as String,
            options: [],
            range: fullRange
        )

        for match in matches.reversed() {
            guard match.numberOfRanges >= 2 else { continue }

            var urlRange = match.range(at: 1)
            var urlString = nsString.substring(with: urlRange)

            let trailingPunctuation = CharacterSet(charactersIn: ".,?!):;")
            while let lastScalar = urlString.unicodeScalars.last,
                  trailingPunctuation.contains(lastScalar),
                  urlRange.length > 0 {
                urlString = String(urlString.unicodeScalars.dropLast())
                urlRange.length -= 1
            }

            guard !urlString.isEmpty,
                  let url = URL(string: urlString) else {
                continue
            }

            apply(link: url, to: attributed, in: urlRange)
        }
    }

    private func apply(
        link url: URL,
        to attributed: NSMutableAttributedString,
        in range: NSRange
    ) {
        if shouldAddLinks {
            attributed.addAttribute(.link, value: url, range: range)
        } else {
            attributed.removeAttribute(.link, range: range)
        }

        let color = inbound ? darkLinkColor.uiColor : anyLinkColor.uiColor
        attributed.addAttribute(.foregroundColor, value: color, range: range)
        attributed.addAttribute(
            .underlineStyle,
            value: NSUnderlineStyle.single.rawValue,
            range: range
        )
    }
}
