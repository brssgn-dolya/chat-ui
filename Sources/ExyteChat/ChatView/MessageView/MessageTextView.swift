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
    let isDeleted: Bool
    
    @State private var showLinkOptions: Bool = false
    @State private var linkOptions: [URL] = []
    
    var body: some View {
        if let text = text, !text.isEmpty {
            textView(text)
                .confirmationDialog("Оберіть посилання",
                                    isPresented: $showLinkOptions,
                                    titleVisibility: .visible) {
                    ForEach(linkOptions, id: \.self) { url in
                        Button(url.absoluteString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    Button("Скасувати", role: .cancel) { }
                }
        }
    }
    
    @ViewBuilder
    private func textView(_ text: String) -> some View {
        if messageUseMarkdown {
            let attributedText = MarkdownProcessor(text: text,
                                                   inbound: inbound,
                                                   anyLinkColor: anyLinkColor,
                                                   darkLinkColor: darkLinkColor)
                .formattedAttributedString()
            if isDeleted {
                retractedMessage(attributedText: attributedText)
            } else {
                Text(attributedText)
                    .highPriorityGesture(TapGesture().onEnded {
                        handleTap(on: text)
                    })
            }
        } else {
            Text(text)
        }
    }
    
    /// Handles tap gestures on the text.
    /// If one URL is found, it opens it directly; if multiple URLs are found, it presents a confirmation dialog.
    private func handleTap(on text: String) {
        let processor = URLProcessor(text: text,
                                          inbound: inbound,
                                          anyLinkColor: anyLinkColor,
                                          darkLinkColor: darkLinkColor)
        let urls = processor.extractURLs()
        if urls.count == 1, let url = urls.first {
            UIApplication.shared.open(url)
        } else if urls.count > 1 {
            linkOptions = urls
            showLinkOptions = true
        }
    }
}

extension MessageTextView {
    @ViewBuilder
    private func retractedMessage(attributedText: AttributedString) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "nosign")
                .foregroundColor(inbound ? .gray : Color.white.opacity(0.85))
                .font(.system(size: 12))
                .fontWeight(.bold)
            Text(attributedText)
                .foregroundColor(inbound ? .gray : Color.white.opacity(0.85))
                .lineLimit(2)
        }
    }
}

//struct MessageTextView_Previews: PreviewProvider {
//    static var previews: some View {
//        MessageTextView(text: "Hello world!", messageUseMarkdown: false, inbound: true, anyLinkColor: .blue, darkLinkColor: .blue)
//    }
//}
