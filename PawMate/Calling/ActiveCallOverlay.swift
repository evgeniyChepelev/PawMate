import SwiftUI

struct ActiveCallOverlay: View {

    @ObservedObject var session: CallCoordinator

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 12) {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                        )

                    Text(session.callerDisplayName.isEmpty ? "HookUp" : session.callerDisplayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    Text(formattedDuration)
                        .font(.body)
                        .foregroundColor(.gray)
                        .monospacedDigit()
                }

                Spacer()

                Button(action: { session.endActiveCall() }) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 72, height: 72)
                        .overlay(
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        )
                }
                .padding(.bottom, 60)
            }
        }
    }

    private var formattedDuration: String {
        let minutes = session.elapsedSeconds / 60
        let seconds = session.elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
