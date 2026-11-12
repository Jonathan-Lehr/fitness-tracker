import SwiftUI
import SwiftData

/// Scenery placeholder tinted by ride type (used when there's no usable photo).
struct ScenePlaceholder: View {
    let type: WorkoutType
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                LinearGradient(colors: [type.color, type.color.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h))
                    p.addLine(to: CGPoint(x: w * 0.35, y: h * 0.45))
                    p.addLine(to: CGPoint(x: w * 0.6, y: h * 0.75))
                    p.addLine(to: CGPoint(x: w * 0.8, y: h * 0.5))
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.closeSubpath()
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
            guard let data = workout.photoData else { image = nil; return }
            let id = String(describing: workout.persistentModelID)
            image = await ThumbnailStore.shared.thumbnail(id: id, data: data, aspect: aspect,
                                                          focus: workout.thumbnailFocus)
        }
    }

    /// Restarts the thumbnail task when the focus changes, e.g. once the backfill analyzes the photo.
    private var taskID: ThumbnailTaskID {
        ThumbnailTaskID(model: workout.persistentModelID, focus: workout.thumbnailFocus,
                        analysisVersion: workout.thumbnailFocusAnalysisVersion)
    }

    private struct ThumbnailTaskID: Equatable {
        let model: PersistentIdentifier
        let focus: CGRect?
        let analysisVersion: Int
    }
}
