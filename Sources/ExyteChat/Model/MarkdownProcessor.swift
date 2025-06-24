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
        let mutableAttributed = NSMutableAttributedString(string: text, attributes: [.font: baseFont])
        
        processMarkdownStyle(for: .inlineCode, in: mutableAttributed)
        processMarkdownStyle(for: .strikethrough, in: mutableAttributed)
        processMarkdownStyle(for: .bold, in: mutableAttributed)
        processMarkdownStyle(for: .italic, in: mutableAttributed)
        processMentions(in: mutableAttributed)
        
        let urlProcessor = URLProcessor(
            text: text,
            inbound: inbound,
            anyLinkColor: anyLinkColor,
            darkLinkColor: darkLinkColor
        )
        urlProcessor.formatURLs(in: mutableAttributed)

        return AttributedString(mutableAttributed)
    }

    // MARK: - MARKDOWN STYLES

    private enum MarkdownStyle {
        case inlineCode, strikethrough, bold, italic
    }

    private func processMarkdownStyle(for style: MarkdownStyle, in attributed: NSMutableAttributedString) {
        let pattern: String
        let applyAttributes: (NSRange, String, NSMutableAttributedString) -> Void

        switch style {
        case .inlineCode:
            pattern = "`([^`]+)`"
            applyAttributes = { fullRange, inner, attr in
                attr.replaceCharacters(in: fullRange, with: inner)
                attr.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: baseFont.pointSize, weight: .regular), range: NSRange(location: fullRange.location, length: inner.count))
            }

        case .strikethrough:
            pattern = "~([^~]+)~"
            applyAttributes = { fullRange, inner, attr in
                attr.replaceCharacters(in: fullRange, with: inner)
                attr.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: fullRange.location, length: inner.count))
            }

        case .bold:
            pattern = "\\*([^*]+)\\*"
            applyAttributes = { fullRange, inner, attr in
                attr.replaceCharacters(in: fullRange, with: inner)
                attr.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: baseFont.pointSize), range: NSRange(location: fullRange.location, length: inner.count))
            }

        case .italic:
            pattern = "_([^_]+)_"
            applyAttributes = { fullRange, inner, attr in
                attr.replaceCharacters(in: fullRange, with: inner)
                attr.addAttribute(.font, value: UIFont.italicSystemFont(ofSize: baseFont.pointSize), range: NSRange(location: fullRange.location, length: inner.count))
            }
        }

        let regex = try! NSRegularExpression(pattern: pattern)
        let nsString = attributed.string as NSString
        let matches = regex.matches(in: attributed.string, range: NSRange(location: 0, length: nsString.length))

        for match in matches.reversed() {
            guard match.range.length >= 2 else { continue }
            let innerRange = NSRange(location: match.range.location + 1, length: match.range.length - 2)
            let innerText = nsString.substring(with: innerRange)
            applyAttributes(match.range, innerText, attributed)
        }
    }

    // MARK: - MENTIONS

    private func processMentions(in attributed: NSMutableAttributedString) {
        let pattern = "<mention>@([^<]+?) \\(([^)]+)\\)</mention>"
        let regex = try! NSRegularExpression(pattern: pattern)
        let nsString = attributed.string as NSString
        let matches = regex.matches(in: attributed.string, range: NSRange(location: 0, length: nsString.length))
        
        for match in matches.reversed() {
            guard match.numberOfRanges == 3 else { continue }
            
            let fullRange = match.range(at: 0)
            let name = nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
            let id = nsString.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespaces)
            
            let display = "@\(name)"
            let url = URL(string: "mention://\(id)")!
            
            attributed.replaceCharacters(in: fullRange, with: display)
            let newRange = NSRange(location: fullRange.location, length: display.count)
            
            attributed.addAttribute(.link, value: url, range: newRange)
            attributed.addAttribute(.foregroundColor, value: (inbound ? darkLinkColor : anyLinkColor).uiColor, range: newRange)
            attributed.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: baseFont.pointSize), range: newRange)
        }
    }

    // MARK: - NSAttributedString variant

    public func formattedNSAttributedString() -> NSAttributedString {
        let mutable = NSMutableAttributedString(string: text, attributes: [.font: baseFont])
        processMarkdownStyle(for: .inlineCode, in: mutable)
        processMarkdownStyle(for: .strikethrough, in: mutable)
        processMarkdownStyle(for: .bold, in: mutable)
        processMarkdownStyle(for: .italic, in: mutable)
        processMentions(in: mutable)

        let urlProcessor = URLProcessor(
            text: text,
            inbound: inbound,
            anyLinkColor: anyLinkColor,
            darkLinkColor: darkLinkColor
        )
        urlProcessor.formatURLs(in: mutable)

        return mutable
    }
}
