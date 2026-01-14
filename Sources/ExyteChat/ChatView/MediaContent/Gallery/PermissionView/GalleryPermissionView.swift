//
//  PermissionView.swift
//  Chat
//
//  Created by Bohdan Yankivskyi on 09.11.2025.
//

import SwiftUI

struct GalleryPermissionView: View {
    let title: String
    let subtitle: String

    let onOpenSettings: () -> Void
    let onNotNow: () -> Void
    let onClose: () -> Void

    private let baseSymbol = "photo.badge.shield.exclamationmark.fill"
    private let gearSymbol = "gearshape.fill"

    @State private var showGear = false
    private let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    private var symbolName: String { showGear ? gearSymbol : baseSymbol }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(.label))
                    .frame(width: 36, height: 36)
            }
            .padding(.top, 10)
            .padding(.leading, 12)

            PermissionCardView(
                title: title,
                subtitle: subtitle,
                symbolName: symbolName,
                onOpenSettings: onOpenSettings,
                onNotNow: onNotNow,
                onClose: onClose
            )
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.28)) {
                showGear.toggle()
            }
        }
    }
}
