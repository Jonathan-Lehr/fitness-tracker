import SwiftUI

extension WorkoutType {
    /// Tag colors shared by grid cards and placeholders. Always paired with the text label.
    var color: Color {
        tagColor.color
    }

    private var tagColor: AppColor {
        switch self {
        case .endurance: .tagEndurance
        case .climb: .tagClimb
        case .interval: .tagInterval
        case .recovery: .tagRecovery
        case .tempo: .tagTempo
        case .other: .tagOther
        }
    }
}

struct TypeTag: View {
    let type: WorkoutType
    /// Where the dot and label sit within the shared tag width: leading in lists so tags
    /// read in a column, centered in the detail view where the tag stands alone.
    var contentAlignment: HorizontalAlignment = .leading

    var body: some View {
        ZStack(alignment: Alignment(horizontal: contentAlignment, vertical: .center)) {
            // Hidden copies of every type reserve the longest one's width, so tags line up and
            // track Dynamic Type; the visible content is aligned within that width.
            ForEach(WorkoutType.allCases) { candidate in
                content(for: candidate).hidden()
            }
            content(for: type)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.primary)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(type.color.opacity(0.22), in: Capsule())
        .overlay(Capsule().strokeBorder(type.color.opacity(0.55), lineWidth: 1))
        .accessibilityLabel("Type: \(type.label)")
    }

    private func content(for type: WorkoutType) -> some View {
        HStack(spacing: 4) {
            Circle().fill(type.color).frame(width: 7, height: 7)
            Text(type.label)
        }
    }
}
