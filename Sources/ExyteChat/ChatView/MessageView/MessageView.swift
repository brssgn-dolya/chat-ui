//
//  MessageView.swift
//  Chat
//
//  Created by Alex.M on 23.05.2022.
//

import SwiftUI
import MapKit

struct MessageView: View {

    @Environment(\.chatTheme) private var theme

    @ObservedObject var viewModel: ChatViewModel

    let message: Message
    let positionInUserGroup: PositionInUserGroup
    let chatType: ChatType
    let avatarSize: CGFloat
    let tapAvatarClosure: ChatView.TapAvatarClosure?
    let messageUseMarkdown: Bool
    let isDisplayingMessageMenu: Bool
    let showMessageTimeView: Bool
    let isGroup: Bool
    let tapDocumentClosure: ChatView.TapDocumentClosure?

    @State var avatarViewSize: CGSize = .zero
    @State var statusSize: CGSize = .zero
    @State var timeSize: CGSize = .zero

    static let widthWithMedia: CGFloat = 204
    static let horizontalNoAvatarPadding: CGFloat = 8
    static let horizontalAvatarPadding: CGFloat = 8
    static let horizontalTextPadding: CGFloat = 12
    static let horizontalAttachmentPadding: CGFloat = 1 // for multiple attachments
    static let statusViewSize: CGFloat = 14
    static let horizontalStatusPadding: CGFloat = 8
    static let horizontalBubblePadding: CGFloat = 70

    var font: UIFont

    enum DateArrangement {
        case hstack, vstack, overlay
    }

    var additionalMediaInset: CGFloat {
        message.attachments.count > 1 ? MessageView.horizontalAttachmentPadding * 2 : 0
    }

    var dateArrangement: DateArrangement {
        let timeWidth = timeSize.width + 10
        let textPaddings = MessageView.horizontalTextPadding * 2
        let widthWithoutMedia = UIScreen.main.bounds.width
        - (message.user.isCurrentUser ? MessageView.horizontalNoAvatarPadding : avatarViewSize.width)
        - statusSize.width
        - MessageView.horizontalBubblePadding
        - textPaddings

        let maxWidth = message.attachments.isEmpty ? widthWithoutMedia : MessageView.widthWithMedia - textPaddings
        let finalWidth = message.text.width(withConstrainedWidth: maxWidth, font: font, messageUseMarkdown: messageUseMarkdown)
        let lastLineWidth = message.text.lastLineWidth(labelWidth: maxWidth, font: font, messageUseMarkdown: messageUseMarkdown)
        let numberOfLines = message.text.numberOfLines(labelWidth: maxWidth, font: font, messageUseMarkdown: messageUseMarkdown)

        if numberOfLines == 1, finalWidth + CGFloat(timeWidth) < maxWidth {
            return .hstack
        }
        if lastLineWidth + CGFloat(timeWidth) < finalWidth {
            return .overlay
        }
        return .vstack
    }

    var showAvatar: Bool {
        positionInUserGroup == .single
        || (chatType == .conversation && positionInUserGroup == .last)
        || (chatType == .comments && positionInUserGroup == .first)
    }

    var topPadding: CGFloat {
        if chatType == .comments { return 0 }
        return positionInUserGroup == .single || positionInUserGroup == .first ? 8 : 4
    }

