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
    
    @State private var showLinkOptions: Bool = false
    @State private var linkOptions: [URL] = []
    
    var body: some View {
        if let text = text, !text.isEmpty {
            textView(text)
                .confirmationDialog("Оберіть посилання", isPresented: $showLinkOptions, titleVisibility: .visible) {
                    ForEach(linkOptions, id: \.self) { url in
                        Button(url.absoluteString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    Button("Відміна", role: .cancel) { }
                }
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
        let baseText = text ?? ""
        var attributedString = AttributedString(baseText)
        
        let linkRegex = try! NSRegularExpression(
            pattern: #"(https?://[a-zA-Z0-9\.\-_/]+(?:\?[a-zA-Z0-9_\-=%&]+)?)"#,
            options: []
        )
        
        let nsRange = NSRange(baseText.startIndex..<baseText.endIndex, in: baseText)
        let matches = linkRegex.matches(in: baseText, options: [], range: nsRange)
        
        for match in matches {
            if let range = Range(match.range, in: baseText),
               let attrStart = AttributedString.Index(range.lowerBound, within: attributedString),
               let attrEnd = AttributedString.Index(range.upperBound, within: attributedString) {
                
                let attrRange = attrStart..<attrEnd
                let urlString = String(baseText[range])
                
                attributedString[attrRange].link = URL(string: urlString)
                attributedString[attrRange].foregroundColor = inbound ? darkLinkColor : anyLinkColor
                attributedString[attrRange].underlineStyle = .single
            }
        }
        
        return attributedString
    }
    
    private func handleTap(on text: String) {
        let urls = extractAllURLs(from: text)
        if urls.count == 1, let url = urls.first {
            UIApplication.shared.open(url)
        } else if urls.count > 1 {
            linkOptions = urls
            showLinkOptions = true
        }
    }
    
    private func extractAllURLs(from text: String) -> [URL] {
        var urls: [URL] = []
        let linkRegex = try! NSRegularExpression(
            pattern: #"(https?://[a-zA-Z0-9\.\-_/]+(?:\?[a-zA-Z0-9_\-=%&]+)?)"#,
            options: []
        )
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = linkRegex.matches(in: text, options: [], range: nsRange)
        
        for match in matches {
            if let range = Range(match.range, in: text),
               let url = URL(string: String(text[range])) {
                urls.append(url)
            }
        }
        return urls
    }
}

//struct MessageTextView_Previews: PreviewProvider {
//    static var previews: some View {
//        MessageTextView(text: "Hello world!", messageUseMarkdown: false, inbound: true, anyLinkColor: .blue, darkLinkColor: .blue)
//    }
//}
