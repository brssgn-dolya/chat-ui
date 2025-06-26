//
//  SwiftUIView.swift
//  
//
//  Created by Alex.M on 07.07.2022.
//

import SwiftUI

struct MessageTextView: View {
    let text: String?
    let messageUseMarkdown: Bool
    let inbound: Bool
    let anyLinkColor: Color
    let darkLinkColor: Color
    let isDeleted: Bool
    let onMentionTap: ((String) -> Void)?

    @State private var showLinkOptions = false
    @State private var linkOptions: [LinkOption] = []
    @State private var attributedText: AttributedString = AttributedString("")

    private var baseUIFont: UIFont {
        let base = isDeleted
            ? UIFont.systemFont(ofSize: 15)
            : UIFont.systemFont(ofSize: 17)
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: base)
    }

    var body: some View {
        Group {
            if let text = text, !text.isEmpty {
                contentView(for: text)
                    .confirmationDialog(
                        dialogTitle(),
                        isPresented: $showLinkOptions,
                        titleVisibility: .visible
                    ) {
                        ForEach(linkOptions) { option in
                            Button(option.displayName) {
                                _ = handleLinkTap(option.url)
                            }
                        }
                        Button("Скасувати", role: .cancel) { }
                    }
                    .task {
                        if messageUseMarkdown {
                            attributedText = generateAttributedText(from: text)
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private func contentView(for text: String) -> some View {
        if messageUseMarkdown {
            if isDeleted {
                retractedMessage(attributedText: attributedText)
            } else {
                Text(attributedText)
                    .font(.system(size: baseUIFont.pointSize))
                    .highPriorityGesture(
                        TapGesture().onEnded {
                            handleTap(in: attributedText)
                        }
                    )
//                    .environment(\.openURL, OpenURLAction { url in
//                        handleLinkTap(url)
//                    })
            }
        } else {
            Text(text)
                .font(.system(size: baseUIFont.pointSize))
        }
    }

    private func generateAttributedText(from text: String) -> AttributedString {
        var _ = [LinkOption]()
        let processor = MarkdownProcessor(
            text: text,
            inbound: inbound,
            anyLinkColor: anyLinkColor,
            darkLinkColor: darkLinkColor,
            baseFont: baseUIFont
        )
        return processor.formattedAttributedString()
    }

    @discardableResult
    private func handleLinkTap(_ url: URL) -> OpenURLAction.Result {
        if url.scheme == "mention", let userID = url.host {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onMentionTap?(userID)
            }
            return .handled
        } else if let scheme = url.scheme, ["http", "https"].contains(scheme) {
            UIApplication.shared.open(url)
            return .handled
        } else {
            return .systemAction
        }
    }

    private func handleTap(in attributed: AttributedString) {
        let options: [LinkOption] = attributed.runs.compactMap { run in
            guard let url = run.link else { return nil }
            let display = String(attributed[run.range].characters)
            let type: LinkOption.LinkType = url.scheme == "mention"
                ? .mention(id: url.host ?? "")
                : .url
            return LinkOption(displayName: display, url: url, type: type)
        }

        if options.count == 1 {
            _ = handleLinkTap(options[0].url)
        } else if options.count > 1 {
            self.linkOptions = options
            self.showLinkOptions = true
        }
    }

    private func dialogTitle() -> String {
        if linkOptions.allSatisfy({ $0.type.isMention }) {
            return "Оберіть користувача:"
        } else {
            return "Оберіть посилання:"
        }
    }
}

// MARK: - LinkOption

struct LinkOption: Identifiable, Hashable, Equatable {
    enum LinkType: Hashable {
        case mention(id: String)
        case url

        var isMention: Bool {
            if case .mention = self { return true }
            return false
        }
    }

    let id = UUID()
    let displayName: String
    let url: URL
    let type: LinkType

    var userID: String? {
        if case .mention(let id) = type {
            return id
        }
        return nil
    }
}

extension MessageTextView {
    @ViewBuilder
    private func retractedMessage(attributedText: AttributedString) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "nosign")
                .foregroundColor(inbound ? .gray : Color.white.opacity(0.85))
                .font(.system(size: 14, weight: .semibold))
            
            Text(attributedText)
                .foregroundColor(inbound ? .gray : Color.white.opacity(0.85))
                .font(.system(size: 15, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .background(Color.clear)
    }
}

//struct MessageTextView_Previews: PreviewProvider {
//    static var previews: some View {
//        MessageTextView(text: "Hello world!", messageUseMarkdown: false, inbound: true, anyLinkColor: .blue, darkLinkColor: .blue)
//    }
//}
