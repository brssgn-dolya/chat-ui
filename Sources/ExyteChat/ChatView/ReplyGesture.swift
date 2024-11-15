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
    var maxSwipeOffset: CGFloat = 30
    var replySymbolColor: Color = .init(uiColor: .label)
    var onReply: (() -> Void)?
    
    @State private var draggedOffset: CGSize = .zero
    
    private var replySymbolOpacity: CGFloat {
        let horizontalOffset = abs(draggedOffset.width)
        guard horizontalOffset > maxSwipeOffset / 2 else { return 0.0 }
        let opaciry = (horizontalOffset - maxSwipeOffset / 2) / (maxSwipeOffset / 2)
        return opaciry
    }
    
    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                switch swipeDirection {
                case .left:
                    guard value.translation.width < 0 else { return }
                    let horizontalOffset = value.translation.width < -maxSwipeOffset ? -maxSwipeOffset : value.translation.width
                    draggedOffset = .init(width: horizontalOffset, height: 0)
                case .right:
                    guard value.translation.width > 0 else { return }
                    let horizontalOffset = min(maxSwipeOffset, max(maxSwipeOffset, value.translation.width))
                    draggedOffset = .init(width: horizontalOffset, height: 0)
                    break
                }
            }
            .onEnded { value in
                draggedOffset = .zero
                
                guard abs(value.translation.width) > maxSwipeOffset - 3 else { return }
                
                switch swipeDirection {
                case .left:
                    guard value.translation.width < 0 else { return }
                    onReply?()
                case .right:
                    guard value.translation.width > 0 else { return }
                    onReply?()
                }
                
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
    }
    
    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            content
                .offset(draggedOffset)
                .animation(.easeInOut, value: draggedOffset)
                .gesture(drag)
            
            Image(systemName: "arrowshape.turn.up.backward.circle")
                .foregroundStyle(replySymbolColor)
                .opacity(replySymbolOpacity)
                .scaleEffect(.init(width: replySymbolOpacity, height: replySymbolOpacity))
                .animation(.easeInOut, value: draggedOffset)
        }
    }
}

extension View {
    func onReplyGesture(swipeDirection: ReplyGesture.SwipeDirection = .left, handler: (() -> Void)?) -> some View {
        modifier(ReplyGesture(swipeDirection: swipeDirection, onReply: handler))
    }
}
