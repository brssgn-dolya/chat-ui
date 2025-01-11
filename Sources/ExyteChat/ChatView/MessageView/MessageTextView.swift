//
//  SwiftUIView.swift
//  
//
//  Created by Alex.M on 07.07.2022.
//

import SwiftUI

struct MessageTextView: View {

    let text: String?
    let messageUseMarkdown: Bool
    let inbound: Bool
    let anyLinkColor: Color
    let darkLinkColor: Color

    var body: some View {
        if let text = text, !text.isEmpty {
            textView(text)
        }
    }

    @ViewBuilder
    private func textView(_ text: String) -> some View {
        if messageUseMarkdown,
           let attributed = try? AttributedString(markdown: text, options: String.markdownOptions) {
            Text(formatAttributedString())
        } else {
            Text(text)
        }
    }
    
    private func formatAttributedString() -> AttributedString {
        var attributedString = AttributedString(text ?? "")
        
        // Regular expression to detect URLs
        let linkRegex = try! NSRegularExpression(pattern: #"(https?://[a-zA-Z0-9\.\-_/]+(?:\?[a-zA-Z0-9_\-=%&]+)?)"#, options: [])
        
        // Convert AttributedString to String to use NSRange
        let fullString = String(attributedString.characters)
        let matches = linkRegex.matches(in: fullString, options: [], range: NSRange(location: 0, length: fullString.utf16.count))
        
        for match in matches {
            if let range = Range(match.range, in: fullString) {
                let url = String(fullString[range])
                
                // Apply link attribute and change color
                if let attributedRange = attributedString.range(of: url) {
                    attributedString[attributedRange].link = URL(string: url)
                    attributedString[attributedRange].foregroundColor = inbound ? darkLinkColor : anyLinkColor // Link color
                    attributedString[attributedRange].underlineStyle = .single // Optional underline
                }
            }
        }
        
        return attributedString
    }
}

struct MessageTextView_Previews: PreviewProvider {
    static var previews: some View {
        MessageTextView(text: "Hello world!", messageUseMarkdown: false, inbound: true, anyLinkColor: .blue, darkLinkColor: .blue)
    }
}
