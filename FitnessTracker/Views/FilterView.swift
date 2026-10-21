import SwiftUI
import SwiftData

struct FilterView: View {
    @Binding var filter: LogFilter
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Program.title) private var programs: [Program]

    var body: some View {
        NavigationStack {
            Form {
                Section("Date Range") {
                    Toggle("Limit dates", isOn: $filter.useDateRange)
                    if filter.useDateRange {
                        DatePicker("From", selection: $filter.startDate, displayedComponents: .date)
                        DatePicker("To", selection: $filter.endDate, displayedComponents: .date)
                    }
                }
                Section("Workout") {
                    Picker("Program", selection: $filter.programTitle) {
                        Text("Any").tag(String?.none)
                        ForEach(programs) { Text($0.title).tag(String?.some($0.title)) }
                    }
                    Picker("Type", selection: $filter.type) {
                        Text("Any").tag(WorkoutType?.none)
                        ForEach(WorkoutType.allCases) { Text($0.label).tag(WorkoutType?.some($0)) }
                    }
                }
                Section("Effort") {
                    Stepper("Min avg watts: \(filter.minWatts)", value: $filter.minWatts, in: 0...300, step: 5)
                }
                Section {
                    Button("Reset Filters", role: .destructive) { filter = LogFilter() }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 420)
        #endif
    }
}