    var bottomPadding: CGFloat {
        if chatType == .conversation { return 0 }
        return positionInUserGroup == .single || positionInUserGroup == .first ? 8 : 4
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if !message.user.isCurrentUser {
                avatarView
            }

            VStack(alignment: message.user.isCurrentUser ? .trailing : .leading, spacing: 2) {
                if !isDisplayingMessageMenu, let reply = message.replyMessage?.toMessage() {
                    replyBubbleView(reply)
                        .opacity(0.5)
                        .padding(message.user.isCurrentUser ? .trailing : .leading, 10)
                        .overlay(alignment: message.user.isCurrentUser ? .trailing : .leading) {
                            Capsule()
                                .foregroundColor(theme.colors.buttonBackground)
                                .frame(width: 2)
                        }
                }
                
                if !message.user.isCurrentUser && (positionInUserGroup == .single || (chatType == .conversation && positionInUserGroup == .first)) && isGroup {
                    Text(message.user.name)
                        .font(.caption)
                        .foregroundStyle(Color(uiColor: .label.withAlphaComponent(0.7)))
                        .offset(x: 8.0)
                }
                
                bubbleView(message)
            }

            if message.user.isCurrentUser, let status = message.status {
                MessageStatusView(status: status) {
                    if case let .error(draft) = status {
                        viewModel.sendMessage(draft)
                    }
                }
                .sizeGetter($statusSize)
            }
            
            encryptionIndicatorView(isEncrypted: message.isEncrypted)
        }
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
        .padding(.trailing, message.user.isCurrentUser ? MessageView.horizontalNoAvatarPadding : 0)
        .padding(message.user.isCurrentUser ? .leading : .trailing, MessageView.horizontalBubblePadding)
        .frame(maxWidth: UIScreen.main.bounds.width, alignment: message.user.isCurrentUser ? .trailing : .leading)
    }

    @ViewBuilder
    func bubbleView(_ message: Message) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !message.attachments.isEmpty {
                attachmentsView(message)
            }
            
            if message.type == .geo {
                VStack(alignment: .trailing, spacing: 8) {
                    locationView(message)
                }
            }

            if !message.text.isEmpty && message.type != .document && message.type != .geo {
                textWithTimeView(message)
                    .font(Font(font))
            }

            if let recording = message.recording {
                VStack(alignment: .trailing, spacing: 8) {
                    recordingView(recording)
                    messageTimeView()
                        .padding(.bottom, 8)
                        .padding(.trailing, 12)
                }
            }
            
            if message.type == .document {
                VStack(alignment: .trailing, spacing: 8) {
                    documentView(message)
                        .highPriorityGesture(TapGesture().onEnded {
                            tapDocumentClosure?(message.user, message.id)
                        })
                    messageTimeView()
                        .padding(.bottom, 8)
                        .padding(.trailing, 12)
                }
            }
        }
        .bubbleBackground(message, theme: theme)
    }

    @ViewBuilder
    func replyBubbleView(_ message: Message) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(message.user.name)
                .fontWeight(.semibold)
                .padding(.horizontal, MessageView.horizontalTextPadding)

            if !message.attachments.isEmpty {
                attachmentsView(message)
                    .padding(.top, 4)
                    .padding(.bottom, message.text.isEmpty ? 0 : 4)
            }

            if !message.text.isEmpty {
                MessageTextView(
                    text: message.text,
                    messageUseMarkdown: messageUseMarkdown,
                    inbound: !message.user.isCurrentUser,
                    anyLinkColor: theme.colors.anyLink,
                    darkLinkColor: theme.colors.darkLink,
                    isDeleted: message.isDeleted
                )
                    .padding(.horizontal, MessageView.horizontalTextPadding)
            }

            if let recording = message.recording {
                recordingView(recording)
            }
        }
        .font(.caption2)
        .padding(.vertical, 8)
        .frame(width: message.attachments.isEmpty ? nil : MessageView.widthWithMedia + additionalMediaInset)
        .bubbleBackground(message, theme: theme, isReply: true)
    }

    @ViewBuilder
    var avatarView: some View {
        if isGroup {
            Group {
                if showAvatar {
                    AvatarView(url: message.user.avatarURL, cachedImage: message.user.avatarCachedImage, avatarSize: avatarSize)
                        .contentShape(Circle())
                        .highPriorityGesture(
                            TapGesture().onEnded {
                                tapAvatarClosure?(message.user, message.id)
                            }
                        )
                } else {
                    Color.clear.viewSize(avatarSize)
                }
            }
            .padding(.horizontal, MessageView.horizontalAvatarPadding)
            .sizeGetter($avatarViewSize)
        } else {
            Spacer()
                .frame(width: MessageView.horizontalTextPadding)
        }
    }

    @ViewBuilder
    func attachmentsView(_ message: Message) -> some View {
        AttachmentsGrid(attachments: message.attachments) {
            viewModel.presentAttachmentFullScreen($0)
        }
        .applyIf(message.attachments.count > 1) {
            $0
                .padding(.top, MessageView.horizontalAttachmentPadding)
                .padding(.horizontal, MessageView.horizontalAttachmentPadding)
        }
        .overlay(alignment: .bottomTrailing) {
            if message.text.isEmpty {
                messageTimeView(needsCapsule: true)
                    .padding(4)
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    func textWithTimeView(_ message: Message) -> some View {
        let isDeleted = message.isDeleted
        
        let messageView = MessageTextView(
            text: message.text,
            messageUseMarkdown: messageUseMarkdown,
            inbound: !message.user.isCurrentUser,
            anyLinkColor: theme.colors.anyLink,
            darkLinkColor: theme.colors.darkLink,
            isDeleted: isDeleted
        )
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, MessageView.horizontalTextPadding)
        
        let timeView = messageTimeView()
            .padding(.trailing, 12)
        
        if isDeleted {
            HStack(alignment: .center, spacing: 6) {
                messageView
                timeView
            }
            .padding(.vertical, 8)
        } else {
            Group {
                switch dateArrangement {
                case .hstack:
                    HStack(alignment: .lastTextBaseline, spacing: 12) {
                        messageView
                        if !message.attachments.isEmpty {
                            Spacer()
                        }
                        timeView
                    }
                    .padding(.vertical, 8)
                    
                case .vstack:
                    VStack(alignment: .leading, spacing: 4) {
                        messageView
                        HStack(spacing: 0) {
                            Spacer()
                            timeView
                        }
                    }
                    .padding(.vertical, 8)
                    
                case .overlay:
                    HStack(alignment: .bottom, spacing: 4) {
                        messageView
                            .padding(.vertical, 8)
                        
                        timeView
                            .padding(.bottom, 8)
                    }
                }
            }
        }
    }

    @ViewBuilder
    func recordingView(_ recording: Recording) -> some View {
        RecordWaveformWithButtons(
            recording: recording,
            colorButton: message.user.isCurrentUser ? theme.colors.myMessage : .white,
            colorButtonBg: message.user.isCurrentUser ? .white : theme.colors.myMessage,
            colorWaveform: message.user.isCurrentUser ? theme.colors.textDarkContext : theme.colors.textLightContext
        )
        .padding(.horizontal, MessageView.horizontalTextPadding)
        .padding(.top, 8)
    }

    func messageTimeView(needsCapsule: Bool = false) -> some View {
        Group {
            if showMessageTimeView {
                if needsCapsule {
                    MessageTimeWithCapsuleView(text: message.time, isCurrentUser: message.user.isCurrentUser, chatTheme: theme)
                } else {
                    MessageTimeView(text: message.time, isCurrentUser: message.user.isCurrentUser, chatTheme: theme)
                }
            }
        }
        .sizeGetter($timeSize)
    }
    
    @ViewBuilder
    func encryptionIndicatorView(isEncrypted: Bool) -> some View {
        Group {
            if !isEncrypted {
                Image(systemName: "lock.open.trianglebadge.exclamationmark.fill")
                    .foregroundStyle(Color(uiColor: .systemOrange))
                    .padding(.bottom, 4)
                    .padding(.horizontal, 4)
            } else {
                EmptyView()
            }
        }
    }
    
    @ViewBuilder
    func documentView(_ message: Message) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "doc")
                .resizable()
                .foregroundStyle(message.user.isCurrentUser ? .white : theme.colors.buttonBackground)
                .scaledToFit()
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(message.text.components(separatedBy: "-").first ?? "")
                    .font(.body)
                    .lineLimit(1)
                Text(message.text.components(separatedBy: "-").last ?? "")
                    .font(.footnote)
                
            }
        }
        .padding(.horizontal, MessageView.horizontalTextPadding)
        .padding(.top, 8)
    }
}

