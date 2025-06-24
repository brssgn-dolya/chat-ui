//
//  MentionsSuggestionsView.swift
//  Chat
//
//  Created by Bohdan Yankivskyi on 24.06.2025.
//

import SwiftUI

struct MentionsSuggestionsView: View {
    let suggestions: [User]
    let onSelect: (User) -> Void
    
    @ObservedObject var mentionsViewModel: MentionsSuggestionsViewModel
    
    private let rowHeight: CGFloat = 48
    private let maxVisibleRows: Int = 4
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(suggestions.indices, id: \.self) { index in
                    mentionRow(suggestions[index])
                    if index < suggestions.count - 1 {
                        Divider().padding(.leading, 48)
                    }
                }
                
            }
        }
        .frame(height: CGFloat(min(suggestions.count, maxVisibleRows)) * rowHeight)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(radius: 4)
        .padding(.horizontal)
        .padding(.bottom, 4)
        .animation(.default, value: suggestions.map(\.id))
    }
    
    @ViewBuilder
    private func mentionRow(_ user: User) -> some View {
        Button(action: {
            onSelect(user)
        }) {
            HStack(spacing: 8) {
                AvatarView(
                    url: user.avatarURL,
                    cachedImage: user.avatarCachedImage,
                    avatarSize: 28
                )
                
                VStack(alignment: .leading, spacing: 2) {
                    highlightedText(fullText: user.name, highlight: mentionsViewModel.query)
                        .foregroundColor(.primary)
                    
                    if let role = user.role, !role.isEmpty {
                        Text(role.capitalized)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .frame(height: rowHeight)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func highlightedText(fullText: String, highlight: String) -> Text {
        guard !highlight.isEmpty else {
            return Text(fullText).foregroundColor(.primary)
        }
        
        let lowerFull = fullText.lowercased()
        let lowerHighlight = highlight.lowercased()
        var result = Text("")
        var currentIndex = fullText.startIndex
        
        while let range = lowerFull.range(of: lowerHighlight, range: currentIndex..<lowerFull.endIndex) {
            if range.lowerBound > currentIndex {
                let before = fullText[currentIndex..<range.lowerBound]
                result = result + Text(String(before)).foregroundColor(.primary)
            }
            
            let match = fullText[range]
            result = result + Text(String(match)).bold().foregroundColor(.primary)
            
            currentIndex = range.upperBound
        }
        
        if currentIndex < fullText.endIndex {
            let remaining = fullText[currentIndex..<fullText.endIndex]
            result = result + Text(String(remaining)).foregroundColor(.primary)
        }
        
        return result
    }
}
