import SwiftUI
import SwiftData

struct FilterView: View {
    @Binding var filter: LogFilter
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Program.title) private var programs: [Program]
    @State private var minWattsText = ""

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
                    NavigationLink {
                        ProgramChooserView(selection: $filter.programTitle, titles: programs.map(\.title))
                    } label: {
                        LabeledContent("Program", value: filter.programTitle ?? "Any")
                    }
                    Picker("Type", selection: $filter.type) {
                        Text("Any").tag(WorkoutType?.none)
                        ForEach(WorkoutType.allCases) { Text($0.label).tag(WorkoutType?.some($0)) }
                    }
                }
                Section("Effort") {
                    LabeledContent("Min avg watts") {
                        TextField("None", text: $minWattsText)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                            .onChange(of: minWattsText) { _, newValue in
                                let digits = String(newValue.filter(\.isNumber).prefix(4))
                                if digits != newValue { minWattsText = digits }
                                filter.minWatts = Int(digits) ?? 0
                            }
                    }
                }
                Section {
                    Button("Reset Filters", role: .destructive) { filter = LogFilter(); minWattsText = "" }
                }
            }
            .formStyle(.grouped)
            .onAppear { minWattsText = filter.minWatts > 0 ? String(filter.minWatts) : "" }
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

/// Type-to-filter program chooser. Uses `.searchable` on iOS; on macOS a focused
/// text field so typing works immediately without clicking into a toolbar search field.
struct ProgramChooserView: View {
    @Binding var selection: String?
    let titles: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    #if os(macOS)
    @FocusState private var searchFocused: Bool
    #endif

    private var matches: [String] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? titles : titles.filter { $0.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        List {
            #if os(macOS)
            TextField("Search programs", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($searchFocused)
            #endif
            if query.isEmpty {
                row("Any program", value: nil)
            }
            ForEach(matches, id: \.self) { row($0, value: $0) }
            if matches.isEmpty {
                Text("No matching programs").foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Program")
        #if os(iOS)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search programs")
        #else
        .onAppear { searchFocused = true }
        #endif
    }

    private func row(_ label: String, value: String?) -> some View {
        Button {
            selection = value
            dismiss()
        } label: {
            HStack {
                Text(label).foregroundStyle(.primary)
                Spacer()
                if selection == value {
                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
