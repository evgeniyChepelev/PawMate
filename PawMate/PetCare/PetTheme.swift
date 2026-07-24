import SwiftUI

/// Per-section accent palette — every screen gets its own personality.
enum PetPalette {
    static let home     = Color(red: 1.00, green: 0.55, blue: 0.20) // warm orange
    static let journal  = Color(red: 0.16, green: 0.72, blue: 0.52) // fresh green
    static let health   = Color(red: 0.98, green: 0.35, blue: 0.52) // coral pink
    static let timeline = Color(red: 0.53, green: 0.40, blue: 0.94) // violet
    static let passport = Color(red: 0.24, green: 0.52, blue: 0.97) // blue
    static let support  = Color(red: 0.10, green: 0.68, blue: 0.72) // teal
}

extension Color {
    /// Two-stop diagonal gradient built from this color.
    var diagonal: LinearGradient {
        LinearGradient(
            colors: [self, self.opacity(0.72)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Screen background

/// Soft accent wash behind a scrolling screen, theme-aware.
struct ScreenBackground: View {
    let accent: Color
    var body: some View {
        LinearGradient(
            colors: [accent.opacity(0.16), .clear],
            startPoint: .top,
            endPoint: .center
        )
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea()
    }
}

// MARK: - Card container

struct PetCard<Content: View>: View {
    var accent: Color = .clear
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(accent.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }
}

// MARK: - Progress ring

struct RingProgress: View {
    var progress: Double
    var color: Color
    var lineWidth: CGFloat = 12

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(progress, 1)))
                .stroke(color.diagonal, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
            Text("\(Int((progress * 100).rounded()))%")
                .font(.system(.headline, design: .rounded)).bold()
                .foregroundStyle(color)
        }
    }
}

// MARK: - Stat tile

struct StatTile: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(color.diagonal, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(value)
                .font(.system(.title2, design: .rounded)).bold()
                .foregroundStyle(.primary)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

// MARK: - Chip

struct ChipView: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.14), in: Capsule())
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var icon: String? = nil
    var color: Color = .secondary
    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon).foregroundStyle(color)
            }
            Text(title)
                .font(.system(.title3, design: .rounded)).bold()
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Codable color

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self = Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

/// Colors a user can pick for their own tasks (stored as hex strings).
enum TaskPalette {
    static let options: [String] = ["#FF8C33", "#29B885", "#FA5A84", "#8768F0", "#3D85F7", "#1AAEB8"]
}
