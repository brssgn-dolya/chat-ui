//
//  MessageView+Reaction.swift
//  Chat
//

import SwiftUI

extension MessageView {
    
    @ViewBuilder
    func reactionsView(_ message: Message, maxReactions: Int = 4) -> some View {
        // If text has a single character, cap at 3; otherwise keep provided max
        let adjustedMaxReactions = (message.text.count <= 2) ? 3 : maxReactions

        let prepared = prepareReactions(message: message, maxReactions: adjustedMaxReactions)
        // "+N" equals hidden count: total - visibleCount
        let visibleCount = prepared.reactions.count
        let hiddenCount = max(0, message.reactions.count - visibleCount)
        let overflowText = message.user.isCurrentUser ? " +\(hiddenCount)" : "+\(hiddenCount) "

        HStack(spacing: -bubbleSize.width / 4) {
            if !message.user.isCurrentUser {
                overflowBubbleView(
                    leadingSpacer: true,
                    needsOverflowBubble: prepared.needsOverflowBubble,
                    text: overflowText,
                    containsReactionFromCurrentUser: prepared.overflowContainsCurrentUser
                )
            }

            ForEach(Array(prepared.reactions.enumerated()), id: \.element) { index, reaction in
                ReactionBubble(reaction: reaction, font: Font(font))
                    .transition(.scaleAndFade)
                    .zIndex(message.user.isCurrentUser ? Double(prepared.reactions.count - index)
                                                      : Double(index + 1))
                    .sizeGetter($bubbleSize)
            }

            if message.user.isCurrentUser {
                overflowBubbleView(
                    leadingSpacer: false,
                    needsOverflowBubble: prepared.needsOverflowBubble,
                    text: overflowText,
                    containsReactionFromCurrentUser: prepared.overflowContainsCurrentUser
                )
            }
        }
        .offset(x: message.user.isCurrentUser ? -(bubbleSize.height / 2) : (bubbleSize.height / 2), y: 0)
    }
    
    @ViewBuilder
    func overflowBubbleView(leadingSpacer:Bool, needsOverflowBubble:Bool, text:String, containsReactionFromCurrentUser:Bool) -> some View {
        if needsOverflowBubble {
            ReactionBubble(
                reaction: .init(
                    user: .init(
                        id: "null",
                        name: "",
                        avatarURL: nil, avatarCachedImage: nil,
                        isCurrentUser: containsReactionFromCurrentUser
                    ),
                    type: .emoji(text),
                    status: .sent
                ),
                font: .footnote.weight(.light)
            )
            .padding(message.user.isCurrentUser ? .trailing : .leading, -3)
        }
    }
    
    struct PreparedReactions {
        /// Sorted Reactions by most recent -> oldest (trimmed to maxReactions)
        let reactions:[Reaction]
        /// Indicates whether we need to add an overflow bubble (due to the number of Reactions exceeding maxReactions)
        let needsOverflowBubble:Bool
        /// Indicates whether the clipped reactions (oldest reactions beyond maxReaction) contain a reaction from the current user
        /// - Note: This value is used to color the background of the overflow bubble
        let overflowContainsCurrentUser:Bool
    }
    
    // MARK: - prepareReactions: (my reaction always first)
    private func prepareReactions(message: Message, maxReactions: Int) -> PreparedReactions {
        guard maxReactions > 1, !message.reactions.isEmpty else {
            return .init(reactions: [], needsOverflowBubble: false, overflowContainsCurrentUser: false)
        }

        // 1) Split: mine vs others
        //    Then sort each bucket by createdAt desc and concatenate: mine first, then others.
        //    This guarantees: my reaction is always first if it exists.
        let mine   = message.reactions.filter { $0.user.isCurrentUser }
            .sorted(by: { $0.createdAt > $1.createdAt })
        let others = message.reactions.filter { !$0.user.isCurrentUser }
            .sorted(by: { $0.createdAt > $1.createdAt })

        var ordered = mine + others

        // 2) Overflow logic
        let needsOverflowBubble = ordered.count > maxReactions
        // Visible bubbles count (excluding the "+N" bubble) when overflow is present
        let visibleSlots = needsOverflowBubble ? (maxReactions - 1) : maxReactions

        // Hidden tail AFTER taking visible
        let hiddenTail = ordered.count > visibleSlots ? Array(ordered.dropFirst(visibleSlots)) : []
        let overflowContainsCurrentUser = hiddenTail.contains(where: { $0.user.isCurrentUser })

        // Trim to visible portion
        if ordered.count > visibleSlots {
            ordered = Array(ordered.prefix(visibleSlots))
        }

        // 3) Layout direction:
        //    keep your old reversal rule for opponent messages (z-index/overlap expectation)
        let layoutOrdered = message.user.isCurrentUser ? ordered : ordered.reversed()

        return .init(
            reactions: layoutOrdered,
            needsOverflowBubble: needsOverflowBubble,
            overflowContainsCurrentUser: overflowContainsCurrentUser
        )
    }
}

struct ReactionBubble: View {
    
    @Environment(\.chatTheme) var theme
    
    let reaction: Reaction
    let font: Font
    
    @State private var phase = 0.0
    private var isOverflowText: Bool {
           (reaction.emoji ?? "").hasPrefix("+")
       }

    private var fillColor: Color {
        // Special case for "+N" overflow bubble
        if isOverflowText {
            // If hidden set contains my reaction, use myMessage; otherwise friendMessage
            return theme.colors.friendMessage
        }

        // Regular bubbles
        switch reaction.status {
        case .error:
            return .red
        case .sending, .sent, .read:
            return reaction.user.isCurrentUser ? theme.colors.myMessage : theme.colors.friendMessage
        }
    }
    
    private var textColor: Color {
            // For overflow "+N" ensure contrast with background
//            if isOverflowText {
//                return .dolyaBlue
//            }
            // For normal emoji keep system coloring (don’t tint)
        return .dolyaBlue //.primary
        }
    
    var opacity: Double {
        switch reaction.status {
        case .sent, .read:
            return 1.0
        case .sending, .error:
            return 0.7
        }
    }
    
    var body: some View {
        Text(reaction.emoji ?? "?")
            .font(font)
            .opacity(opacity)
            .foregroundStyle(textColor)
            .padding(6)
            .background(
                ZStack {
                    Circle()
                        .fill(fillColor)
                    // If the reaction is in flight, animate the stroke
                    if reaction.status == .sending {
                        Circle()
                            .stroke(style: .init(lineWidth: 2, lineCap: .round, dash: [100, 50], dashPhase: phase))
                            .fill(theme.colors.friendMessage)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
                                    phase -= 150
                                }
                            }
                    // Otherwise just stroke the circle normally
                    } else {
                        Circle()
                            .stroke(style: .init(lineWidth: 2))
                            .fill(theme.colors.mainBackground)
                    }
                }
            )
    }
}
