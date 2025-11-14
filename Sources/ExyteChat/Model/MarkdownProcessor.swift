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
    public let shouldAddLinks: Bool
    
    public init(
        text: String,
        inbound: Bool = false,
        anyLinkColor: Color = .blue,
        darkLinkColor: Color = .gray,
        baseFont: UIFont = .systemFont(ofSize: 17),
        shouldAddLinks: Bool = true
    ) {
        self.text = text
        self.inbound = inbound
        self.anyLinkColor = anyLinkColor
        self.darkLinkColor = darkLinkColor
        self.baseFont = baseFont
        self.shouldAddLinks = shouldAddLinks
    }

    public func formattedAttributedString() -> AttributedString {
        let mutableAttributed = NSMutableAttributedString(
            string: text,
            attributes: [.font: baseFont]
        )

        processMarkdownStyle(for: .inlineCode, in: mutableAttributed)
        processMarkdownStyle(for: .strikethrough, in: mutableAttributed)
        processMarkdownStyle(for: .bold, in: mutableAttributed)
        processMarkdownStyle(for: .italic, in: mutableAttributed)
        processMentions(in: mutableAttributed)

        let urlProcessor = URLProcessor(
            text: text,
            inbound: inbound,
            anyLinkColor: anyLinkColor,
            darkLinkColor: darkLinkColor,
            shouldAddLinks: shouldAddLinks
        )
        urlProcessor.formatURLs(in: mutableAttributed)

        return AttributedString(mutableAttributed)
    }
    
    public func formattedNSAttributedString() -> NSAttributedString {
        let mutableAttributed = NSMutableAttributedString(
            string: text,
            attributes: [.font: baseFont]
        )

        processMarkdownStyle(for: .inlineCode, in: mutableAttributed)
        processMarkdownStyle(for: .strikethrough, in: mutableAttributed)
        processMarkdownStyle(for: .bold, in: mutableAttributed)
        processMarkdownStyle(for: .italic, in: mutableAttributed)
        processMentions(in: mutableAttributed)

        let urlProcessor = URLProcessor(
            text: text,
            inbound: inbound,
            anyLinkColor: anyLinkColor,
            darkLinkColor: darkLinkColor,
            shouldAddLinks: shouldAddLinks
        )
        urlProcessor.formatURLs(in: mutableAttributed)

        return mutableAttributed
    }

    private enum MarkdownStyle {
        case inlineCode, strikethrough, bold, italic
    }

    private func processMarkdownStyle(for style: MarkdownStyle, in attributed: NSMutableAttributedString) {
        let pattern: String
        let applyAttributes: (NSRange, String, NSMutableAttributedString) -> Void

        switch style {
        case .inlineCode:
            pattern = #"`([^\n`]+)`"#
            applyAttributes = { fullRange, inner, attr in
                attr.replaceCharacters(in: fullRange, with: inner)
                let innerLength = (inner as NSString).length
                attr.addAttribute(
                    .font,
                    value: UIFont.monospacedSystemFont(ofSize: baseFont.pointSize, weight: .regular),
                    range: NSRange(location: fullRange.location, length: innerLength)
                )
            }

        case .strikethrough:
            pattern = #"~([^\n~]+)~"#
            applyAttributes = { fullRange, inner, attr in
                attr.replaceCharacters(in: fullRange, with: inner)
                let innerLength = (inner as NSString).length
                attr.addAttribute(
                    .strikethroughStyle,
                    value: NSUnderlineStyle.single.rawValue,
                    range: NSRange(location: fullRange.location, length: innerLength)
                )
            }

        case .bold:
            pattern = #"(?<!\*)\*([^\n*]+?)\*(?!\*)"#
            applyAttributes = { fullRange, inner, attr in
                attr.replaceCharacters(in: fullRange, with: inner)
                let innerLength = (inner as NSString).length
                attr.addAttribute(
                    .font,
                    value: UIFont.boldSystemFont(ofSize: baseFont.pointSize),
                    range: NSRange(location: fullRange.location, length: innerLength)
                )
            }

        case .italic:
            pattern = #"(?<!\w)_(?!_)([^\n_]+?)_(?!\w)"#
            applyAttributes = { fullRange, inner, attr in
                attr.replaceCharacters(in: fullRange, with: inner)
                let innerLength = (inner as NSString).length
                attr.addAttribute(
                    .font,
                    value: UIFont.italicSystemFont(ofSize: baseFont.pointSize),
                    range: NSRange(location: fullRange.location, length: innerLength)
                )
            }
        }

        let regex = try! NSRegularExpression(pattern: pattern)
        let nsString = attributed.string as NSString
        let length = nsString.length
        let matches = regex.matches(
            in: nsString as String,
            range: NSRange(location: 0, length: length)
        )

        for match in matches.reversed() {
            guard match.numberOfRanges >= 2 else { continue }
            let innerRange = match.range(at: 1)
            let innerText = nsString.substring(with: innerRange)
            applyAttributes(match.range, innerText, attributed)
        }
    }

    private func processMentions(in attributed: NSMutableAttributedString) {
        let pattern = "<mention>@([^<]+?) \\(([^)]+)\\)</mention>"
        let regex = try! NSRegularExpression(pattern: pattern)
        let nsString = attributed.string as NSString
        let length = nsString.length
        let matches = regex.matches(
            in: nsString as String,
            range: NSRange(location: 0, length: length)
        )

        for match in matches.reversed() {
            guard match.numberOfRanges == 3 else { continue }

            let fullRange = match.range(at: 0)
            let name = nsString
                .substring(with: match.range(at: 1))
                .trimmingCharacters(in: .whitespaces)
            let id = nsString
                .substring(with: match.range(at: 2))
                .trimmingCharacters(in: .whitespaces)

            let display = "@\(name)"
            attributed.replaceCharacters(in: fullRange, with: display)

            let displayLength = (display as NSString).length
            let newRange = NSRange(location: fullRange.location, length: displayLength)

            attributed.addAttribute(
                .font,
                value: UIFont.boldSystemFont(ofSize: baseFont.pointSize),
                range: newRange
            )
            attributed.addAttribute(
                .foregroundColor,
                value: (inbound ? darkLinkColor : anyLinkColor).uiColor,
                range: newRange
            )
            attributed.addAttribute(
                .underlineStyle,
                value: NSUnderlineStyle.single.rawValue,
                range: newRange
            )

            if shouldAddLinks {
                let url = URL(string: "mention://\(id)")!
                attributed.addAttribute(.link, value: url, range: newRange)
            }
        }
    }
}
