import SwiftUI

/// Decoy front-end shown on the `.supported` branch: a full, user-driven pet-care app.
struct PetCareRootView: View {
    @StateObject private var store = PetStore()

    var body: some View {
        Group {
            if store.hasPet {
                TabView {
                    PetHomeView()
                        .tabItem { Label("Home", systemImage: "house.fill") }
                    PetJournalView()
                        .tabItem { Label("Journal", systemImage: "book.closed.fill") }
                    PetHealthView()
                        .tabItem { Label("Health", systemImage: "heart.fill") }
                    PetTimelineView()
                        .tabItem { Label("Timeline", systemImage: "sparkles") }
                    PetPassportView()
                        .tabItem { Label("Passport", systemImage: "person.text.rectangle.fill") }
                }
                .tint(PetPalette.home)
            } else {
                PetOnboardingView()
            }
        }
        .environmentObject(store)
        .animation(.default, value: store.hasPet)
    }
}

#Preview {
    PetCareRootView()
}
