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

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(isCurrentUser ? theme.colors.myMessageTime
                                           : theme.colors.frientMessageTime)
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
                Capsule()
                    .fill(theme.colors.timeCapsuleBackground)
            )
            .foregroundColor(theme.colors.timeCapsuleForeground.opacity(0.8))
    }
}
