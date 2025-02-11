//
//  encapsulates.swift
//  Chat
//
//  Created by Dolya on 10.02.2025.
//

import SwiftUI

struct MarkdownProcessor {
    let text: String
    let inbound: Bool
    let anyLinkColor: Color
    let darkLinkColor: Color
    
    /// Returns an AttributedString with markdown formatting applied.
    func formattedAttributedString() -> AttributedString {
        let mutableAttributed = NSMutableAttributedString(string: text)
        
        // Process markdown styles.
        processMarkdownStyle(for: .inlineCode, in: mutableAttributed)
        processMarkdownStyle(for: .strikethrough, in: mutableAttributed)
        processMarkdownStyle(for: .bold, in: mutableAttributed)
        processMarkdownStyle(for: .italic, in: mutableAttributed)
        
        // Process URLs separately (only attributes are applied, no markers removed).
        processURLs(in: mutableAttributed)
        
        return AttributedString(mutableAttributed)
    }
    
    /// Extracts all URLs found in the text.
    func extractURLs() -> [URL] {
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
    
    // MARK: - Markdown Processing Using Switch
    
    /// Supported markdown styles.
    private enum MarkdownStyle {
        case inlineCode, strikethrough, bold, italic
    }
    
    /// Processes markdown formatting based on the given style.
    /// It finds text enclosed by specific markers, removes the markers, and applies the corresponding attribute.
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
        
        // Process matches in reverse order to preserve correct indexing.
        for match in matches.reversed() {
            let fullRange = match.range
            guard fullRange.length >= 2 else { continue }
            let innerRange = NSRange(location: fullRange.location + 1, length: fullRange.length - 2)
            let innerText = nsString.substring(with: innerRange)
            attributeClosure(fullRange, innerText, attributed)
        }
    }
    
    /// Processes URLs by applying link attributes, color, and underline styling.
    private func processURLs(in attributed: NSMutableAttributedString) {
        let pattern = #"(https?://[a-zA-Z0-9\.\-_/]+(?:\?[a-zA-Z0-9_\-=%&]+)?)"#
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let nsString = attributed.string as NSString
        let matches = regex.matches(in: attributed.string, options: [], range: NSRange(location: 0, length: nsString.length))
        
        for match in matches.reversed() {
            let fullRange = match.range
            let urlString = nsString.substring(with: fullRange)
            if let url = URL(string: urlString) {
                attributed.addAttribute(.link, value: url, range: fullRange)
                let color = inbound ? darkLinkColor.uiColor : anyLinkColor.uiColor
                attributed.addAttribute(.foregroundColor, value: color, range: fullRange)
                attributed.addAttribute(.underlineStyle,
                                        value: NSUnderlineStyle.single.rawValue,
                                        range: fullRange)
            }
        }
    }
}

