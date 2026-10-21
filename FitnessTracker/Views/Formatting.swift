import Foundation

extension Double {
    var minutesText: String {
        let m = Int(self.rounded())
        return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
    }
    var milesText: String { String(format: "%.2f mi", self) }
}
