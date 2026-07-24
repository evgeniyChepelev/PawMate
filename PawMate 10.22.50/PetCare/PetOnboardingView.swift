import SwiftUI

struct PetOnboardingView: View {
    @State private var page = 0
    @State private var startCreating = false

    private let pages = OnboardingPage.all

    var body: some View {
        if startCreating {
            PetFormView(isOnboarding: true)
        } else {
            intro
        }
    }

    private var intro: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip") { withAnimation { startCreating = true } }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            .padding(.top, 10)

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(pages[index]).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            dots.padding(.bottom, 22)

            Button {
                if page >= pages.count - 1 {
                    withAnimation { startCreating = true }
                } else {
                    withAnimation { page += 1 }
                }
            } label: {
                Text(page >= pages.count - 1 ? "Get Started" : "Next")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(pages[page].color.diagonal, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: pages[page].color.opacity(0.35), radius: 12, y: 6)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
        .background(ScreenBackground(accent: pages[page].color))
        .animation(.easeInOut, value: page)
    }

    private func pageView(_ item: OnboardingPage) -> some View {
        VStack(spacing: 30) {
            Spacer()
            OnboardingIllustration(page: item)
            VStack(spacing: 12) {
                Text(item.title)
                    .font(.system(.largeTitle, design: .rounded)).bold()
                    .multilineTextAlignment(.center)
                Text(item.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 34)
            }
            Spacer()
        }
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index == page ? pages[page].color : Color.secondary.opacity(0.3))
                    .frame(width: index == page ? 22 : 8, height: 8)
                    .animation(.spring, value: page)
            }
        }
    }
}

// MARK: - Illustration

private struct OnboardingIllustration: View {
    let page: OnboardingPage

    var body: some View {
        ZStack {
            Circle().fill(page.color.opacity(0.14)).frame(width: 250, height: 250)
            Circle().fill(page.color.diagonal).frame(width: 156, height: 156)
                .shadow(color: page.color.opacity(0.45), radius: 24, y: 12)
            Image(systemName: page.symbol)
                .font(.system(size: 66))
                .foregroundStyle(.white)
            ForEach(page.accents) { accent in
                Image(systemName: accent.symbol)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(accent.color.diagonal, in: Circle())
                    .shadow(color: accent.color.opacity(0.4), radius: 8, y: 4)
                    .offset(accent.offset)
            }
        }
        .frame(height: 270)
    }
}

// MARK: - Model

private struct FloatAccent: Identifiable {
    let id = UUID()
    let symbol: String
    let color: Color
    let offset: CGSize
}

private struct OnboardingPage: Identifiable {
    let id = UUID()
    let symbol: String
    let color: Color
    let accents: [FloatAccent]
    let title: String
    let subtitle: String

    static let all: [OnboardingPage] = [
        OnboardingPage(
            symbol: "pawprint.fill",
            color: PetPalette.home,
            accents: [
                FloatAccent(symbol: "heart.fill", color: PetPalette.health, offset: CGSize(width: -92, height: -72)),
                FloatAccent(symbol: "sparkles", color: PetPalette.timeline, offset: CGSize(width: 96, height: 64)),
            ],
            title: "Welcome to PawMate",
            subtitle: "Everything your pet needs to stay happy and healthy — all in one friendly place."
        ),
        OnboardingPage(
            symbol: "checklist",
            color: PetPalette.journal,
            accents: [
                FloatAccent(symbol: "bowl.fill", color: PetPalette.home, offset: CGSize(width: -96, height: -58)),
                FloatAccent(symbol: "pills.fill", color: PetPalette.health, offset: CGSize(width: 92, height: 70)),
            ],
            title: "Care, every day",
            subtitle: "Feed, walk, medicate — tick off daily tasks and keep a perfect streak."
        ),
        OnboardingPage(
            symbol: "cross.case.fill",
            color: PetPalette.health,
            accents: [
                FloatAccent(symbol: "syringe.fill", color: PetPalette.passport, offset: CGSize(width: 94, height: -60)),
                FloatAccent(symbol: "scalemass.fill", color: PetPalette.timeline, offset: CGSize(width: -90, height: 68)),
            ],
            title: "Health, tracked",
            subtitle: "Log weight, vaccines and medications. Keep a journal of every good day."
        ),
        OnboardingPage(
            symbol: "person.text.rectangle.fill",
            color: PetPalette.passport,
            accents: [
                FloatAccent(symbol: "phone.fill", color: PetPalette.support, offset: CGSize(width: 92, height: 62)),
                FloatAccent(symbol: "star.fill", color: PetPalette.home, offset: CGSize(width: -92, height: -62)),
            ],
            title: "Passport & support",
            subtitle: "Keep a digital pet passport and reach a specialist whenever you need advice."
        ),
    ]
}

#Preview {
    PetOnboardingView().environmentObject(PetStore())
}
