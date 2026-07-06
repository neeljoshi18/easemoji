import SwiftUI

struct EmojiResultsView: View {
    let emojis: [String]
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 32) {
            HStack(spacing: 24) {
                ForEach(emojis, id: \.self) { emoji in
                    EmojiButton(emoji: emoji) {
                        appState.insertEmoji(emoji)
                    }
                }
            }

            Button {
                appState.retry()
            } label: {
                Label("Try Again", systemImage: "arrow.counterclockwise")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Emoji Button

private struct EmojiButton: View {
    let emoji: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            action()
        } label: {
            Text(emoji)
                .font(.system(size: 48))
                .frame(width: 72, height: 72)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(ScaleFeedbackButtonStyle())
    }
}

// MARK: - Scale Feedback Button Style

private struct ScaleFeedbackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
