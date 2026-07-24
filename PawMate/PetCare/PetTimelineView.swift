import SwiftUI

struct PetTimelineView: View {
    @EnvironmentObject private var store: PetStore
    @State private var showAdd = false

    private let accent = PetPalette.timeline

    var body: some View {
        NavigationStack {
            Group {
                if store.timeline.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            let events = store.sortedTimeline
                            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                                row(event, isLast: index == events.count - 1)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                }
            }
            .background(ScreenBackground(accent: accent))
            .navigationTitle("Timeline")
            .settingsToolbar()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) { AddEventView().environmentObject(store) }
        }
        .tint(accent)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles").font(.system(size: 44)).foregroundStyle(accent)
            Text("No moments yet").font(.title3.weight(.semibold))
            Text("Log photos, weigh-ins, grooming and more.\nTap ＋ to add your first entry.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private func row(_ event: TimelineEvent, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Image(systemName: event.kind.icon)
                    .font(.callout).foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(event.kind.color.diagonal, in: Circle())
                if !isLast {
                    Rectangle().fill(Color.secondary.opacity(0.25)).frame(width: 2).frame(maxHeight: .infinity)
                }
            }
            .frame(width: 42)

            PetCard(accent: event.kind.color) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(event.title).font(.headline)
                        Spacer()
                        Text(event.date.formatted(.relative(presentation: .named)))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if !event.subtitle.isEmpty {
                        Text(event.subtitle).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.bottom, 14)
            .contextMenu {
                Button(role: .destructive) { store.deleteEvent(event) } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Add event

private struct AddEventView: View {
    @EnvironmentObject private var store: PetStore
    @Environment(\.dismiss) private var dismiss

    @State private var kind: TimelineKind = .photo
    @State private var title = ""
    @State private var subtitle = ""
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Type", selection: $kind) {
                        ForEach(TimelineKind.allCases) { k in
                            Label(k.label, systemImage: k.icon).tag(k)
                        }
                    }
                }
                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Note (optional)", text: $subtitle)
                    DatePicker("When", selection: $date)
                }
            }
            .navigationTitle("New Moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.addEvent(TimelineEvent(kind: kind,
                                                     title: title.trimmingCharacters(in: .whitespaces),
                                                     subtitle: subtitle.trimmingCharacters(in: .whitespaces),
                                                     date: date))
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    PetTimelineView().environmentObject(PetStore())
}
