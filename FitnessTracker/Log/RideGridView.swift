import SwiftUI
import SwiftData

private extension Workout {
    var metricsText: String {
        let watts = avgWatts > 0 ? "\(avgWatts.formattedWholeNumber()) W avg" : "— W"
        return "\(distanceMiles.formattedMilesWithUnit()) · \(watts)"
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
                Text(workout.durationMinutes.formattedMinutes()).font(.subheadline)
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
                    Text(workout.durationMinutes.formattedMinutes()).font(.subheadline.weight(.semibold))
                }
                Text(workout.metricsText).font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            .padding(.vertical, 4)
            Spacer(minLength: 0)
        }
        .background(LogSurface.card, in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        // No stroke: sits on the grouped listRowBackground; Mac RideTile keeps its border.
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
            ForEach(days, id: \.day) { day in
                VStack(alignment: .leading, spacing: 8) {
                    DayHeader(day: day.day)
                    ForEach(day.items) { workout in
                        Button { onOpen(workout) } label: { RideTile(workout: workout) }
                            // borderless on Mac: List + .plain can still treat the enclosing
                            // row as the hit target and activate oddly with several buttons.
                            #if os(macOS)
                            .buttonStyle(.borderless)
                            #else
                            .buttonStyle(.plain)
                            #endif
                            .contextMenu {
                                Button(role: .destructive) { onDelete(workout) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
    }
}
