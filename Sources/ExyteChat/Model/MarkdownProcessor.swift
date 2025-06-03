//
//  MarkdownProcessor.swift
//  Chat
//
//  Created by Dolya on 10.02.2025.
//

import SwiftUI

public struct MarkdownProcessor {
    public let text: String
    public let inbound: Bool
    public let anyLinkColor: Color
    public let darkLinkColor: Color
    public let baseFont: UIFont

    public init(
        text: String,
        inbound: Bool = false,
        anyLinkColor: Color = .blue,
        darkLinkColor: Color = .gray,
        baseFont: UIFont = .systemFont(ofSize: 17)
    ) {
        self.text = text
        self.inbound = inbound
        self.anyLinkColor = anyLinkColor
        self.darkLinkColor = darkLinkColor
        self.baseFont = baseFont
    }

    public func formattedAttributedString() -> AttributedString {
        let mutableAttributed = NSMutableAttributedString(string: text, attributes: [
            .font: baseFont
        ])
        
        processMarkdownStyle(for: .inlineCode, in: mutableAttributed)
        processMarkdownStyle(for: .strikethrough, in: mutableAttributed)
        processMarkdownStyle(for: .bold, in: mutableAttributed)
        processMarkdownStyle(for: .italic, in: mutableAttributed)

        let urlProcessor = URLProcessor(
            text: text,
            inbound: inbound,
            anyLinkColor: anyLinkColor,
            darkLinkColor: darkLinkColor
        )
        urlProcessor.formatURLs(in: mutableAttributed)

        return AttributedString(mutableAttributed)
    }

    private enum MarkdownStyle {
        case inlineCode, strikethrough, bold, italic
    }

    private func processMarkdownStyle(for style: MarkdownStyle, in attributed: NSMutableAttributedString) {
        let pattern: String
        let attributeClosure: (NSRange, String, NSMutableAttributedString) -> Void

        switch style {
        case .inlineCode:
            pattern = "`([^`]+)`"
            attributeClosure = { fullRange, innerText, attributed in
                attributed.replaceCharacters(in: fullRange, with: innerText)
                let newRange = NSRange(location: fullRange.location, length: (innerText as NSString).length)
                attributed.addAttribute(
                    .font,
                    value: UIFont.monospacedSystemFont(ofSize: baseFont.pointSize, weight: .regular),
                    range: newRange
                )
            }

        case .strikethrough:
            pattern = "~([^~]+)~"
            attributeClosure = { fullRange, innerText, attributed in
                attributed.replaceCharacters(in: fullRange, with: innerText)
                let newRange = NSRange(location: fullRange.location, length: (innerText as NSString).length)
                attributed.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: newRange)
            }

        case .bold:
            pattern = "\\*([^*]+)\\*"
            attributeClosure = { fullRange, innerText, attributed in
                attributed.replaceCharacters(in: fullRange, with: innerText)
                let newRange = NSRange(location: fullRange.location, length: (innerText as NSString).length)
                attributed.addAttribute(
                    .font,
                    value: UIFont.systemFont(ofSize: baseFont.pointSize, weight: .bold),
                    range: newRange
                )
            }

        case .italic:
            pattern = "_([^_]+)_"
            attributeClosure = { fullRange, innerText, attributed in
                attributed.replaceCharacters(in: fullRange, with: innerText)
                let newRange = NSRange(location: fullRange.location, length: (innerText as NSString).length)
                attributed.addAttribute(
                    .font,
                    value: UIFont.italicSystemFont(ofSize: baseFont.pointSize),
                    range: newRange
                )
            }
        }

        let regex = try! NSRegularExpression(pattern: pattern)
        let nsString = attributed.string as NSString
        let matches = regex.matches(in: attributed.string, range: NSRange(location: 0, length: nsString.length))

        for match in matches.reversed() {
            guard match.range.length >= 2 else { continue }
            let innerRange = NSRange(location: match.range.location + 1, length: match.range.length - 2)
            let innerText = nsString.substring(with: innerRange)
            attributeClosure(match.range, innerText, attributed)
        }
    }
}
