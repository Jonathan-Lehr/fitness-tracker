import Foundation
import SwiftData

enum WorkoutType: String, CaseIterable, Identifiable, Codable {
    case endurance, interval, recovery, climb, tempo, other
    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    static func infer(from title: String) -> WorkoutType {
        let t = title.lowercased()
        for type in WorkoutType.allCases where type != .other {
            if t.contains(type.rawValue) { return type }
        }
        return .other
    }
}

@Model
final class Program {
    // No @Attribute(.unique): CloudKit doesn't support it. Uniqueness by title is enforced in code.
    var title: String = ""
    var typeRaw: String = WorkoutType.other.rawValue
    @Relationship(deleteRule: .cascade, inverse: \Workout.program)
    var workouts: [Workout]? = []

    init(title: String, type: WorkoutType? = nil) {
        self.title = title
        self.typeRaw = (type ?? WorkoutType.infer(from: title)).rawValue
    }

    var type: WorkoutType {
        get { WorkoutType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    var sortedWorkouts: [Workout] {
        (workouts ?? []).sorted { $0.date < $1.date }
    }

    /// Finds a program by title (case-insensitive) or creates one.
    static func findOrCreate(title: String, in context: ModelContext) -> Program {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let all = (try? context.fetch(FetchDescriptor<Program>())) ?? []
        if let existing = all.first(where: { $0.title.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return existing
        }
        let p = Program(title: trimmed)
        context.insert(p)
        return p
    }
}
