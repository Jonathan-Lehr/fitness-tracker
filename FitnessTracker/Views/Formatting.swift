import Foundation

extension Double {
    var minutesText: String {
        let m = Int(self.rounded())
        return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
    }
    var milesText: String { String(format: "%.2f mi", self) }
    var milesString: String { String(format: "%.2f", self) }
}

extension Date {
    /// Compact date and time for tight spots like the inline navigation title, e.g. "Nov 11, 3:35 PM".
    /// The year is included only when the date falls in a different year than `now`.
    func shortTimestamp(relativeTo now: Date = .now, calendar: Calendar = .current) -> String {
        let isCurrentYear = calendar.isDate(self, equalTo: now, toGranularity: .year)
        var style = Date.FormatStyle(date: .omitted, time: .omitted, locale: calendar.locale ?? .current,
                                     calendar: calendar, timeZone: calendar.timeZone)
            .month(.abbreviated).day().hour().minute()
        if !isCurrentYear {
            style = style.year()
        }
        return formatted(style)
    }
}
