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
        case title
        case date
        case duration
        case distance
        case calories
        case elevation
        case rpm
        case watts
        case inclineAvg
        case inclineMax
        case resistanceAvg
        case resistanceMax
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
        var missing = Set<Field>()
        if title == nil { missing.insert(.title) }
        if date == nil { missing.insert(.date) }
        if durationMinutes == nil { missing.insert(.duration) }
        if distanceMiles == nil { missing.insert(.distance) }
        if calories == nil { missing.insert(.calories) }
        if elevationFeet == nil { missing.insert(.elevation) }
        if avgRPM == nil { missing.insert(.rpm) }
        if avgWatts == nil { missing.insert(.watts) }
        if inclineAvg == nil { missing.insert(.inclineAvg) }
        if inclineMax == nil { missing.insert(.inclineMax) }
        if resistanceAvg == nil { missing.insert(.resistanceAvg) }
        if resistanceMax == nil { missing.insert(.resistanceMax) }
        return missing
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
        if let title = titleByProximity(items) { summary.title = title }
        // Geometry fallbacks when the unit landed on a different "line" than its value.
        if summary.distanceMiles == nil, let distanceText = valueLeftOf(unitPattern: miUnit, in: items) {
            summary.distanceMiles = parseDistance(distanceText + " mi")
        }
        if summary.elevationFeet == nil, let elevationText = valueLeftOf(unitPattern: ftUnit, in: items) {
            summary.elevationFeet = parseElevation(elevationText + " ft")
        }
        return summary
    }

    /// Parse from OCR lines ordered top to bottom.
    static func parse(lines rawLines: [String], calendar: Calendar = .current) -> IFitSummary {
        let lines = rawLines.map(normalize).filter { !$0.isEmpty }
        let text = lines.joined(separator: " ")
        var summary = IFitSummary()

        summary.title = titleFromLines(lines)
        summary.date = parseDate(text, calendar: calendar)

        // Duration: "1 hr 5 min", "1hr", "42 min"
        if let m = firstMatch(#"(\d{1,2})\s*hrs?\b(?:\s*(\d{1,2})\s*min)?"#, in: text) {
            summary.durationMinutes = Double((Int(m[1]) ?? 0) * 60 + (Int(m[2]) ?? 0))
        } else if let m = firstMatch(#"(\d{1,3})\s*min\b"#, in: text) {
            summary.durationMinutes = Double(m[1])
        }
        summary.distanceMiles = parseDistance(text)
        if let m = firstMatch(#"(\d{2,4})\s*ca[l1I]s?\b"#, in: text) { summary.calories = Int(m[1]) }
        summary.elevationFeet = parseElevation(text)
        if let m = firstMatch(#"(\d{2,3})\s*avg\s*rpm"#, in: text) { summary.avgRPM = Int(m[1]) }
        if let m = firstMatch(#"(\d{2,4})\s*avg\s*watts?"#, in: text) { summary.avgWatts = Int(m[1]) }

        // Incline "2.6 % avg · 10.0 % max"
        let dec = #"(\d{1,2}(?:[.,]\d)?)"#
        if let m = firstMatch(dec + #"\s*%\s*avg"#, in: text) { summary.inclineAvg = inclinePercent(m[1]) }
        if let m = firstMatch(dec + #"\s*%\s*max"#, in: text) { summary.inclineMax = inclinePercent(m[1]) }

        // Resistance "10 avg · 16 max" (no % sign; prefer text after the word Resistance)
        let resText: String
        if let range = text.range(of: "resistance", options: .caseInsensitive) {
            resText = String(text[range.upperBound...])
        } else {
            resText = text
        }
        if let m = firstMatch(#"(?<![\d.%])(\d{1,2})\s*avg\b(?!\s*(?:rpm|watt))"#, in: resText) { summary.resistanceAvg = Int(m[1]) }
        if let m = firstMatch(#"(?<![\d.])(\d{1,2})\s*max\b"#, in: resText.replacingOccurrences(of: #"\d+(?:[.,]\d)?\s*%\s*max"#, with: "", options: .regularExpression)) {
            summary.resistanceMax = Int(m[1])
        }
        return summary
    }

    // MARK: Distance & elevation (camera OCR is noisiest here)

    /// Fuzzy "mi": OCR often reads ml, rni, mI, m1, or "mi." (only matched right after a number).
    static let miUnit = #"(?:mi|ml|rni|m[I1l|]|nni)\b\.?"#
    /// Fuzzy "ft": ff, fl, f t, it, Ft.
    static let ftUnit = #"(?:f\s?t|ff|fl|[iI]t)\b"#

    static func parseDistance(_ text: String) -> Double? {
        // 1) number + mi; decimal may be ".", ",", a space, or dropped.
        if let m = firstMatch(#"(?<![\d.,])(\d{1,2})\s?[.,·:\s]\s?(\d{1,2})\s*"# + miUnit, in: text),
           let v = Double("\(m[1]).\(m[2])"), validDistance(v) { return v }
        if let m = firstMatch(#"(?<![\d.,])(\d{1,4})\s*"# + miUnit, in: text), let v = droppedDecimal(m[1]) { return v }
        // 2) unit missing/garbled: a two-decimal number not followed by % (iFit shows miles as x.xx,
        //    incline uses one decimal plus %).
        if let m = firstMatch(#"(?<![\d.,])(\d{1,2})[.,](\d{2})(?![\d%]|\s*%)"#, in: text),
           let v = Double("\(m[1]).\(m[2])"), validDistance(v) { return v }
        return nil
    }

    static func validDistance(_ miles: Double) -> Bool { miles > 0 && miles <= 60 }

    /// "1388" read without its decimal point -> 13.88 (miles always have two decimals on this screen).
    static func droppedDecimal(_ digits: String) -> Double? {
        guard let number = Double(digits) else { return nil }
        if digits.count >= 3 {
            let value = number / 100
            return validDistance(value) ? value : nil
        }
        return validDistance(number) ? number : nil
    }

    static func parseElevation(_ text: String) -> Int? {
        // Thousands separators: "1,543", "1.543", "1 543", or none.
        let num = #"(?<![\d.,])(\d{1,2}[,.\s]\d{3}|\d{1,5})"#
        if let m = firstMatch(num + #"\s*"# + ftUnit, in: text), let v = integer(m[1]), validElevation(v) { return v }
        // Unit missing: the stats row is "... cals (est) <ft> <rpm> avg rpm ...", so take the
        // number between calories and the rpm value.
        if let m = firstMatch(#"ca[l1I|]s?\s*(?:\(?\s*est\s*\)?)?\s*"# + num + #"\b(?!\s*avg)\D{0,6}\d{2,3}\s*avg\s*rpm"#, in: text),
           let v = integer(m[1]), validElevation(v) { return v }
        return nil
    }

    static func validElevation(_ feet: Int) -> Bool { feet >= 0 && feet <= 10_000 }

    static func integer(_ text: String) -> Int? { Int(text.filter(\.isNumber)) }

    // MARK: Geometry fallback

    /// For a unit-only observation (e.g. "mi" on its own), find the nearest number to its left
    /// on roughly the same row. Survives perspective skew that breaks line grouping.
    static func valueLeftOf(unitPattern: String, in items: [RecognizedText]) -> String? {
        let unitItems = items.filter {
            $0.text.range(of: "^\\s*" + unitPattern + "\\s*$", options: [.regularExpression, .caseInsensitive]) != nil
        }
        for unit in unitItems {
            let candidates = items.filter { item in
                item.box.maxX <= unit.box.minX + unit.box.width * 0.5
                    && unit.box.minX - item.box.maxX < 0.12
                    && abs(item.box.midY - unit.box.midY) < max(item.box.height, unit.box.height) * 1.2
                    && item.text.contains(where: \.isNumber)
            }
            if let nearest = candidates.max(by: { $0.box.maxX < $1.box.maxX }) {
                return normalize(nearest.text)
            }
        }
        return nil
    }

    // MARK: Title

    /// Matches iFit's "Last completed" label, allowing spaces the OCR may drop or insert.
    static let lastCompletedPattern = #"last\s*complet"#

    static func titleFromLines(_ lines: [String]) -> String? {
        guard let completedIndex = lines.firstIndex(where: { $0.range(of: lastCompletedPattern, options: [.regularExpression, .caseInsensitive]) != nil }) else { return nil }
        // Title on the same line before "Last completed"
        if let range = lines[completedIndex].range(of: lastCompletedPattern, options: [.regularExpression, .caseInsensitive]) {
            let prefix = cleanTitle(String(lines[completedIndex][..<range.lowerBound]))
            if let prefix { return prefix }
        }
        var lineIndex = completedIndex - 1
        while lineIndex >= 0 {
            if let title = cleanTitle(lines[lineIndex]) { return title }
            lineIndex -= 1
        }
        return nil
    }

    static func cleanTitle(_ text: String) -> String? {
        var title = text
        for phrase in buttonPhrases {
            title = title.replacingOccurrences(of: phrase, with: "", options: .caseInsensitive)
        }
        title = title.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        // Must look like a title: at least 2 words with letters.
        let letters = title.filter(\.isLetter).count
        return letters >= 4 && title.contains(" ") ? title : nil
    }

    /// The observation directly above "Last completed", left-aligned with it.
    static func titleByProximity(_ items: [RecognizedText]) -> String? {
        guard let anchor = items.first(where: { $0.text.range(of: lastCompletedPattern, options: [.regularExpression, .caseInsensitive]) != nil }) else { return nil }
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

    static func monthIndex(_ name: String) -> Int? {
        let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        return months.firstIndex(of: name.lowercased().prefix(3).description).map { $0 + 1 }
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

    static func normalize(_ text: String) -> String {
        var normalized = text.replacingOccurrences(of: "\u{2013}", with: "-")
            .replacingOccurrences(of: "\u{2014}", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Letter/digit confusions next to digits: "1O.O2" -> "10.02", "l3.88" -> "13.88".
        for _ in 0..<2 {
            normalized = normalized.replacingOccurrences(of: #"(?<=\d)[Oo]|(?<=\d[.,])[Oo]|[Oo](?=[.,]?\d)"#, with: "0", options: .regularExpression)
            normalized = normalized.replacingOccurrences(of: #"(?<=\d)[lI|]|[lI|](?=\d)"#, with: "1", options: .regularExpression)
        }
        return normalized
    }

    static func number(_ text: String) -> Double? { Double(text.replacingOccurrences(of: ",", with: ".")) }

    /// Highest incline the bike supports, in percent.
    static let maximumInclinePercent = 20.0

    /// Incline percent, restoring a dropped decimal point: iFit shows incline with one decimal,
    /// so "28" above the bike's maximum incline was read from "2.8" (or similar).
    static func inclinePercent(_ text: String) -> Double? {
        guard let value = number(text) else { return nil }
        let hasDecimal = text.contains(".") || text.contains(",")
        return !hasDecimal && value > maximumInclinePercent ? value / 10 : value
    }

    /// Returns capture groups (index 0 = whole match; missing groups are "").
    static func firstMatch(_ pattern: String, in text: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (0..<m.numberOfRanges).map { i in
            Range(m.range(at: i), in: text).map { String(text[$0]) } ?? ""
        }
    }
}
