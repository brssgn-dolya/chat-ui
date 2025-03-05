//
//  ActivityIndicator.swift
//
//
//  Created by Alisa Mylnikova on 01.09.2023.
//

import SwiftUI
import ActivityIndicatorView

public struct ActivityIndicator: View {

    @Environment(\.chatTheme) public var theme
    public var size: CGFloat
    public var showBackground: Bool

    public init(size: CGFloat = 50, showBackground: Bool = true) {
        self.size = size
        self.showBackground = showBackground
    }

    public var body: some View {
        ZStack {
            if showBackground {
                Color.black.opacity(0.8)
                    .frame(width: 100, height: 100)
                    .cornerRadius(8)
            }

            ActivityIndicatorView(isVisible: .constant(true), type: .flickeringDots())
                .foregroundColor(theme.colors.sendButtonBackground)
                .frame(width: size, height: size)
        }
    }
}
