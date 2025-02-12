//
//  MarkdownProcessor.swift
//  Chat
//
//  Created by Dolya on 10.02.2025.
//

import SwiftUI

// MARK: - MarkdownProcessor (Handles Markdown Formatting)
public struct MarkdownProcessor {
    public let text: String
    public let inbound: Bool
    public let anyLinkColor: Color
    public let darkLinkColor: Color

    public init(
        text: String,
        inbound: Bool = false,
        anyLinkColor: Color = .blue,
        darkLinkColor: Color = .gray
    ) {
        self.text = text
        self.inbound = inbound
        self.anyLinkColor = anyLinkColor
        self.darkLinkColor = darkLinkColor
    }

    /// Returns an `AttributedString` with markdown formatting applied.
    public func formattedAttributedString() -> AttributedString {
        let mutableAttributed = NSMutableAttributedString(string: text)

        processMarkdownStyle(for: .inlineCode, in: mutableAttributed)
        processMarkdownStyle(for: .strikethrough, in: mutableAttributed)
        processMarkdownStyle(for: .bold, in: mutableAttributed)
        processMarkdownStyle(for: .italic, in: mutableAttributed)

        // Apply URL formatting
        let urlProcessor = URLProcessor(
            text: text,
            inbound: inbound,
            anyLinkColor: anyLinkColor,
            darkLinkColor: darkLinkColor
        )
        urlProcessor.formatURLs(in: mutableAttributed)
        
        return AttributedString(mutableAttributed)
    }

    // MARK: - Markdown Processing
    private enum MarkdownStyle {
        case inlineCode, strikethrough, bold, italic
    }

    /// Processes markdown formatting based on the given style.
    private func processMarkdownStyle(for style: MarkdownStyle, in attributed: NSMutableAttributedString) {
        let pattern: String
        let attributeClosure: (NSRange, String, NSMutableAttributedString) -> Void

        switch style {
        case .inlineCode:
            pattern = "`([^`]+)`"
            attributeClosure = { fullRange, innerText, attributed in
                attributed.replaceCharacters(in: fullRange, with: innerText)
                let newRange = NSRange(location: fullRange.location, length: (innerText as NSString).length)
                attributed.addAttribute(.font,
                                        value: UIFont.monospacedSystemFont(ofSize: UIFont.systemFontSize, weight: .regular),
                                        range: newRange)
            }
        case .strikethrough:
            pattern = "~([^~]+)~"
            attributeClosure = { fullRange, innerText, attributed in
                attributed.replaceCharacters(in: fullRange, with: innerText)
                let newRange = NSRange(location: fullRange.location, length: (innerText as NSString).length)
                attributed.addAttribute(.strikethroughStyle,
                                        value: NSUnderlineStyle.single.rawValue,
                                        range: newRange)
            }
        case .bold:
            pattern = "\\*([^*]+)\\*"
            attributeClosure = { fullRange, innerText, attributed in
                attributed.replaceCharacters(in: fullRange, with: innerText)
                let newRange = NSRange(location: fullRange.location, length: (innerText as NSString).length)
                attributed.addAttribute(.font,
                                        value: UIFont.boldSystemFont(ofSize: UIFont.systemFontSize),
                                        range: newRange)
            }
        case .italic:
            pattern = "_([^_]+)_"
            attributeClosure = { fullRange, innerText, attributed in
                attributed.replaceCharacters(in: fullRange, with: innerText)
                let newRange = NSRange(location: fullRange.location, length: (innerText as NSString).length)
                attributed.addAttribute(.font,
                                        value: UIFont.italicSystemFont(ofSize: UIFont.systemFontSize),
                                        range: newRange)
            }
        }

        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let nsString = attributed.string as NSString
        let matches = regex.matches(in: attributed.string, options: [], range: NSRange(location: 0, length: nsString.length))

        // Process matches in reverse order to maintain correct indexing.
        for match in matches.reversed() {
            let fullRange = match.range
            guard fullRange.length >= 2 else { continue }
            let innerRange = NSRange(location: fullRange.location + 1, length: fullRange.length - 2)
            let innerText = nsString.substring(with: innerRange)
            attributeClosure(fullRange, innerText, attributed)
        }
    }
}

