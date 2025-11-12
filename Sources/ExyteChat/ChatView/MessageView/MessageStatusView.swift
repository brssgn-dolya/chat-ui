//
//  Created by Alex.M on 07.07.2022.
//

import SwiftUI

public struct MessageStatusView: View {

    @Environment(\.chatTheme) private var theme

    let status: Message.Status
    let onRetry: () -> Void
    let colorSet: MessageStatusColorSet?

    public init(
        status: Message.Status,
        colorSet: MessageStatusColorSet? = nil,
        onRetry: @escaping () -> Void
    ) {
        self.status = status
        self.onRetry = onRetry
        self.colorSet = colorSet
    }

    private var resolvedColor: Color {
        switch status {
        case .sending:
            return colorSet?.sending ?? theme.colors.grayStatus
        case .sent:
            return colorSet?.sent ?? theme.colors.grayStatus
        case .received:
            return colorSet?.received ?? theme.colors.grayStatus
        case .read:
            return colorSet?.read ?? .cyan//theme.colors.myMessage
        case .error:
            return colorSet?.error ?? theme.colors.errorStatus
        }
    }

    public var body: some View {
        if case let .error(_) = status {
            Button {
                onRetry()
            } label: {
                HStack(spacing: 4.0) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .resizable()
                        .foregroundColor(resolvedColor)
                        .viewSize(MessageView.statusViewSize)
                        
                    Text("Повторити")
                        .foregroundColor(.init(uiColor: .systemGray))
                        .font(.system(size: 13))
                        .fontWeight(.medium)
                }
                .padding(.leading, MessageView.horizontalStatusPadding)
            }
        } else {
            Group {
                switch status {
                case .sending:
                    theme.images.message.sending
                        .resizable()
                        .rotationEffect(.degrees(90))
                        .foregroundColor(resolvedColor)
                case .sent:
                    theme.images.message.checkmark
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(resolvedColor)
                case .received:
                    theme.images.message.checkmarks
                        .resizable()
                        .foregroundColor(resolvedColor)
                case .read:
                    theme.images.message.checkmarks
                        .resizable()
                        .foregroundColor(resolvedColor)
                case .error:
                    EmptyView()
                }
            }
            .viewSize(MessageView.statusViewSize)
            .padding(.trailing, MessageView.horizontalStatusPadding)
        }
    }
}

public struct MessageStatusColorSet {
    public var sending: Color?
    public var sent: Color?
    public var received: Color?
    public var read: Color?
    public var error: Color?

    public init(
        sending: Color? = nil,
        sent: Color? = nil,
        received: Color? = nil,
        read: Color? = nil,
        error: Color? = nil
    ) {
        self.sending = sending
        self.sent = sent
        self.received = received
        self.read = read
        self.error = error
    }
}
