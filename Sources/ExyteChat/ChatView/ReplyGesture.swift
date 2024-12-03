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
    var onReply: (() -> Void)?
    
    @State private var draggedOffset: CGSize = .zero
    @State private var shouldPlayHappitFeedback: Bool = true
    
    private var replySymbolOpacity: CGFloat {
        let horizontalOffset = abs(draggedOffset.width)
        guard horizontalOffset > maxSwipeOffset / 3 else { return 0.0 }
        let opaciry = (horizontalOffset - maxSwipeOffset / 3) / (maxSwipeOffset - maxSwipeOffset / 3)
        return opaciry
    }
    
    private var drag: some Gesture {
        DragGesture(minimumDistance: maxSwipeOffset / 3)
            .onChanged { value in
                guard abs(value.translation.height) < 5 else { return }
                
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
                
                guard abs(value.translation.width) > maxSwipeOffset - 5 && shouldPlayHappitFeedback else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                shouldPlayHappitFeedback = false
            }
            .onEnded { value in
                draggedOffset = .zero
                shouldPlayHappitFeedback = true
                
                guard abs(value.translation.width) > maxSwipeOffset - 5 else { return }
                
                switch swipeDirection {
                case .left:
                    guard value.translation.width < 0 else { return }
                    onReply?()
                case .right:
                    guard value.translation.width > 0 else { return }
                    onReply?()
                }
            }
    }
    
    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            content
                .offset(draggedOffset)
                .animation(.easeInOut, value: draggedOffset)
                //.gesture(drag)
                .simultaneousGesture(drag)
            
            Image(systemName: "arrowshape.turn.up.backward.circle")
                .resizable()
                .scaledToFit()
                .frame(width: 24.0, height: 24.0)
                .foregroundStyle(replySymbolColor)
                .offset(x: -16)
                .opacity(replySymbolOpacity)
                .scaleEffect(.init(width: replySymbolOpacity, height: replySymbolOpacity))
                .animation(.easeInOut, value: draggedOffset)
        }
    }
}

extension View {
    func onReplyGesture(swipeDirection: ReplyGesture.SwipeDirection = .left, replySymbolColor: Color, handler: (() -> Void)?) -> some View {
        modifier(ReplyGesture(swipeDirection: swipeDirection, replySymbolColor: replySymbolColor, onReply: handler))
    }
}
