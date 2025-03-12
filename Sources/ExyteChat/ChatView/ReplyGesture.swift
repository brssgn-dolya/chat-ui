//
//  ReplyGesture.swift
//  BRSSGNSDK
//
//  Created by Boris on 14.11.2024.
//

import SwiftUI

struct ReplyGesture: ViewModifier {
    enum SwipeDirection {
        case left
        case right
    }
    
    var swipeDirection: SwipeDirection
    var maxSwipeOffset: CGFloat = 48
    var replySymbolColor: Color = .init(uiColor: .label)
    var replyIcon: String = "arrowshape.turn.up.left.fill"
    var onReply: (() -> Void)?
    
    @State private var draggedOffset: CGFloat = 0
    @State private var shouldPlayHapticFeedback: Bool = true
    
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    private var progress: CGFloat {
        min(abs(draggedOffset) / maxSwipeOffset, 1.0)
    }
    
    private var replySymbolOpacity: CGFloat {
        progress
    }
    
    private var drag: some Gesture {
        DragGesture(minimumDistance: maxSwipeOffset / 3, coordinateSpace: .local)
            .onChanged { value in
                let horizontalMovement = abs(value.translation.width)
                let verticalMovement = abs(value.translation.height)

                guard horizontalMovement > verticalMovement else { return }

                let newOffset: CGFloat
                switch swipeDirection {
                case .left where value.translation.width < 0:
                    newOffset = max(value.translation.width, -maxSwipeOffset)
                case .right where value.translation.width > 0:
                    newOffset = min(value.translation.width, maxSwipeOffset)
                default:
                    return
                }

                if draggedOffset != newOffset {
                    draggedOffset = newOffset
                }

                if progress == 1.0, shouldPlayHapticFeedback {
                    hapticFeedback.impactOccurred()
                    shouldPlayHapticFeedback = false
                }
            }
            .onEnded { value in
                let shouldTriggerReply = progress == 1.0
                let targetOffset: CGFloat = shouldTriggerReply ? (swipeDirection == .left ? -maxSwipeOffset : maxSwipeOffset) : 0

                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    draggedOffset = targetOffset
                }

                if shouldTriggerReply {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onReply?()
                        withAnimation(.spring()) { draggedOffset = 0 }
                    }
                }
                shouldPlayHapticFeedback = true
            }
    }
    
    func body(content: Content) -> some View {
        ZStack(alignment: swipeDirection == .left ? .trailing : .leading) {
            content
                .offset(x: draggedOffset)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: draggedOffset)
                .simultaneousGesture(drag)
            ZStack {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(replySymbolColor, lineWidth: 2)
                    .rotationEffect(.degrees(-90))
                    .frame(width: 32, height: 32)
                Circle()
                    .fill(progress == 1.0
                          ? replySymbolColor.opacity(progress)
                          : replySymbolColor.opacity(progress * 0.7))
                    .frame(width: 32, height: 32)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0.2), value: progress)
                Image(systemName: replyIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(.white)
                    .opacity(progress)
                    .scaleEffect(progress)
                    .applySymbolEffect(shouldPlayHapticFeedback: shouldPlayHapticFeedback)
            }
            .scaleEffect(.init(width: replySymbolOpacity, height: replySymbolOpacity))
            .offset(x: swipeDirection == .left ? -16 : 16)
        }
    }
}

extension View {
    func onReplyGesture(swipeDirection: ReplyGesture.SwipeDirection = .left, replySymbolColor: Color, handler: (() -> Void)?) -> some View {
        modifier(ReplyGesture(swipeDirection: swipeDirection, replySymbolColor: replySymbolColor, onReply: handler))
    }
}

extension View {
    @ViewBuilder
    func applySymbolEffect(shouldPlayHapticFeedback: Bool) -> some View {
        if #available(iOS 17.0, *) {
            self.symbolEffect(.scale.up, isActive: shouldPlayHapticFeedback)
        } else {
            self
        }
    }
}
