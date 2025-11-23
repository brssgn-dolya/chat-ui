//
//  Created by Alex.M on 08.07.2022.
//

import SwiftUI

struct MessageTimeText: View {
    let text: String
    let isCurrentUser: Bool
    var theme: ChatTheme
    var needsCapsule: Bool

    private var resolvedColor: Color {
        needsCapsule
        ? .white.opacity(0.85)
        : (isCurrentUser ? theme.colors.myMessageTime
                         : theme.colors.frientMessageTime)
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(resolvedColor)
            .fixedSize(horizontal: true, vertical: true)
    }
}

struct CapsuleTimeContainer<Content: View>: View {
    let isCurrentUser: Bool
    var theme: ChatTheme
    @ViewBuilder var content: Content
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 6) { content }
            .foregroundStyle(.white.opacity(0.9))
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                Capsule()
                    .fill(.thinMaterial)
                    .overlay(
                        Capsule().fill(
                            Color.black.opacity(scheme == .light ? 0.28 : 0.12)
                        )
                    )
            )
            .overlay(
                Capsule().strokeBorder(
                    scheme == .light
                    ? Color.black.opacity(0.22)
                    : Color.white.opacity(0.28),
                    lineWidth: 0.5
                )
            )
            .shadow(color: .black.opacity(scheme == .light ? 0.18 : 0.45), radius: 2, y: 1)
    }
}
