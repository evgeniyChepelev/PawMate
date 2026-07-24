import Foundation
import SwiftUI
import Combine

// MARK: - Models (all Codable & user-editable)

struct Pet: Codable, Identifiable {
    var id = UUID()
    var name: String
    var species: String
    var breed: String
    var emoji: String
    var birthDate: Date
    var weightKg: Double
    var owner: String
    var microchip: String
    var allergies: [String]

    var ageDescription: String {
        let years = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
        return years <= 0 ? "< 1 yr" : "\(years) yr"
    }

    static let empty = Pet(name: "", species: "Dog", breed: "", emoji: "🐾",
                           birthDate: Date(), weightKg: 0, owner: "", microchip: "", allergies: [])
}

struct CareTask: Codable, Identifiable {
    var id = UUID()
    var title: String
    var icon: String
    var colorHex: String
    var done: Bool

    var color: Color { Color(hex: colorHex) }

    static var starter: [CareTask] {
        [
            CareTask(title: "Feed", icon: "bowl.fill", colorHex: "#FF8C33", done: false),
            CareTask(title: "Walk", icon: "figure.walk", colorHex: "#29B885", done: false),
            CareTask(title: "Medication", icon: "pills.fill", colorHex: "#FA5A84", done: false),
        ]
    }
}

struct JournalDay: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var ate: Bool
    var walked: Bool
    var meds: Bool
    var stool: Bool
    var sleepHours: Double
    var note: String
}

struct VaccineRecord: Codable, Identifiable {
    var id = UUID()
    var name: String
    var date: Date
}

struct Medication: Codable, Identifiable {
    var id = UUID()
    var name: String
    var schedule: String
    var active: Bool
}

enum TimelineKind: String, Codable, CaseIterable, Identifiable {
    case photo, weight, vaccine, food, grooming, note
    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .photo: "camera.fill"
        case .weight: "scalemass.fill"
        case .vaccine: "syringe.fill"
        case .food: "fork.knife"
        case .grooming: "scissors"
        case .note: "text.bubble.fill"
        }
    }

    var color: Color {
        switch self {
        case .photo: PetPalette.timeline
        case .weight: PetPalette.health
        case .vaccine: PetPalette.passport
        case .food: PetPalette.home
        case .grooming: PetPalette.support
        case .note: .gray
        }
    }
}

struct TimelineEvent: Codable, Identifiable {
    var id = UUID()
    var kind: TimelineKind
    var title: String
    var subtitle: String
    var date: Date
}

// MARK: - Store (persists everything the user enters)

final class PetStore: ObservableObject {
    @Published private(set) var pet: Pet?
    @Published private(set) var tasks: [CareTask] = []
    @Published private(set) var journal: [JournalDay] = []
    @Published private(set) var vaccines: [VaccineRecord] = []
    @Published private(set) var medications: [Medication] = []
    @Published private(set) var timeline: [TimelineEvent] = []

    private let storageKey = "pawmate.petcare.v1"

    init() { load() }

    // MARK: Persistence

    private struct Snapshot: Codable {
        var pet: Pet?
        var tasks: [CareTask]
        var journal: [JournalDay]
        var vaccines: [VaccineRecord]
        var medications: [Medication]
        var timeline: [TimelineEvent]
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        pet = snap.pet
        tasks = snap.tasks
        journal = snap.journal
        vaccines = snap.vaccines
        medications = snap.medications
        timeline = snap.timeline
    }

    private func save() {
        let snap = Snapshot(pet: pet, tasks: tasks, journal: journal,
                            vaccines: vaccines, medications: medications, timeline: timeline)
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    var hasPet: Bool { pet != nil }
    var currentPet: Pet { pet ?? .empty }

    // MARK: Pet profile

    func savePet(_ newPet: Pet) {
        let isFirst = (pet == nil)
        pet = newPet
        if isFirst && tasks.isEmpty { tasks = CareTask.starter }
        save()
    }

    func updateWeight(_ kg: Double) {
        guard var p = pet else { return }
        p.weightKg = kg
        pet = p
        save()
    }

    func deleteProfile() {
        pet = nil; tasks = []; journal = []
        vaccines = []; medications = []; timeline = []
        save()
    }

    // MARK: Tasks

    var completedToday: Int { tasks.filter(\.done).count }
    var todayCompletion: Double { tasks.isEmpty ? 0 : Double(completedToday) / Double(tasks.count) }

    func addTask(_ task: CareTask) { tasks.append(task); save() }
    func toggle(_ task: CareTask) {
        guard let i = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[i].done.toggle(); save()
    }
    func deleteTasks(at offsets: IndexSet) { tasks.remove(atOffsets: offsets); save() }
    func deleteTask(_ task: CareTask) { tasks.removeAll { $0.id == task.id }; save() }

    // MARK: Journal

    @discardableResult
    func ensureToday() -> JournalDay {
        let today = Calendar.current.startOfDay(for: Date())
        if let existing = journal.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            return existing
        }
        let day = JournalDay(date: today, ate: false, walked: false, meds: false,
                             stool: false, sleepHours: 12, note: "")
        journal.insert(day, at: 0)
        save()
        return day
    }

    var sortedJournal: [JournalDay] { journal.sorted { $0.date > $1.date } }

    func binding(for day: JournalDay) -> Binding<JournalDay> {
        Binding(
            get: { self.journal.first { $0.id == day.id } ?? day },
            set: { updated in
                if let i = self.journal.firstIndex(where: { $0.id == day.id }) {
                    self.journal[i] = updated
                    self.save()
                }
            }
        )
    }

    // MARK: Vaccines

    func addVaccine(_ vaccine: VaccineRecord) { vaccines.append(vaccine); save() }
    func deleteVaccine(_ vaccine: VaccineRecord) { vaccines.removeAll { $0.id == vaccine.id }; save() }

    var nextVaccine: VaccineRecord? {
        vaccines.filter { $0.date >= Calendar.current.startOfDay(for: Date()) }
                .sorted { $0.date < $1.date }.first
    }
    var lastVaccine: VaccineRecord? {
        vaccines.filter { $0.date < Calendar.current.startOfDay(for: Date()) }
                .sorted { $0.date > $1.date }.first
    }
    var daysUntilNextVaccine: Int? {
        guard let next = nextVaccine else { return nil }
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: next.date)).day
    }

    // MARK: Medications

    func addMedication(_ med: Medication) { medications.append(med); save() }
    func toggleMedication(_ med: Medication) {
        guard let i = medications.firstIndex(where: { $0.id == med.id }) else { return }
        medications[i].active.toggle(); save()
    }
    func deleteMedication(_ med: Medication) { medications.removeAll { $0.id == med.id }; save() }
    var activeMedications: [Medication] { medications.filter(\.active) }

    // MARK: Timeline

    func addEvent(_ event: TimelineEvent) { timeline.insert(event, at: 0); save() }
    func deleteEvent(_ event: TimelineEvent) { timeline.removeAll { $0.id == event.id }; save() }
    var sortedTimeline: [TimelineEvent] { timeline.sorted { $0.date > $1.date } }
}
