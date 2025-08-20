//
//  ReactionOverview.swift
//  Chat
//
//  Created by Bohdan Yankivskyi on 05.08.2025.
//

import SwiftUI

private struct ContentWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

extension View {
    // Helper to conditionally apply a modifier
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}

struct ReactionOverview: View {
    
    @StateObject var viewModel: ChatViewModel
    
    let message: Message
    /// Available width from parent (e.g. screen width)
    let width: CGFloat
    let backgroundColor: Color
    let padding: CGFloat = 24
    let inScrollView: Bool

    @State private var contentWidth: CGFloat = 0

    struct SortedReaction: Identifiable {
        var id: String { reaction.toString }
        let reaction: ReactionType
        let users: [User]
    }

    var body: some View {
        // Max visible bubble width inside outer .padding(padding)
        let maxContainerWidth = max(0, width - padding * 2)

        // Intrinsic content width (measured below) + horizontal insets
        let intrinsicWithInsets = contentWidth + padding * 2

        // Visible bubble width: either as much as content needs, or max allowed
        let targetWidth = min(intrinsicWithInsets, maxContainerWidth)

        // If content does not fit — enable scrolling, otherwise center it
        let needsScroll = intrinsicWithInsets > maxContainerWidth

        ScrollView(.horizontal, showsIndicators: false) {
            // Natural content width without spacers
            let row = HStack(spacing: padding) {
                ForEach(sortReactions()) { reaction in
                    reactionUserView(reaction: reaction)
                        .padding(padding / 2)
                }
            }
            // Measure content width
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: ContentWidthKey.self, value: proxy.size.width)
                }
            )
            .padding(.horizontal, padding) // Same inner horizontal insets

            // If it fits — expand to targetWidth and center
            row
                .if(!needsScroll) { view in
                    view.frame(width: targetWidth, alignment: .center)
                }
        }
        // Set bubble width based on target calculation
        .frame(width: targetWidth)
        // Apply background color
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThickMaterial)
        )
        // Clip to rounded rectangle shape
        .clipShape(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        // Now allow it to be centered within the full width
        .frame(maxWidth: .infinity, alignment: .center)
        // Keep outer padding to preserve same height as first version
        .padding(padding)
        .offset(x: horizontalOffset)
        // Update measured content width
        .onPreferenceChange(ContentWidthKey.self) { contentWidth = $0 }
    }
    
    @ViewBuilder
    func reactionUserView(reaction: SortedReaction) -> some View {
        VStack {
            Text(reaction.reaction.toString)
                .font(.title3)
                .background(
                    emojiBackgroundView()
                        .opacity(0.1)
                        .padding(-10)
                )
                .padding(.top, 8)
                .padding(.bottom)
            
            HStack(spacing: -14) {
                ForEach(reaction.users) { user in
                    AvatarView(url: user.avatarURL, cachedImage: user.avatarCachedImage, avatarSize: 32)
                        .contentShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(style: .init(lineWidth: 1))
                                .foregroundStyle(backgroundColor)
                        )
                }
            }
        }
    }
    
    @ViewBuilder
    func emojiBackgroundView() -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .center) {
                Circle()
                    .fill(.primary)
                Circle()
                    .fill(.primary)
                    .frame(width: proxy.size.width / 4, height: proxy.size.width / 4)
                    .offset(y: proxy.size.height / 2)
            }
        }
        .compositingGroup()
    }
    
    private var horizontalOffset: CGFloat {
        guard inScrollView else { return 0 }
        if message.user.isCurrentUser {
            return UIApplication.safeArea.leading
        } else {
            return -UIApplication.safeArea.leading
        }
    }
    
    private func sortReactions() -> [SortedReaction] {
        let mostRecent = message.reactions.sorted { $0.createdAt < $1.createdAt }
        let orderedEmojis = mostRecent.map(\.emoji)
        return Set(message.reactions.compactMap(\.emoji)).sorted(by: {
            orderedEmojis.firstIndex(of: $0)! < orderedEmojis.firstIndex(of: $1)!
        }).map { emoji in
            let users = mostRecent.filter { $0.emoji == emoji }
            return SortedReaction(
                reaction: .emoji(emoji),
                users: users.map(\.user)
            )
        }
    }
}

#if swift(>=6.0)
#Preview {
    let john = User(id: "john", name: "John", avatarURL: nil, isCurrentUser: true)
    let stan = User(id: "stan", name: "Stan", avatarURL: nil, isCurrentUser: false)
    let sally = User(id: "sally", name: "Sally", avatarURL: nil, isCurrentUser: false)
    
    ReactionOverview(
        viewModel: ChatViewModel(),
        message: .init(
            id: UUID().uuidString,
            user: stan,
            status: .read,
            text: "An example message of great importance",
            reactions: [
                Reaction(user: john, createdAt: Date.now.addingTimeInterval(-80), type: .emoji("🔥")),
                Reaction(user: stan, createdAt: Date.now.addingTimeInterval(-70), type: .emoji("🥳")),
                Reaction(user: john, createdAt: Date.now.addingTimeInterval(-60), type: .emoji("🔌")),
                Reaction(user: john, createdAt: Date.now.addingTimeInterval(-50), type: .emoji("🧠")),
                Reaction(user: john, createdAt: Date.now.addingTimeInterval(-40), type: .emoji("🥳")),
                Reaction(user: stan, createdAt: Date.now.addingTimeInterval(-30), type: .emoji("🔌")),
                Reaction(user: stan, createdAt: Date.now.addingTimeInterval(-20), type: .emoji("🧠")),
                Reaction(user: sally, createdAt: Date.now.addingTimeInterval(-10), type: .emoji("🧠"))
            ]
        ),
        width: UIScreen.main.bounds.width,
        backgroundColor: Color(UIColor.secondarySystemBackground),
        inScrollView: false
    )
}
#endif
