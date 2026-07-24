import SwiftUI

struct PetHealthView: View {
    @EnvironmentObject private var store: PetStore
    @State private var showEditWeight = false
    @State private var showAddVaccine = false
    @State private var showAddMed = false

    private let accent = PetPalette.health

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    weightHero
                    statRow
                    vaccinesCard
                    medsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(ScreenBackground(accent: accent))
            .navigationTitle("Health")
            .settingsToolbar()
            .sheet(isPresented: $showEditWeight) { EditWeightView().environmentObject(store) }
            .sheet(isPresented: $showAddVaccine) { AddVaccineView().environmentObject(store) }
            .sheet(isPresented: $showAddMed) { AddMedicationView().environmentObject(store) }
        }
        .tint(accent)
    }

    private var weightHero: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Current weight", systemImage: "scalemass.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Button { showEditWeight = true } label: {
                    Image(systemName: "square.and.pencil").foregroundStyle(.white)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(store.currentPet.weightKg > 0 ? String(format: "%.1f", store.currentPet.weightKg) : "—")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                Text("kg").font(.title3.weight(.semibold)).opacity(0.9)
            }
            .foregroundStyle(.white)
            Text("Tap the pencil to update after each weigh-in.")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(accent.diagonal, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: accent.opacity(0.35), radius: 14, y: 8)
    }

    private var statRow: some View {
        HStack(spacing: 12) {
            StatTile(icon: "checkmark.seal.fill", title: "Last vaccine",
                     value: store.lastVaccine?.date.formatted(.dateTime.month(.abbreviated).day()) ?? "—",
                     color: PetPalette.passport)
            StatTile(icon: "calendar", title: "Next vaccine",
                     value: store.nextVaccine?.date.formatted(.dateTime.month(.abbreviated).day()) ?? "—",
                     color: PetPalette.journal)
            StatTile(icon: "pills.fill", title: "Active meds",
                     value: "\(store.activeMedications.count)", color: accent)
        }
    }

    private var vaccinesCard: some View {
        PetCard(accent: PetPalette.passport) {
            VStack(alignment: .leading, spacing: 14) {
                header("Vaccinations", color: PetPalette.passport) { showAddVaccine = true }
                if store.vaccines.isEmpty {
                    emptyLine("No vaccines added yet.")
                } else {
                    ForEach(store.vaccines.sorted { $0.date < $1.date }) { vaccine in
                        let upcoming = vaccine.date >= Calendar.current.startOfDay(for: Date())
                        HStack(spacing: 12) {
                            Circle().fill(upcoming ? PetPalette.journal : Color.secondary).frame(width: 10, height: 10)
                            Text(vaccine.name).font(.body.weight(.medium))
                            Spacer()
                            Text(vaccine.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        .contextMenu {
                            Button(role: .destructive) { store.deleteVaccine(vaccine) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private var medsCard: some View {
        PetCard(accent: accent) {
            VStack(alignment: .leading, spacing: 14) {
                header("Medications", color: accent) { showAddMed = true }
                if store.medications.isEmpty {
                    emptyLine("No medications added yet.")
                } else {
                    ForEach(store.medications) { med in
                        HStack(spacing: 12) {
                            Image(systemName: "pills.fill")
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .background((med.active ? accent : Color.secondary).diagonal,
                                            in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(med.name).font(.body.weight(.medium))
                                Text(med.schedule).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button { store.toggleMedication(med) } label: {
                                ChipView(text: med.active ? "Active" : "Paused",
                                         color: med.active ? PetPalette.journal : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .contextMenu {
                            Button(role: .destructive) { store.deleteMedication(med) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private func header(_ title: String, color: Color, add: @escaping () -> Void) -> some View {
        HStack {
            Text(title).font(.system(.title3, design: .rounded)).bold()
            Spacer()
            Button(action: add) {
                Image(systemName: "plus.circle.fill").font(.title3).foregroundStyle(color)
            }
        }
    }

    private func emptyLine(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
    }
}

// MARK: - Edit weight

private struct EditWeightView: View {
    @EnvironmentObject private var store: PetStore
    @Environment(\.dismiss) private var dismiss
    @State private var weight = 0.0

    var body: some View {
        NavigationStack {
            Form {
                Section("Weight") {
                    HStack {
                        TextField("0.0", value: $weight, format: .number)
                            .keyboardType(.decimalPad)
                        Text("kg").foregroundStyle(.secondary)
                    }
                    Stepper("Adjust", value: $weight, in: 0...200, step: 0.1)
                }
            }
            .navigationTitle("Update Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.updateWeight(weight); dismiss() }
                }
            }
            .onAppear { weight = store.currentPet.weightKg }
        }
    }
}

// MARK: - Add vaccine

private struct AddVaccineView: View {
    @EnvironmentObject private var store: PetStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Vaccine") {
                    TextField("Name (e.g. Rabies)", text: $name)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle("Add Vaccine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.addVaccine(VaccineRecord(name: name.trimmingCharacters(in: .whitespaces), date: date))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Add medication

private struct AddMedicationView: View {
    @EnvironmentObject private var store: PetStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var schedule = ""
    @State private var active = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Medication") {
                    TextField("Name", text: $name)
                    TextField("Schedule (e.g. 1 tablet · daily)", text: $schedule)
                    Toggle("Active", isOn: $active)
                }
            }
            .navigationTitle("Add Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.addMedication(Medication(name: name.trimmingCharacters(in: .whitespaces),
                                                       schedule: schedule, active: active))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    PetHealthView().environmentObject(PetStore())
}
