//
//  Created by Alex.M on 08.07.2022.
//

import SwiftUI

struct MessageTimeView: View {

    let text: String
    let isCurrentUser: Bool
    var chatTheme: ChatTheme

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(isCurrentUser ? chatTheme.colors.myMessageTime : chatTheme.colors.frientMessageTime)
    }
}

struct MessageTimeWithCapsuleView: View {

    let text: String
    let isCurrentUser: Bool
    var chatTheme: ChatTheme

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(chatTheme.colors.timeCapsuleForeground)
            .opacity(0.8)
            .padding(.top, 4)
            .padding(.bottom, 4)
            .padding(.horizontal, 8)
            .background {
                Capsule()
                    .fill(chatTheme.colors.timeCapsuleBackground)
            }
    }
}

struct MessageTimeText: View {
    let text: String
    let isCurrentUser: Bool
    var theme: ChatTheme
    var needsCapsule: Bool

    private var timeColor: Color {
        needsCapsule
        ? theme.colors.frientMessageTime
        : (isCurrentUser ? theme.colors.myMessageTime
                         : theme.colors.frientMessageTime)
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(timeColor)
            .fixedSize(horizontal: true, vertical: true)
    }
}

struct CapsuleTimeContainer<Content: View>: View {
    let isCurrentUser: Bool
    var theme: ChatTheme
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 6) { content }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                Capsule().fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule().strokeBorder(.separator, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
    }
}
