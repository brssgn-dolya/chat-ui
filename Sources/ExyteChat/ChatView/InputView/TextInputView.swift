//
//  Created by Alex.M on 14.06.2022.
//

import SwiftUI
import UIKit

struct TextInputView: View {

    @Environment(\.chatTheme) private var theme

    @EnvironmentObject private var globalFocusState: GlobalFocusState

    @Binding var text: String
    var inputFieldId: UUID
    var style: InputViewStyle
    var availableInput: AvailableInputType

    var body: some View {
        TextField("", text: $text, axis: .vertical)
            .customFocus($globalFocusState.focus, equals: .uuid(inputFieldId))
            .placeholder(when: text.isEmpty) {
                Text(style.placeholder)
                    .foregroundColor(theme.colors.buttonBackground)
            }
            .foregroundColor(style == .message ? theme.colors.textLightContext : theme.colors.textDarkContext)
            .padding(.vertical, 10)
            .padding(.leading, !availableInput.isMediaAvailable ? 12 : 0)
            .onTapGesture {
                globalFocusState.focus = .uuid(inputFieldId)
            }
            .background { ReturnKeyConfigurator(text: text) }
    }
}

private struct ReturnKeyConfigurator: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> UIView { UIView(frame: .zero) }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            var view: UIView? = uiView
            while let current = view {
                if let tv = Self.findTextView(in: current, excluding: uiView) {
                    tv.enablesReturnKeyAutomatically = true
                    if text.isEmpty {
                        tv.reloadInputViews()
                    }
                    return
                }
                view = current.superview
            }
        }
    }

    private static func findTextView(in view: UIView, excluding: UIView) -> UITextView? {
        if view === excluding { return nil }
        if let tv = view as? UITextView { return tv }
        for sub in view.subviews {
            if let tv = findTextView(in: sub, excluding: excluding) { return tv }
        }
        return nil
    }
}