public extension View {

    @ViewBuilder
    func bubbleBackground(_ message: Message, theme: ChatTheme, isReply: Bool = false) -> some View {
        let radius: CGFloat = !message.attachments.isEmpty ? 12 : 20
        let additionalMediaInset: CGFloat = message.attachments.count > 1 ? 2 : 0
        self
            .frame(width: message.attachments.isEmpty ? nil : MessageView.widthWithMedia + additionalMediaInset)
            .foregroundColor(message.user.isCurrentUser ? (isReply ? theme.colors.textMyReply : theme.colors.textDarkContext) : theme.colors.textLightContext)
            .background {
                if isReply || !message.text.isEmpty || message.recording != nil {
                    RoundedRectangle(cornerRadius: radius)
                        .foregroundColor(message.user.isCurrentUser ? theme.colors.myMessage : theme.colors.friendMessage)
                        .opacity(isReply ? 0.5 : 1)
                }
            }
            .cornerRadius(radius)
    }
}

// MARK: - Location View

extension MessageView {
    
    @ViewBuilder
    func locationView(_ message: Message) -> some View {
        let coordinates = parseCoordinates(from: message.text)
        let size = CGSize(width: min(UIScreen.main.bounds.width * 0.6, 260), height: 128)
        
        if let lat = coordinates?.latitude, let lon = coordinates?.longitude {
            ZStack {
                MessageMapView(latitude: lat, longitude: lon, snapshotSize: size)
                    .frame(width: size.width, height: size.height)
                    .cornerRadius(20)
                    .overlay(alignment: .bottomTrailing) {
                        timeView(text: message.time)
                            .padding(4)
                    }
                    .highPriorityGesture(
                        TapGesture().onEnded {
                            openMaps(latitude: lat, longitude: lon)
                        }
                    )
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }
    
    @ViewBuilder
    func timeView(text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(Color.white.opacity(0.85))
            .padding(.top, 4)
            .padding(.bottom, 4)
            .padding(.horizontal, 8)
            .background {
                Capsule()
                    .fill(Color.black.opacity(0.3))
            }
    }

    func parseCoordinates(from text: String) -> (latitude: Double, longitude: Double)? {
        let cleanText = text.replacingOccurrences(of: "geo:", with: "")
        let components = cleanText.split(separator: ";").first?.split(separator: ",").compactMap { Double($0) }
        
        if let lat = components?.first, let lon = components?.last {
            return (latitude: lat, longitude: lon)
        }
        return nil
    }
    
    func openMaps(latitude: Double, longitude: Double) {
        let url = URL(string: "http://maps.apple.com/?q=\(latitude),\(longitude)")!
        UIApplication.shared.open(url)
    }
}

//#if DEBUG
//struct MessageView_Preview: PreviewProvider {
//    static let stan = User(id: "stan", name: "Stan", avatarURL: nil, avatarCachedImage: nil, isCurrentUser: false)
//    static let john = User(id: "john", name: "John", avatarURL: nil, avatarCachedImage: nil, isCurrentUser: true)
//
//    static private var shortMessage = "Hi, buddy!"
//    static private var longMessage = "Hello hello hello hello hello hello hello hello hello hello hello hello hello\n hello hello hello hello d d d d d d d d"
//
//    static private var replyedMessage = Message(
//        id: UUID().uuidString,
//        user: stan,
//        status: .read,
//        text: longMessage,
//        attachments: [
//            Attachment.randomImage(),
//            Attachment.randomImage(),
//            Attachment.randomImage(),
//            Attachment.randomImage(),
//            Attachment.randomImage(),
//        ]
//    )
//
//    static private var message = Message(
//        id: UUID().uuidString,
//        user: stan,
//        status: .read,
//        text: shortMessage,
//        replyMessage: replyedMessage.toReplyMessage()
//    )
//
//    static var previews: some View {
//        ZStack {
//            Color.yellow.ignoresSafeArea()
//
//            MessageView(
//                viewModel: ChatViewModel(),
//                message: replyedMessage,
//                positionInUserGroup: .single,
//                chatType: .conversation,
//                avatarSize: 32,
//                tapAvatarClosure: nil,
//                messageUseMarkdown: false,
//                isDisplayingMessageMenu: false,
//                showMessageTimeView: true,
//                isGroup: false,
//                tapDocumentClosure: nil,
//                font: UIFontMetrics.default.scaledFont(for: UIFont.systemFont(ofSize: 15))
//            )
//        }
//    }
//}
//#endif
