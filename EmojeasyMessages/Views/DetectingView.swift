import SwiftUI

struct DetectingView: View {
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(.quaternary)
                    .frame(width: 88, height: 88)
                    .scaleEffect(isPulsing ? 1.2 : 0.8)
                    .opacity(isPulsing ? 0.3 : 0.6)
                    .animation(
                        .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                        value: isPulsing
                    )

                Image(systemName: "face.smiling")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                    .symbolEffect(.pulse, options: .repeating)
            }

            Text("Reading your expression…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            isPulsing = true
        }
    }
}
