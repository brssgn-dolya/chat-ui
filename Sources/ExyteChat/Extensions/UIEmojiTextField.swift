//
//  EmojiTextField.swift
//  Chat
//
//  https://stackoverflow.com/questions/66397828/emoji-keyboard-swiftui
//

import SwiftUI

class UIEmojiTextField: UITextField {
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func setEmoji() {
        _ = self.textInputMode
    }
    
    override var textInputContextIdentifier: String? {
           return ""
    }
    
    override var textInputMode: UITextInputMode? {
        for mode in UITextInputMode.activeInputModes {
            if mode.primaryLanguage == "emoji" {
                self.keyboardType = .default // do not remove this
                return mode
            }
        }
        return nil
    }
}

/// A TextField that opens the keyboard (when focused) with the emoji selector active
struct EmojiTextField: UIViewRepresentable {
    /// A placeholder string to display when no emoji is selected
    var placeholder: String = ""
    /// A binding string that the selected emoji will be assigned to
    @Binding var text: String
    
    func makeUIView(context: Context) -> UIEmojiTextField {
        let emojiTextField = UIEmojiTextField()
        emojiTextField.placeholder = placeholder
        emojiTextField.text = text
        emojiTextField.delegate = context.coordinator
        return emojiTextField
    }
    
    func updateUIView(_ uiView: UIEmojiTextField, context: Context) {
        uiView.text = text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: EmojiTextField
        
        init(parent: EmojiTextField) {
            self.parent = parent
        }
        
        func textFieldDidChangeSelection(_ textField: UITextField) {
            DispatchQueue.main.async { [weak self] in
                self?.parent.text = textField.text ?? ""
            }
        }
    }
}
import SwiftUI

extension DynamicTypeSize {
    /// These values were extracted from a single emoji rendered at `Font.title3`
    /// We use these values to help with view layouts and frames
    func bubbleDiameter() -> CGFloat {
        switch self {
        case .xSmall:
            return 22
        case .small:
            return 23
        case .medium:
            return 24
        case .large:
            return 25
        case .xLarge:
            return 26
        case .xxLarge:
            return 27
        case .xxxLarge:
            return 30
        case .accessibility1:
            return 35
        case .accessibility2:
            return 42
        case .accessibility3:
            return 48
        case .accessibility4:
            return 53
        case .accessibility5:
            return 59
        @unknown default:
            return 25
        }
    }
}
