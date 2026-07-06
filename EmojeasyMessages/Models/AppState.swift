import SwiftUI
import Messages
import ARKit

/// The phase of the extension UI — drives the entire view tree.
enum AppPhase: Equatable {
    case idle
    case detecting
    case results([String])
    case error(ErrorKind)
}

/// Central state machine for the Emojeasy iMessage extension.
///
/// Observed by SwiftUI views via @ObservedObject. Manages the face tracking
/// lifecycle and provides actions for emoji insertion and retry.
@MainActor
final class AppState: ObservableObject {

    /// Current UI phase — observed by MainView to switch between child views.
    @Published var phase: AppPhase = .idle
    
    /// Toggle between ARKit Face Tracking and the Custom ML Model (Path 1)
    @Published var isUsingCustomMLModel: Bool = false

    /// The active Messages conversation, set by MessagesViewController.
    /// Used to insert emoji into the compose text field.
    weak var conversation: MSConversation?

    /// The face tracking manager — created on each capture session.
    private var faceTracker: FaceTrackingManager?

    /// Starts a new face tracking capture session.
    /// Should be called when the extension becomes active.
    func startCapture() {
        guard ARFaceTrackingConfiguration.isSupported else {
            phase = .error(.deviceUnsupported)
            return
        }

        // Check if we are already detecting to avoid redundant starts
        if phase == .detecting { return }

        // Determine if we have authorization
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        if status == .authorized {
            self.beginTracking()
        } else if status == .notDetermined {
            // Unlikely to hit this in an extension, but handle just in case
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    guard let self = self else { return }
                    if granted {
                        self.beginTracking()
                    } else {
                        self.phase = .error(.cameraPermissionDenied)
                    }
                }
            }
        } else {
            self.phase = .error(.cameraPermissionDenied)
        }
    }

    private func beginTracking() {
        phase = .detecting

        let tracker = FaceTrackingManager()

        tracker.onExpressionDetected = { [weak self] emojis in
            self?.phase = .results(emojis)
        }

        tracker.onError = { [weak self] errorKind in
            self?.phase = .error(errorKind)
        }

        faceTracker = tracker
        tracker.start()
    }

    /// Stops the current capture session and releases the tracker.
    func stopCapture() {
        faceTracker?.stop()
        faceTracker = nil
    }

    /// Stops the current session and immediately starts a new one.
    func retry() {
        stopCapture()
        startCapture()
    }

    /// Inserts an emoji into the Messages compose text field.
    /// The emoji is appended next to any existing text — never auto-sent.
    func insertEmoji(_ emoji: String) {
        Task {
            do {
                try await conversation?.insertText(emoji)
            } catch {
                print("Failed to insert emoji: \(error)")
            }
        }
    }
}
