import Foundation
import SwiftData

enum DataMaintenance {
    static func deleteAll(_ context: ModelContext, simulatedOnly: Bool = false) {
        let workouts = (try? context.fetch(FetchDescriptor<Workout>())) ?? []
        for w in workouts where !simulatedOnly || w.isSimulated { context.delete(w) }
        let programs = (try? context.fetch(FetchDescriptor<Program>())) ?? []
        for p in programs where (p.workouts ?? []).allSatisfy({ !simulatedOnly || $0.isSimulated }) {
            context.delete(p)
        }
        try? context.save()
    }
}
