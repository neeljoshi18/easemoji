import UIKit
import SwiftUI
import Messages

/// The bridge between UIKit's MSMessagesAppViewController and our SwiftUI views.
/// Hosts MainView via UIHostingController and manages the ARSession lifecycle
/// through AppState.
@MainActor
class MessagesViewController: MSMessagesAppViewController {

    private let appState = AppState()
    private var hostingController: UIHostingController<MainView>?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        let mainView = MainView(appState: appState)
        let hosting = UIHostingController(rootView: mainView)
        hosting.view.backgroundColor = .clear

        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting.view)

        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        hosting.didMove(toParent: self)
        hostingController = hosting
    }

    // MARK: - Conversation Handling

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        appState.conversation = conversation
        
        // Start capture automatically when the extension opens
        appState.startCapture()
    }

    override func didResignActive(with conversation: MSConversation) {
        super.didResignActive(with: conversation)
        appState.stopCapture()
        appState.phase = .idle
    }

    // MARK: - Presentation Style

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.didTransition(to: presentationStyle)
        // No manual handling needed. We stay in compact mode.
    }
}
