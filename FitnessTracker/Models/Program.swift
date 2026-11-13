import Foundation
import SwiftData

enum WorkoutType: String, CaseIterable, Identifiable, Codable {
    case endurance
    case interval
    case recovery
    case climb
    case tempo
    case other

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    static func infer(from title: String) -> WorkoutType {
        let loweredTitle = title.lowercased()
        for type in WorkoutType.allCases where type != .other {
            if loweredTitle.contains(type.rawValue) { return type }
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

    /// Title with leading and trailing whitespace and newlines removed.
    static func normalizedTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Case-insensitive key for matching program titles.
    static func normalizedTitleKey(_ title: String) -> String {
        normalizedTitle(title).lowercased()
    }

    /// Finds a program by title (case-insensitive, ignoring surrounding whitespace) or creates one.
    static func findOrCreate(title: String, in context: ModelContext) -> Program {
        let trimmed = normalizedTitle(title)
        let key = normalizedTitleKey(trimmed)
        let all = (try? context.fetch(FetchDescriptor<Program>())) ?? []
        if let existing = all.first(where: { normalizedTitleKey($0.title) == key }) {
            return existing
        }
        let program = Program(title: trimmed)
        context.insert(program)
        return program
    }
}
