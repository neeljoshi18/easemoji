import SwiftUI

struct MainView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ZStack {
            // Visible background — subtle system material so UI isn't invisible
            Color(.systemBackground)
                .ignoresSafeArea()

            switch appState.phase {
            case .idle:
                DetectingView()
                    .transition(.opacity)

            case .detecting:
                DetectingView()
                    .transition(.opacity)

            case .results(let emojis):
                EmojiResultsView(emojis: emojis, appState: appState)
                    .transition(.opacity)

            case .error(let errorKind):
                ErrorView(errorKind: errorKind, onRetry: { appState.retry() })
                    .transition(.opacity)
            }
            
            // Mode Indicator
            VStack {
                HStack {
                    Spacer()
                    Text(appState.isUsingCustomMLModel ? "MODE: ML" : "MODE: ARKit")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
                Spacer()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.phase)
    }
}
