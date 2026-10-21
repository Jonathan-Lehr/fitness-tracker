import Foundation
import SwiftData

/// CloudKit can't enforce uniqueness, so two devices can create the same Program or
/// Workout (e.g. both seed the real rides before syncing). This merges them.
enum DataDeduper {
    static func key(title: String, date: Date) -> String {
        // Minute precision: rides are entered from a screen that shows minutes only.
        let minute = Int(date.timeIntervalSinceReferenceDate / 60)
        return title.lowercased().trimmingCharacters(in: .whitespaces) + "|\(minute)"
    }

    static func key(_ w: Workout) -> String { key(title: w.title, date: w.date) }

    static func run(_ context: ModelContext) {
        var changed = false

        // 1. Programs with the same title (case-insensitive): keep the one with most rides.
        let programs = (try? context.fetch(FetchDescriptor<Program>())) ?? []
        let byTitle = Dictionary(grouping: programs) { $0.title.lowercased().trimmingCharacters(in: .whitespaces) }
        for (_, group) in byTitle where group.count > 1 {
            let sorted = group.sorted { ($0.workouts?.count ?? 0) > ($1.workouts?.count ?? 0) }
            let keeper = sorted[0]
            for dup in sorted.dropFirst() {
                for w in dup.workouts ?? [] { w.program = keeper }
                dup.workouts = []
                context.delete(dup)
                changed = true
            }
        }

        // 2. Workouts with the same title + start minute: keep the richest one.
        let workouts = (try? context.fetch(FetchDescriptor<Workout>())) ?? []
        for (_, group) in Dictionary(grouping: workouts, by: key) where group.count > 1 {
            let sorted = group.sorted { score($0) > score($1) }
            for dup in sorted.dropFirst() {
                context.delete(dup)
                changed = true
            }
        }

        if changed { try? context.save() }
    }

    private static func score(_ w: Workout) -> Int {
        (w.photoData != nil ? 2 : 0) + ((w.notes?.isEmpty == false) ? 1 : 0)
    }
}
