import SwiftUI

struct PetJournalView: View {
    @EnvironmentObject private var store: PetStore
    @State private var selectedID: UUID?

    private let accent = PetPalette.journal

    private var days: [JournalDay] { store.sortedJournal }
    private var selectedDay: JournalDay? {
        days.first { $0.id == selectedID } ?? days.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    daySelector
                    if let day = selectedDay {
                        entryCard(for: day)
                        sleepCard(for: day)
                        noteCard(for: day)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(ScreenBackground(accent: accent))
            .navigationTitle("Journal")
            .settingsToolbar()
        }
        .tint(accent)
        .onAppear {
            let today = store.ensureToday()
            if selectedID == nil { selectedID = today.id }
        }
    }

    private var daySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(days) { day in
                    let isSelected = day.id == (selectedDay?.id)
                    VStack(spacing: 4) {
                        Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(isSelected ? .white : .secondary)
                        Text(day.date.formatted(.dateTime.day()))
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(isSelected ? .white : .primary)
                    }
                    .frame(width: 48, height: 62)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(isSelected ? AnyShapeStyle(accent.diagonal) : AnyShapeStyle(Color(.secondarySystemGroupedBackground)))
                    )
                    .onTapGesture { withAnimation { selectedID = day.id } }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func entryCard(for day: JournalDay) -> some View {
        let binding = store.binding(for: day)
        return PetCard(accent: accent) {
            VStack(alignment: .leading, spacing: 14) {
                Text(day.date.formatted(date: .complete, time: .omitted))
                    .font(.system(.title3, design: .rounded)).bold()

                logRow(binding.ate,    emoji: "🍖", label: "Ate",        color: PetPalette.home)
                logRow(binding.walked, emoji: "🚶", label: "Walked",     color: PetPalette.journal)
                logRow(binding.meds,   emoji: "💊", label: "Medication", color: PetPalette.health)
                logRow(binding.stool,  emoji: "💩", label: "Stool",      color: .brown)
            }
        }
    }

    private func logRow(_ isOn: Binding<Bool>, emoji: String, label: String, color: Color) -> some View {
        Button {
            withAnimation { isOn.wrappedValue.toggle() }
        } label: {
            HStack(spacing: 12) {
                Text(emoji).font(.title3)
                Text(label).font(.body.weight(.medium)).foregroundStyle(.primary)
                Spacer()
                Image(systemName: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn.wrappedValue ? color : Color.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func sleepCard(for day: JournalDay) -> some View {
        let binding = store.binding(for: day)
        return PetCard(accent: PetPalette.timeline) {
            HStack(spacing: 16) {
                Text("😴").font(.system(size: 34))
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sleep").font(.subheadline).foregroundStyle(.secondary)
                    Stepper(value: binding.sleepHours, in: 0...24, step: 1) {
                        Text("\(Int(day.sleepHours)) hours")
                            .font(.system(.title3, design: .rounded)).bold()
                    }
                }
            }
        }
    }

    private func noteCard(for day: JournalDay) -> some View {
        let binding = store.binding(for: day)
        return PetCard(accent: accent) {
            VStack(alignment: .leading, spacing: 10) {
                Label("Note", systemImage: "square.and.pencil")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                TextField("How was the day?", text: binding.note, axis: .vertical)
                    .lineLimit(2...5)
            }
        }
    }
}

#Preview {
    PetJournalView().environmentObject(PetStore())
}
