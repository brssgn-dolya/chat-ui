//
//  Created by Alex.M on 07.07.2022.
//

import SwiftUI

public struct MessageStatusView: View {

    @Environment(\.chatTheme) private var theme

    let status: Message.Status
    let onRetry: () -> Void
    let colorSet: MessageStatusColorSet?
    var needsCapsule: Bool
    
    public init(
        status: Message.Status,
        needsCapsule: Bool,
        colorSet: MessageStatusColorSet? = nil,
        onRetry: @escaping () -> Void
    ) {
        self.status = status
        self.needsCapsule = needsCapsule
        self.onRetry = onRetry
        self.colorSet = colorSet
    }

    private var resolvedColor: Color {
        switch status {
        case .sending:
            return colorSet?.sending ?? statusColor
        case .sent:
            return colorSet?.sent ?? Color(red: 130/255, green: 170/255, blue: 255/255)
        case .received:
            return colorSet?.received ?? Color(red: 130/255, green: 170/255, blue: 255/255)
        case .read:
            return colorSet?.read ?? Color(red: 232/255, green: 240/255, blue: 255/255)
        case .error:
            return colorSet?.error ?? theme.colors.errorStatus
        }
    }
    
    private var statusColor: Color {
        needsCapsule ? .white.opacity(0.85) : theme.colors.myMessageTime
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
                        .foregroundColor(statusColor)
                        .font(.system(size: 13))
                        .fontWeight(.medium)
                }
            }
        } else {
            Group {
                switch status {
                case .sending:
                    if #available(iOS 18.0, *) {
                        Image(systemName: "clock")
                            .symbolRenderingMode(.hierarchical)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(resolvedColor)
                            .symbolEffect(.rotate,
                                          options: .repeat(.continuous).speed(0.9),
                                          isActive: true)
                    } else {
                        Image(systemName: "clock")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(resolvedColor)
                    }
                case .sent:
                    Image("icon.message.status.sent")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(resolvedColor)
                case .received:
                    Image("icon.message.status.delivered")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(resolvedColor)
                case .read:
                    Image("icon.message.status.read")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
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
