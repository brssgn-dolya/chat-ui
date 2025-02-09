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
        if messageUseMarkdown {
            Text(formatAttributedString())
                .highPriorityGesture(TapGesture().onEnded {
                    handleTap(on: text)
                })
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
    
    private func handleTap(on text: String) {
        if let url = extractFirstURL(from: text) {
            UIApplication.shared.open(url)
        }
    }

    private func extractFirstURL(from text: String) -> URL? {
        let linkRegex = try! NSRegularExpression(pattern: #"(https?://[a-zA-Z0-9\.\-_/]+(?:\?[a-zA-Z0-9_\-=%&]+)?)"#, options: [])
        let matches = linkRegex.matches(in: text, range: NSRange(location: 0, length: text.utf16.count))

        for match in matches {
            if let range = Range(match.range, in: text) {
                return URL(string: String(text[range]))
            }
        }
        return nil
    }
}

//struct MessageTextView_Previews: PreviewProvider {
//    static var previews: some View {
//        MessageTextView(text: "Hello world!", messageUseMarkdown: false, inbound: true, anyLinkColor: .blue, darkLinkColor: .blue)
//    }
//}
