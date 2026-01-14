//
//  PermissionCardView.swift
//  Chat
//
//  Created by Bohdan Yankivskyi on 23.12.2025.
//

import SwiftUI

struct PermissionCardView: View {
    let title: String
    let subtitle: String
    let symbolName: String

    let onOpenSettings: () -> Void
    let onNotNow: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack {
            Spacer(minLength: 0)

            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(.tertiarySystemFill))
                        .frame(width: 96, height: 96)

                    Image(systemName: symbolName)
                        .symbolRenderingMode(.monochrome)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Color(.label))
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.scale, options: symbolName == "gearshape.fill" ? .repeating : .default)
                }
                .frame(maxWidth: .infinity)

                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(.label))
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(Color(.secondaryLabel))
                    .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    Button(action: onOpenSettings) {
                        Text("Відкрити Налаштування")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color("dolyaBlue", bundle: nil) ?? Color(.systemBlue))

                    Button(action: {
                        onNotNow()
                        onClose()
                    }) {
                        Text("Не зараз")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color(.systemBlue))
                }
                .padding(.top, 6)
            }
            .padding(.top, 24)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 10)
            )
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
    }
}
