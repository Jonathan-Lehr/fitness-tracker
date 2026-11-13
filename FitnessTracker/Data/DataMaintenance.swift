import Foundation
import SwiftData

enum DataMaintenance {
    static func deleteAll(_ context: ModelContext, simulatedOnly: Bool = false) {
        let workouts = (try? context.fetch(FetchDescriptor<Workout>())) ?? []
        for workout in workouts where !simulatedOnly || workout.isSimulated { context.delete(workout) }
        let programs = (try? context.fetch(FetchDescriptor<Program>())) ?? []
        for program in programs where (program.workouts ?? []).allSatisfy({ !simulatedOnly || $0.isSimulated }) {
            context.delete(program)
        }
        try? context.save()
    }
}
