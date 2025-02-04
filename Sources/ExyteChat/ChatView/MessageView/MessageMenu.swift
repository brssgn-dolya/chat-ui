//
//  MessageMenu.swift
//  
//
//  Created by Alisa Mylnikova on 20.03.2023.
//

import SwiftUI
import FloatingButton
import enum FloatingButton.Alignment

public protocol MessageMenuAction: Equatable, CaseIterable {
    func title() -> String
    func icon() -> Image
    func type() -> MessageMenuActionType
}

public enum MessageMenuActionType: Equatable {
    case edit
    case delete
    case reply
    case copy
    case readBy
}

public enum DefaultMessageMenuAction: MessageMenuAction {

    case reply
    case edit(saveClosure: (String)->Void)

    public func title() -> String {
        switch self {
        case .reply:
            "Reply"
        case .edit:
            "Edit"
        }
    }

    public func icon() -> Image {
        switch self {
        case .reply:
            Image(.reply)
        case .edit:
            Image(.edit)
        }
    }
    
    public func type() -> MessageMenuActionType {
        switch self {
        case .reply:
            return .reply
        case .edit:
            return .edit
        }
    }

    public static func == (lhs: DefaultMessageMenuAction, rhs: DefaultMessageMenuAction) -> Bool {
        if case .reply = lhs, case .reply = rhs {
            return true
        }
        if case .edit(_) = lhs, case .edit(_) = rhs {
            return true
        }
        return false
    }

    public static var allCases: [DefaultMessageMenuAction] = [
        .reply, .edit(saveClosure: {_ in})
    ]
}

struct MessageMenu<MainButton: View, ActionEnum: MessageMenuAction>: View {

    @Environment(\.chatTheme) private var theme

    @Binding var isShowingMenu: Bool
    @Binding var menuButtonsSize: CGSize
    var message: Message
    var isGroup: Bool
    var alignment: Alignment
    var direction: Direction
    var leadingPadding: CGFloat
    var trailingPadding: CGFloat
    var onAction: (ActionEnum) -> ()
    var mainButton: () -> MainButton

    var body: some View {
        FloatingButton(
            mainButtonView: mainButton().allowsHitTesting(false),
            buttons: ActionEnum.allCases
                .filter {
                    ($0.type() == .edit && message.type == .text && message.user.isCurrentUser) ||
                    ($0.type() == .delete && message.user.isCurrentUser) ||
                    ($0.type() == .reply) || 
                    ($0.type() == .copy && message.type == .text)
//                    ||
//                    ($0.type() == .readBy && message.user.isCurrentUser
//                     && isGroup && message.type == .text) //add more cases if needed
                }
                .map {
                    menuButton(title: $0.title(), icon: $0.icon(), action: $0)
                },
            isOpen: $isShowingMenu
        )
        .straight()
        //.mainZStackAlignment(.top)
        .initialOpacity(0)
        .direction(direction)
        .alignment(alignment)
        .spacing(2)
        .animation(.linear(duration: 0.2))
        .menuButtonsSize($menuButtonsSize)
    }

    func menuButton(title: String, icon: Image, action: ActionEnum) -> some View {
        HStack(spacing: 0) {
            if alignment == .left {
                Color.clear.viewSize(leadingPadding)
            }

            ZStack {
                theme.colors.friendMessage
                    .background(.ultraThinMaterial)
                    .environment(\.colorScheme, .light)
                    .opacity(0.5)
                    .cornerRadius(12)
                HStack {
                    Text(title)
                        .foregroundColor(theme.colors.textLightContext)
                    Spacer()
                    icon
                }
                .padding(.vertical, 11)
                .padding(.horizontal, 12)
            }
            .frame(width: 208)
            .fixedSize()
            .onTapGesture {
                onAction(action)
            }

            if alignment == .right {
                Color.clear.viewSize(trailingPadding)
            }
        }
    }
}
