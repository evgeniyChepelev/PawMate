import SwiftUI

struct PetFormView: View {
    @EnvironmentObject private var store: PetStore
    @Environment(\.dismiss) private var dismiss

    var existing: Pet?
    var isOnboarding: Bool = false

    @State private var name = ""
    @State private var species = "Dog"
    @State private var breed = ""
    @State private var emoji = "🐶"
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
    @State private var weight = 0.0
    @State private var owner = ""
    @State private var microchip = ""
    @State private var allergies: [String] = []
    @State private var newAllergy = ""

    private let emojiChoices = ["🐶", "🐱", "🐰", "🐹", "🐦", "🐢", "🐠", "🐴", "🐷", "🐮", "🦎", "🐍"]
    private let speciesChoices = ["Dog", "Cat", "Rabbit", "Bird", "Reptile", "Fish", "Other"]

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Avatar") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(emojiChoices, id: \.self) { choice in
                                Text(choice)
                                    .font(.system(size: 34))
                                    .frame(width: 54, height: 54)
                                    .background(emoji == choice ? PetPalette.home.opacity(0.22) : Color(.tertiarySystemFill),
                                               in: Circle())
                                    .overlay(Circle().strokeBorder(emoji == choice ? PetPalette.home : .clear, lineWidth: 2))
                                    .onTapGesture { emoji = choice }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Basics") {
                    TextField("Name", text: $name)
                    Picker("Species", selection: $species) {
                        ForEach(speciesChoices, id: \.self) { Text($0) }
                    }
                    TextField("Breed", text: $breed)
                    DatePicker("Birth date", selection: $birthDate, in: ...Date(), displayedComponents: .date)
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("0.0", value: $weight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("kg").foregroundStyle(.secondary)
                    }
                }

                Section("Owner & ID") {
                    TextField("Owner name", text: $owner)
                    TextField("Microchip number", text: $microchip)
                }

                Section("Allergies") {
                    ForEach(allergies, id: \.self) { item in
                        HStack {
                            Text(item)
                            Spacer()
                            Button(role: .destructive) {
                                allergies.removeAll { $0 == item }
                            } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    HStack {
                        TextField("Add allergy", text: $newAllergy)
                        Button("Add") { addAllergy() }
                            .disabled(newAllergy.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                if !isOnboarding, existing != nil {
                    Section {
                        Button("Delete Pet", role: .destructive) {
                            store.deleteProfile()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isOnboarding ? "Create Profile" : (existing == nil ? "New Pet" : "Edit Pet"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isOnboarding {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { savePet() }.disabled(!canSave)
                }
            }
            .onAppear(perform: loadExisting)
        }
    }

    private func addAllergy() {
        let trimmed = newAllergy.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        allergies.append(trimmed)
        newAllergy = ""
    }

    private func loadExisting() {
        guard let pet = existing else { return }
        name = pet.name; species = pet.species; breed = pet.breed; emoji = pet.emoji
        birthDate = pet.birthDate; weight = pet.weightKg; owner = pet.owner
        microchip = pet.microchip; allergies = pet.allergies
    }

    private func savePet() {
        var pet = existing ?? Pet.empty
        pet.name = name.trimmingCharacters(in: .whitespaces)
        pet.species = species
        pet.breed = breed
        pet.emoji = emoji
        pet.birthDate = birthDate
        pet.weightKg = weight
        pet.owner = owner
        pet.microchip = microchip
        pet.allergies = allergies
        store.savePet(pet)
        if !isOnboarding { dismiss() }
    }
}

#Preview {
    PetFormView(isOnboarding: true).environmentObject(PetStore())
}
