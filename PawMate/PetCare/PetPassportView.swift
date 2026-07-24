import SwiftUI

struct PetPassportView: View {
    @EnvironmentObject private var store: PetStore
    @State private var showEdit = false

    private let accent = PetPalette.passport
    private var pet: Pet { store.currentPet }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    passportCard
                    detailsCard
                    allergiesCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(ScreenBackground(accent: accent))
            .navigationTitle("Passport")
            .settingsToolbar()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { showEdit = true }
                }
            }
            .sheet(isPresented: $showEdit) {
                PetFormView(existing: pet).environmentObject(store)
            }
        }
        .tint(accent)
    }

    private var passportCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("PET PASSPORT", systemImage: "pawprint.fill")
                    .font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.9))
                Spacer()
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.white.opacity(0.9))
            }
            HStack(spacing: 16) {
                Text(pet.emoji)
                    .font(.system(size: 46))
                    .frame(width: 80, height: 80)
                    .background(.white.opacity(0.25), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(pet.name.isEmpty ? "Unnamed" : pet.name)
                        .font(.system(.title, design: .rounded)).bold()
                    Text([pet.species, pet.breed].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.subheadline).opacity(0.92)
                    if !pet.microchip.isEmpty {
                        Text("Chip \(pet.microchip)").font(.caption2.monospaced()).opacity(0.85)
                    }
                }
                Spacer()
            }
            .foregroundStyle(.white)
        }
        .padding(22)
        .background(accent.diagonal, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: accent.opacity(0.4), radius: 16, y: 8)
    }

    private var detailsCard: some View {
        PetCard(accent: accent) {
            VStack(spacing: 0) {
                field("Owner", pet.owner.isEmpty ? "—" : pet.owner, "person.fill")
                Divider().padding(.vertical, 10)
                field("Breed", pet.breed.isEmpty ? "—" : pet.breed, "pawprint.fill")
                Divider().padding(.vertical, 10)
                field("Age", pet.ageDescription, "calendar")
                Divider().padding(.vertical, 10)
                field("Weight", pet.weightKg > 0 ? String(format: "%.1f kg", pet.weightKg) : "—", "scalemass.fill")
                Divider().padding(.vertical, 10)
                field("Microchip", pet.microchip.isEmpty ? "—" : pet.microchip, "number")
            }
        }
    }

    private func field(_ label: String, _ value: String, _ icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.footnote).foregroundStyle(accent).frame(width: 24)
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.body.weight(.medium)).multilineTextAlignment(.trailing)
        }
    }

    private var allergiesCard: some View {
        PetCard(accent: PetPalette.health) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Allergies", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(PetPalette.health)
                if pet.allergies.isEmpty {
                    Text("None recorded").foregroundStyle(.secondary)
                } else {
                    FlowChips(items: pet.allergies, color: PetPalette.health)
                }
            }
        }
    }

}

/// Simple wrapping row of chips.
private struct FlowChips: View {
    let items: [String]
    let color: Color
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { ChipView(text: $0, color: color) }
        }
    }
}

#Preview {
    PetPassportView().environmentObject(PetStore())
}
