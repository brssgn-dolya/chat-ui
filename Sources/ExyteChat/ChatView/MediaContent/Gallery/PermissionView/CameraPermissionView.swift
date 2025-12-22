//
//  CameraPermissionView.swift
//  Chat
//
//  Created by Bohdan Yankivskyi on 23.12.2025.
//

import SwiftUI

struct CameraPermissionView: View {
    let title: String
    let subtitle: String
    let onOpenSettings: () -> Void
    let onNotNow: () -> Void
    let onClose: () -> Void

    @State private var showGear = false
    private let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    private var symbolName: String { showGear ? "gearshape.fill" : "camera.fill" }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

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
