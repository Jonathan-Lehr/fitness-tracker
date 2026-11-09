import SwiftUI
import SwiftData

/// Card fill matching the Log List's rows (inset grouped on iOS, inset list on macOS).
enum LogSurface {
    #if os(macOS)
    static let card = Color(nsColor: NSColor.alternatingContentBackgroundColors.last ?? .controlBackgroundColor)
    #else
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    #endif
}

extension WorkoutType {
    /// Tag colors shared by grid cards and placeholders. Always paired with the text label.
    var color: Color {
        switch self {
        case .endurance: Color(red: 0.20, green: 0.47, blue: 0.80)
        case .climb: Color(red: 0.27, green: 0.59, blue: 0.35)
        case .interval: Color(red: 0.89, green: 0.38, blue: 0.27)
        case .recovery: Color(red: 0.49, green: 0.39, blue: 0.76)
        case .tempo: Color(red: 0.84, green: 0.60, blue: 0.15)
        case .other: Color.gray
        }
    }
}

struct TypeTag: View {
    let type: WorkoutType
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(type.color).frame(width: 7, height: 7)
            Text(type.label)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.primary)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(type.color.opacity(0.22), in: Capsule())
        .overlay(Capsule().strokeBorder(type.color.opacity(0.55), lineWidth: 1))
        .accessibilityLabel("Type: \(type.label)")
    }
}

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
        .task(id: workout.persistentModelID) {
            guard let data = workout.photoData else { image = nil; return }
            let id = String(describing: workout.persistentModelID)
            image = await ThumbnailStore.shared.thumbnail(id: id, data: data, aspect: aspect)
        }
    }
}

private extension Workout {
    var metricsText: String {
        let watts = avgWatts > 0 ? "\(avgWatts) W avg" : "— W"
        return "\(distanceMiles.milesText) · \(watts)"
    }
}

/// Vertical card for the wide (Mac / regular width) day columns.
struct RideTile: View {
    let workout: Workout
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RideImage(workout: workout, aspect: 2)
                .overlay(alignment: .topLeading) {
                    TypeTag(type: workout.type).background(.regularMaterial, in: Capsule()).padding(8)
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.title).font(.headline).lineLimit(2, reservesSpace: true)
                Text(workout.durationMinutes.minutesText).font(.subheadline)
                Text(workout.metricsText).font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            .padding(10)
        }
        .background(LogSurface.card, in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator))
    }
}

/// Full-width horizontal card for compact (iPhone) width.
struct RideRowCard: View {
    let workout: Workout
    var body: some View {
        HStack(spacing: 12) {
            RideImage(workout: workout, aspect: 4.0 / 3.0)
                .frame(width: 112)
            VStack(alignment: .leading, spacing: 5) {
                Text(workout.title).font(.headline).lineLimit(2, reservesSpace: true)
                HStack(spacing: 8) {
                    TypeTag(type: workout.type)
                    Text(workout.durationMinutes.minutesText).font(.subheadline.weight(.semibold))
                }
                Text(workout.metricsText).font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            .padding(.vertical, 8)
            Spacer(minLength: 0)
        }
        .background(LogSurface.card, in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator))
    }
}

struct DayHeader: View {
    let day: Date
    var body: some View {
        Text(day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Wide (Mac / regular) period section: adaptive day columns. Compact iPhone uses native List rows instead.
struct RideGridSection: View {
    let workouts: [Workout]
    /// Opens a single ride detail. Must not use NavigationLink here: several cards share one
    /// List row, and multiple NavigationLinks in that row can push several destinations at once.
    let onOpen: (Workout) -> Void
    let onDelete: (Workout) -> Void

    private var days: [DayGroup<Workout>] { DayGroup.group(workouts, date: \.date) }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16, alignment: .top)],
                  alignment: .leading, spacing: 16) {
            ForEach(days, id: \.day) { g in
                VStack(alignment: .leading, spacing: 8) {
                    DayHeader(day: g.day)
                    ForEach(g.items) { w in
                        Button { onOpen(w) } label: { RideTile(workout: w) }
                            // borderless on Mac: List + .plain can still treat the enclosing
                            // row as the hit target and activate oddly with several buttons.
                            #if os(macOS)
                            .buttonStyle(.borderless)
                            #else
                            .buttonStyle(.plain)
                            #endif
                            .contextMenu {
                                Button(role: .destructive) { onDelete(w) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
    }
}
