//
//  Created by Alex.M on 08.07.2022.
//

import Foundation

extension DateFormatter {
    static let timeFormatter = {
        let formatter = DateFormatter()

        formatter.dateStyle = .none
        formatter.timeStyle = .short

        return formatter
    }()

    static let relativeDateFormatter = {
        let relativeDateFormatter = DateFormatter()
        relativeDateFormatter.timeStyle = .none
        relativeDateFormatter.dateStyle = .full
        relativeDateFormatter.locale = Locale(identifier: "en_US")
        relativeDateFormatter.doesRelativeDateFormatting = true

        return relativeDateFormatter
    }()

    static func timeString(_ seconds: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        
        return formatter.string(from: TimeInterval(seconds)) ?? "00:00"
    }
}
