//
//  Created by Alex.M on 08.07.2022.
//

import Foundation

struct MessagesSection: Identifiable, Equatable, Sendable {
    let id: Int
    let date: Date
    var rows: [MessageRow]

    private static func makeDayKey(for date: Date, calendar: Calendar) -> (key: Int, startOfDay: Date) {
        let start = calendar.startOfDay(for: date)
        let y = calendar.component(.year,  from: start)
        let m = calendar.component(.month, from: start)
        let d = calendar.component(.day,   from: start)
        return (y * 10_000 + m * 100 + d, start)
    }

    init(date: Date, rows: [MessageRow], calendar: Calendar = .current) {
        let (key, start) = Self.makeDayKey(for: date, calendar: calendar)
        self.id = key
        self.date = start
        self.rows = rows
    }

    var formattedDate: String {
        DateFormatter.relativeDateFormatter.string(from: date)
    }

    static func == (lhs: MessagesSection, rhs: MessagesSection) -> Bool {
        lhs.id == rhs.id && lhs.rows == rhs.rows
    }
}
