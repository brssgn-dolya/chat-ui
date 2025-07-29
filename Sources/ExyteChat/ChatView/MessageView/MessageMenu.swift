//
//  MessageMenu.swift
//  
//
//  Created by Alisa Mylnikova on 20.03.2023.
//

import SwiftUI
import FloatingButton
import enum FloatingButton.Alignment

public protocol MessageMenuAction: Equatable, CaseIterable, Hashable {
    func title() -> String
    func icon() -> Image
    func type() -> MessageMenuActionType

    static func menuItems(for message: Message) -> [Self]
}

public extension MessageMenuAction {
    static func menuItems(for message:Message) -> [Self] {
        Self.allCases.map { $0 }
    }
}

public enum MessageMenuActionType: Equatable {
    case edit, delete, reply, copy, information, forward
}

public enum DefaultMessageMenuAction: MessageMenuAction {
    case reply
    case edit(saveClosure: (String) -> Void)
    
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
        switch (lhs, rhs) {
        case (.reply, .reply):
            return true
        case (.edit, .edit):
            return true
        default:
            return false
        }
    }
    
    public func hash(into hasher: inout Hasher) {
         switch self {
         case .reply:
             hasher.combine("reply")
         case .edit:
             hasher.combine("edit")
         }
     }

    public static var allCases: [DefaultMessageMenuAction] = [
        .reply,
        .edit(saveClosure: { _ in })
    ]
}

struct MessageMenu<MainButton: View, ActionEnum: MessageMenuAction>: View {

    @Environment(\.chatTheme) private var theme

    @Binding var isShowingMenu: Bool
    @Binding var menuButtonsSize: CGSize
    @Binding var menuButtonsCount: Int
    
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
            buttons: filteredMenuActions().map { action in
                menuButton(title: action.title(), icon: action.icon(), action: action,
                           isDestructive: action.type() == .delete ? true : false)
            },
            isOpen: $isShowingMenu
        )
        .straight()
        .initialOpacity(0)
        .direction(.bottom)
        .alignment(alignment)
        .spacing(2)
        .animation(.linear(duration: 0.2))
        .menuButtonsSize($menuButtonsSize)
        
        .onAppear {
            menuButtonsCount = filteredMenuActions().count
        }
    }
    
    private func menuButton(title: String,
                            icon: Image,
                            action: ActionEnum,
                            isDestructive: Bool) -> some View {
        HStack(spacing: 0) {
            if alignment == .left {
                Color.clear.viewSize(leadingPadding)
            }

            ZStack {
                if #available(iOS 17.0, *) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(uiColor: .label).opacity(0.2), lineWidth: 0.5)
                        .fill(Color(uiColor: .systemGray6))
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(uiColor: .systemGray6))
                }
                HStack {
                    Text(title)
                        .foregroundColor(isDestructive ? .red : .primary)
                        .font(.system(size: 17, weight: .regular))

                    Spacer()

                    icon
                        .foregroundColor(isDestructive ? .red : .primary)
                }
                .padding(.vertical, 11)
                .padding(.horizontal, 12)
            }
            .frame(width: 208)
            .fixedSize()
            .onTapGesture {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.prepare()
                generator.impactOccurred()
                onAction(action)
            }

            if alignment == .right {
                Color.clear.viewSize(trailingPadding)
            }
        }
    }
    
    private func filteredMenuActions() -> [ActionEnum] {
        let validActions = ActionEnum.allCases.filter { action in
            let type = action.type()
            switch type {
            case .edit:
                return message.type == .text && message.user.isCurrentUser
            case .delete:
                return message.user.isCurrentUser && message.isDeliverableStatus
            case .reply, .forward:
                return true
            case .copy:
                return message.type == .text || message.type == .url
            case .information:
                return message.user.isCurrentUser &&
                isGroup &&
                message.isDeliverableStatus
            @unknown default:
                return false
            }
        }
        
        // Separate actions into non-destructive and destructive (delete)
        let (destructive, nonDestructive) = validActions.partitioned { $0.type() == .delete }
        return nonDestructive + destructive
    }
}

extension Sequence {
    func partitioned(by predicate: (Element) -> Bool) -> (matching: [Element], nonMatching: [Element]) {
        var matching: [Element] = []
        var nonMatching: [Element] = []
        for element in self {
            if predicate(element) {
                matching.append(element)
            } else {
                nonMatching.append(element)
            }
        }
        return (matching, nonMatching)
    }
}
