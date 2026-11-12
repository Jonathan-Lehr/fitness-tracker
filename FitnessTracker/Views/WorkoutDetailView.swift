import SwiftUI

struct WorkoutDetailView: View {
    let workout: Workout
    @State private var showEdit = false

    /// Margin between the screen edge and the summary card.
    private let screenMargin: CGFloat = 12
    /// Notes text lines up with the text inside the summary card.
    private var notesInset: CGFloat { screenMargin + WorkoutSummaryCard.contentInset }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                WorkoutSummaryCard(workout: workout)
                    .padding(.horizontal, screenMargin)

                notesSection
            }
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .background(LogSurface.page)
        .navigationTitle(workout.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            WorkoutFormView(workout: workout)
        }
    }

    @ViewBuilder private var notesSection: some View {
        if let notes = workout.notes, !notes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                    .padding(.horizontal, notesInset)
                    .padding(.bottom, 8)
                Text("Notes")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.leading, notesInset)
                Text(notes)
                    .padding(.horizontal, notesInset)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Summary card for a single workout: photo, title, date and type, then distance and average
/// Watts featured above the secondary stats. Stats use the shared `StatTile` so they match the
/// period summary cards; no deltas until baseline comparison lands (#28).
struct WorkoutSummaryCard: View {
    let workout: Workout

    /// Padding between the card's edge and its photo.
    static let cardPadding: CGFloat = 14
    /// Extra inset for text so it lines up optically with the photo's rounded corners.
    static let textInset: CGFloat = 4
    /// Total inset from the card's edge to its text.
    static var contentInset: CGFloat { cardPadding + textInset }

    /// Secondary stats share one row in equal flexible columns; tile text scales down to fit.
    private let secondaryColumns = Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .leading), count: 4)
    /// Additional stats use two equal columns.
    private let additionalColumns = Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .leading), count: 2)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            photo
            heading
                .padding(.horizontal, Self.textInset)
            featuredStats
                .padding(.horizontal, Self.textInset)
            statGrid(secondaryStats, columns: secondaryColumns)
                .padding(.horizontal, Self.textInset)
            additionalStats
                .padding(.horizontal, Self.textInset)
        }
        .padding(Self.cardPadding)
        .background(LogSurface.card, in: RoundedRectangle(cornerRadius: 20))
    }

    private var photo: some View {
        RideImage(workout: workout, aspect: 16.0 / 9.0)
            .frame(maxHeight: 220)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(workout.title)
                .font(.title2.bold())
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            HStack {
                Text(workout.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
                TypeTag(type: workout.type, contentAlignment: .center)
            }
            .padding(.vertical, 8)
        }
    }

    private var featuredStats: some View {
        VStack(alignment: .leading, spacing: 2) {
            FeaturedStat(value: workout.distanceMiles.formattedMiles(), unit: "Miles",
                         valueFont: .title.bold(), unitFont: .title3.weight(.semibold))
            FeaturedStat(value: wattsValue, unit: "Watts",
                         valueFont: .title2.bold(), unitFont: .headline, color: .orange)
        }
    }

    private var wattsValue: String {
        workout.avgWatts > 0 ? workout.avgWatts.formattedWholeNumber() : "—"
    }

    private var secondaryStats: [StatTile] {
        [
            StatTile(value: workout.durationMinutes.formattedMinutes(), label: "Duration",
                     numericValue: workout.durationMinutes),
            StatTile(value: workout.calories.formattedWholeNumber(), label: "Calories",
                     numericValue: Double(workout.calories)),
            StatTile(value: "\(workout.elevationFeet.formattedWholeNumber()) ft", label: "Elevation",
                     numericValue: Double(workout.elevationFeet)),
            StatTile(value: workout.avgRPM > 0 ? workout.avgRPM.formattedWholeNumber() : "—", label: "RPM",
                     numericValue: Double(workout.avgRPM)),
        ]
    }

    private var additionalStats: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Additional Stats")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            statGrid(additionalStatTiles, columns: additionalColumns)
        }
    }

    private var additionalStatTiles: [StatTile] {
        [
            StatTile(value: "\(workout.inclineAvg.formattedPercent(fractionLength: 1)) / \(workout.inclineMax.formattedPercent(fractionLength: 1))",
                     label: "Incline avg / max"),
            StatTile(value: "\(workout.resistanceAvg.formattedWholeNumber()) / \(workout.resistanceMax.formattedWholeNumber())",
                     label: "Resistance avg / max"),
        ]
    }

    private func statGrid(_ tiles: [StatTile], columns: [GridItem]) -> some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(tiles.indices, id: \.self) { index in
                tiles[index]
            }
        }
    }
}

/// A featured value followed by its unit in a smaller font, both in the same color
/// (as in Apple Fitness), e.g. a bold "19.14" with a smaller "Miles".
private struct FeaturedStat: View {
    let value: String
    let unit: String
    let valueFont: Font
    let unitFont: Font
    var color: Color = .primary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
                .font(valueFont)
                .monospacedDigit()
            Text(unit)
                .font(unitFont)
        }
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
}
