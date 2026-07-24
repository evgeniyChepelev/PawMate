import SwiftUI

struct PetHomeView: View {
    @EnvironmentObject private var store: PetStore
    @State private var showAddTask = false

    private let accent = PetPalette.home

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    petHeader
                    todayCard
                    vaccineCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(ScreenBackground(accent: accent))
            .navigationTitle("Home")
            .settingsToolbar()
            .sheet(isPresented: $showAddTask) { AddTaskView().environmentObject(store) }
        }
        .tint(accent)
    }

    private var pet: Pet { store.currentPet }

    private var petHeader: some View {
        HStack(spacing: 16) {
            Text(pet.emoji)
                .font(.system(size: 44))
                .frame(width: 78, height: 78)
                .background(.white.opacity(0.25), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.4), lineWidth: 1))

            VStack(alignment: .leading, spacing: 6) {
                Text(pet.name)
                    .font(.system(.title, design: .rounded)).bold()
                    .foregroundStyle(.white)
                Text([pet.breed, pet.ageDescription].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                if pet.weightKg > 0 {
                    Text("\(pet.weightKg, specifier: "%.1f") kg")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(.white.opacity(0.22), in: Capsule())
                }
            }
            Spacer()
        }
        .padding(20)
        .background(accent.diagonal, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: accent.opacity(0.35), radius: 14, y: 8)
    }

    private var todayCard: some View {
        PetCard(accent: accent) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Today")
                        .font(.system(.title3, design: .rounded)).bold()
                    Spacer()
                    Button { showAddTask = true } label: {
                        Image(systemName: "plus.circle.fill").font(.title3).foregroundStyle(accent)
                    }
                }

                if store.tasks.isEmpty {
                    emptyTasks
                } else {
                    HStack(spacing: 18) {
                        RingProgress(progress: store.todayCompletion, color: accent)
                            .frame(width: 74, height: 74)
                        VStack(spacing: 10) {
                            ForEach(store.tasks) { task in
                                taskRow(task)
                            }
                        }
                    }
                }
            }
        }
    }

    private func taskRow(_ task: CareTask) -> some View {
        Button {
            withAnimation { store.toggle(task) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.done ? task.color : Color.secondary)
                Image(systemName: task.icon)
                    .font(.footnote).foregroundStyle(task.color).frame(width: 22)
                Text(task.title)
                    .font(.body.weight(.medium))
                    .strikethrough(task.done, color: .secondary)
                    .foregroundStyle(task.done ? .secondary : .primary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) { store.deleteTask(task) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var emptyTasks: some View {
        VStack(spacing: 8) {
            Image(systemName: "checklist").font(.title).foregroundStyle(accent)
            Text("No tasks yet").font(.subheadline.weight(.medium))
            Text("Tap ＋ to add your first daily task.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var vaccineCard: some View {
        PetCard(accent: PetPalette.passport) {
            HStack(spacing: 16) {
                Image(systemName: "syringe.fill")
                    .font(.title2).foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(PetPalette.passport.diagonal, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next vaccine").font(.subheadline).foregroundStyle(.secondary)
                    if let days = store.daysUntilNextVaccine, let next = store.nextVaccine {
                        Text(days == 0 ? "Today" : "in \(days) days")
                            .font(.system(.title2, design: .rounded)).bold()
                        Text("\(next.name) · \(next.date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("None scheduled").font(.title3).bold()
                        Text("Add one in the Health tab").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
    }

}

// MARK: - Add task

private struct AddTaskView: View {
    @EnvironmentObject private var store: PetStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var icon = "bowl.fill"
    @State private var colorHex = TaskPalette.options[0]

    private let icons = ["bowl.fill", "figure.walk", "pills.fill", "drop.fill", "scissors",
                         "heart.fill", "pawprint.fill", "bed.double.fill", "cup.and.saucer.fill", "tennisball.fill"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)
                }
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 14) {
                        ForEach(icons, id: \.self) { symbol in
                            Image(systemName: symbol)
                                .font(.title3)
                                .foregroundStyle(icon == symbol ? Color(hex: colorHex) : .secondary)
                                .frame(width: 44, height: 44)
                                .background(icon == symbol ? Color(hex: colorHex).opacity(0.18) : Color(.tertiarySystemFill),
                                           in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .onTapGesture { icon = symbol }
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Color") {
                    HStack(spacing: 14) {
                        ForEach(TaskPalette.options, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 34, height: 34)
                                .overlay(Circle().strokeBorder(.primary.opacity(colorHex == hex ? 0.6 : 0), lineWidth: 2))
                                .onTapGesture { colorHex = hex }
                        }
                    }
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.addTask(CareTask(title: title.trimmingCharacters(in: .whitespaces),
                                               icon: icon, colorHex: colorHex, done: false))
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    PetHomeView().environmentObject(PetStore())
}
