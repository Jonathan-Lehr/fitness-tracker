import Foundation
import CoreGraphics

/// One piece of recognized text. `box` is normalized (0...1) with a TOP-LEFT origin.
struct RecognizedText: Equatable {
    var text: String
    var box: CGRect
}

/// Values parsed from an iFit post-workout ("Nice job!") summary screen.
struct IFitSummary: Equatable {
    enum Field: String, CaseIterable {
        case title, date, duration, distance, calories, elevation, rpm, watts
        case inclineAvg, inclineMax, resistanceAvg, resistanceMax
    }

    var title: String?
    var date: Date?
    var durationMinutes: Double?
    var distanceMiles: Double?
    var calories: Int?
    var elevationFeet: Int?
    var avgRPM: Int?
    var avgWatts: Int?
    var inclineAvg: Double?
    var inclineMax: Double?
    var resistanceAvg: Int?
    var resistanceMax: Int?

    var missingFields: Set<Field> {
        var m = Set<Field>()
        if title == nil { m.insert(.title) }
        if date == nil { m.insert(.date) }
        if durationMinutes == nil { m.insert(.duration) }
        if distanceMiles == nil { m.insert(.distance) }
        if calories == nil { m.insert(.calories) }
        if elevationFeet == nil { m.insert(.elevation) }
        if avgRPM == nil { m.insert(.rpm) }
        if avgWatts == nil { m.insert(.watts) }
        if inclineAvg == nil { m.insert(.inclineAvg) }
        if inclineMax == nil { m.insert(.inclineMax) }
        if resistanceAvg == nil { m.insert(.resistanceAvg) }
        if resistanceMax == nil { m.insert(.resistanceMax) }
        return m
    }
}

/// Pure parser for OCR text of the iFit summary screen. No Vision/UIKit dependencies.
enum IFitSummaryParser {
    static let buttonPhrases = ["repeat workout", "extend your workout"]

    // MARK: Entry points

    /// Parse from recognized observations (uses geometry to find the title).
    static func parse(items: [RecognizedText], calendar: Calendar = .current) -> IFitSummary {
        let lines = groupIntoLines(items)
        var summary = parse(lines: lines, calendar: calendar)
        if let t = titleByProximity(items) { summary.title = t }
        return summary
    }

