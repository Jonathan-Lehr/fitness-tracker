import Foundation
import SwiftData

/// Analyzes workout photos that have no thumbnail focus yet: workouts saved before smart cropping, workouts
/// restored from older backups, and workouts analyzed by an older `ThumbnailFocusFinder.analysisVersion`.
/// Photos are analyzed one at a time on a background task; results are applied and saved on the
/// main context so open thumbnails re-crop right away. Workouts where Vision found nothing are marked
/// analyzed (focus nil) and skipped from then on.
@MainActor
enum ThumbnailFocusBackfill {
    private static var isRunning = false

    static func run(_ context: ModelContext) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        for workout in pendingWorkouts(context) {
            guard let photo = workout.photoData,
                  let analysis = await analyze(photo),
                  isStillCurrent(workout, photo: photo) else { continue }
            workout.apply(analysis)
            try? context.save()
        }
    }

    static func pendingWorkouts(_ context: ModelContext) -> [Workout] {
        let currentVersion = ThumbnailFocusFinder.analysisVersion
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { $0.thumbnailFocusAnalysisVersion < currentVersion })
        // photoData uses external storage, so it is checked after the fetch rather than in the predicate.
        return ((try? context.fetch(descriptor)) ?? []).filter(\.needsThumbnailFocusAnalysis)
    }

    /// The workout may have been deleted (e.g. by DataDeduper) or given a new photo while Vision ran.
    private static func isStillCurrent(_ workout: Workout, photo: Data) -> Bool {
        !workout.isDeleted && workout.modelContext != nil && workout.photoData == photo
    }

    private static func analyze(_ photo: Data) async -> ThumbnailFocusAnalysis? {
        await Task.detached(priority: .background) {
            ThumbnailFocusFinder.analyze(photoData: photo)
        }.value
    }
}
