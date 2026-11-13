import SwiftUI
import SwiftData

/// Scenery placeholder tinted by ride type (used when there's no usable photo).
struct ScenePlaceholder: View {
    let type: WorkoutType
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            ZStack {
                LinearGradient(colors: [type.color, type.color.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: height))
                    path.addLine(to: CGPoint(x: width * 0.35, y: height * 0.45))
                    path.addLine(to: CGPoint(x: width * 0.6, y: height * 0.75))
                    path.addLine(to: CGPoint(x: width * 0.8, y: height * 0.5))
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.closeSubpath()
                }
                .fill(Color.black.opacity(0.3))
            }
        }
        .accessibilityHidden(true)
    }
}

struct RideImage: View {
    let workout: Workout
    let aspect: Double
    @State private var image: CGImage?

    /// Restarts the thumbnail task when the focus changes, e.g. once the backfill analyzes the photo.
    private var taskID: ThumbnailTaskID {
        ThumbnailTaskID(model: workout.persistentModelID, focus: workout.thumbnailFocus,
                        analysisVersion: workout.thumbnailFocusAnalysisVersion)
    }

    var body: some View {
        ZStack {
            ScenePlaceholder(type: workout.type)
            if let image {
                // The crop already has the card's aspect; fit (not fill) so nothing more is cut.
                Image(decorative: image, scale: 1).resizable().scaledToFit()
            }
        }
        .aspectRatio(aspect, contentMode: .fit)
        .clipped()
        .task(id: taskID) {
            guard let data = workout.photoData else {
                image = nil
                return
            }
            let id = String(describing: workout.persistentModelID)
            image = await ThumbnailStore.shared.thumbnail(id: id, data: data, aspect: aspect,
                                                          focus: workout.thumbnailFocus)
        }
    }

    private struct ThumbnailTaskID: Equatable {
        let model: PersistentIdentifier
        let focus: CGRect?
        let analysisVersion: Int
    }
}