    /// Parse from OCR lines ordered top to bottom.
    static func parse(lines rawLines: [String], calendar: Calendar = .current) -> IFitSummary {
        let lines = rawLines.map(normalize).filter { !$0.isEmpty }
        let text = lines.joined(separator: " ")
        var s = IFitSummary()

        s.title = titleFromLines(lines)
        s.date = parseDate(text, calendar: calendar)

        // Duration: "1 hr 5 min", "1hr", "42 min"
        if let m = firstMatch(#"(\d{1,2})\s*hrs?\b(?:\s*(\d{1,2})\s*min)?"#, in: text) {
            s.durationMinutes = Double((Int(m[1]) ?? 0) * 60 + (Int(m[2]) ?? 0))
        } else if let m = firstMatch(#"(\d{1,3})\s*min\b"#, in: text) {
            s.durationMinutes = Double(m[1])
        }
        if let m = firstMatch(#"(\d{1,3}[.,]\d{1,2})\s*mi\b"#, in: text) ?? firstMatch(#"(\d{1,3})\s*mi\b"#, in: text) {
            s.distanceMiles = number(m[1])
        }
        if let m = firstMatch(#"(\d{2,4})\s*ca[l1I]s?\b"#, in: text) { s.calories = Int(m[1]) }
        if let m = firstMatch(#"(\d{1,5})\s*ft\b"#, in: text) { s.elevationFeet = Int(m[1]) }
        if let m = firstMatch(#"(\d{2,3})\s*avg\s*rpm"#, in: text) { s.avgRPM = Int(m[1]) }
        if let m = firstMatch(#"(\d{2,4})\s*avg\s*watts?"#, in: text) { s.avgWatts = Int(m[1]) }

        // Incline "2.6 % avg · 10.0 % max"
        let dec = #"(\d{1,2}(?:[.,]\d)?)"#
        if let m = firstMatch(dec + #"\s*%\s*avg"#, in: text) { s.inclineAvg = number(m[1]) }
        if let m = firstMatch(dec + #"\s*%\s*max"#, in: text) { s.inclineMax = number(m[1]) }

        // Resistance "10 avg · 16 max" (no % sign; prefer text after the word Resistance)
        let resText: String
        if let r = text.range(of: "resistance", options: .caseInsensitive) {
            resText = String(text[r.upperBound...])
        } else {
            resText = text
        }
        if let m = firstMatch(#"(?<![\d.%])(\d{1,2})\s*avg\b(?!\s*(?:rpm|watt))"#, in: resText) { s.resistanceAvg = Int(m[1]) }
        if let m = firstMatch(#"(?<![\d.])(\d{1,2})\s*max\b"#, in: resText.replacingOccurrences(of: #"\d+(?:[.,]\d)?\s*%\s*max"#, with: "", options: .regularExpression)) {
            s.resistanceMax = Int(m[1])
        }
        return s
    }

    // MARK: Title

    static func titleFromLines(_ lines: [String]) -> String? {
        guard let i = lines.firstIndex(where: { $0.range(of: #"last\s*complet"#, options: [.regularExpression, .caseInsensitive]) != nil }) else { return nil }
        // Title on the same line before "Last completed"
        if let r = lines[i].range(of: #"last\s*complet"#, options: [.regularExpression, .caseInsensitive]) {
            let prefix = cleanTitle(String(lines[i][..<r.lowerBound]))
            if let prefix { return prefix }
        }
        var j = i - 1
        while j >= 0 {
            if let t = cleanTitle(lines[j]) { return t }
            j -= 1
        }
        return nil
    }

    static func cleanTitle(_ s: String) -> String? {
        var t = s
        for b in buttonPhrases {
            t = t.replacingOccurrences(of: b, with: "", options: .caseInsensitive)
        }
        t = t.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        // Must look like a title: at least 2 words with letters.
        let letters = t.filter(\.isLetter).count
        return letters >= 4 && t.contains(" ") ? t : nil
    }

    /// The observation directly above "Last completed", left-aligned with it.
    static func titleByProximity(_ items: [RecognizedText]) -> String? {
        guard let anchor = items.first(where: { $0.text.range(of: #"last\s*complet"#, options: [.regularExpression, .caseInsensitive]) != nil }) else { return nil }
        let candidates = items.filter { item in
            item.box.midY < anchor.box.midY
                && anchor.box.minY - item.box.maxY < max(anchor.box.height, item.box.height) * 3
                && abs(item.box.minX - anchor.box.minX) < 0.08
                && cleanTitle(item.text) != nil
        }
        let best = candidates.max { $0.box.midY < $1.box.midY }
        return best.flatMap { cleanTitle($0.text) }
    }

    // MARK: Date

    static func parseDate(_ text: String, calendar: Calendar) -> Date? {
        let pattern = #"(\d{1,2})\s*[:.]\s*(\d{2})\s*([AaPp])\.?\s*[Mm]\.?\W{0,4}([A-Za-z]{3})[a-z]*\.?\s*(\d{1,2})\s*[,.]?\s*(\d{4})"#
        guard let m = firstMatch(pattern, in: text),
              var hour = Int(m[1]), let minute = Int(m[2]),
              let month = monthIndex(m[4]), let day = Int(m[5]), let year = Int(m[6]) else { return nil }
        let pm = m[3].lowercased() == "p"
        if hour == 12 { hour = 0 }
        if pm { hour += 12 }
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))
    }

    static func monthIndex(_ s: String) -> Int? {
        let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        return months.firstIndex(of: s.lowercased().prefix(3).description).map { $0 + 1 }
    }

    // MARK: Lines

    /// Groups observations into lines (top to bottom, left to right).
    static func groupIntoLines(_ items: [RecognizedText]) -> [String] {
        let sorted = items.sorted { $0.box.midY < $1.box.midY }
        var lines: [[RecognizedText]] = []
        for item in sorted {
            if let last = lines.last?.last,
               abs(item.box.midY - last.box.midY) < min(item.box.height, last.box.height) * 0.6 {
                lines[lines.count - 1].append(item)
            } else {
                lines.append([item])
            }
        }
        return lines.map { $0.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: " ") }
    }

    // MARK: Helpers

    static func normalize(_ s: String) -> String {
        s.replacingOccurrences(of: "\u{2013}", with: "-")
            .replacingOccurrences(of: "\u{2014}", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func number(_ s: String) -> Double? { Double(s.replacingOccurrences(of: ",", with: ".")) }

    /// Returns capture groups (index 0 = whole match; missing groups are "").
    static func firstMatch(_ pattern: String, in text: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (0..<m.numberOfRanges).map { i in
            Range(m.range(at: i), in: text).map { String(text[$0]) } ?? ""
        }
    }
}
