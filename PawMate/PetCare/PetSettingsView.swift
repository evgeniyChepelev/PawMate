import SwiftUI
import StoreKit

struct PetSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview

    @State private var showBookCall = false
    @State private var showCallback = false

    // TODO: replace with the real privacy policy URL when ready.
    private let privacyURL = URL(string: "https://www.termsfeed.com/live/551eb377-7d7d-41b7-b4a1-53f5044fd7b3")!

    var body: some View {
        NavigationStack {
            List {
                Section("Support") {
                    Button { showBookCall = true } label: {
                        settingsRow(icon: "phone.fill", color: PetPalette.support, title: "Book a Call")
                    }
                }

                Section("About") {
                    Link(destination: privacyURL) {
                        settingsRow(icon: "lock.shield.fill", color: PetPalette.passport,
                                    title: "Privacy Policy", trailing: "arrow.up.right")
                    }
                    Button {
                        requestReview()
                    } label: {
                        settingsRow(icon: "star.fill", color: PetPalette.home, title: "Rate Us")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Book a Call", isPresented: $showBookCall) {
                Button("OK") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showCallback = true }
                }
            } message: {
                Text("You can call our specialist to get advice on preparing documents for your pets.")
            }
            .alert("Thank you!", isPresented: $showCallback) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("We will call you back during the day.")
            }
        }
    }

    private func settingsRow(icon: String, color: Color, title: String, trailing: String? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(color.diagonal, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(title).foregroundStyle(.primary)
            Spacer()
            if let trailing {
                Image(systemName: trailing).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Reusable gear-in-navbar for every tab

private struct SettingsToolbarModifier: ViewModifier {
    @State private var showSettings = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showSettings) { PetSettingsView() }
    }
}

extension View {
    /// Adds a Settings gear button to the leading side of the nav bar.
    func settingsToolbar() -> some View { modifier(SettingsToolbarModifier()) }
}

#Preview {
    PetSettingsView()
}
