import ARKit

/// Describes what went wrong during face tracking.
enum ErrorKind: Sendable, Equatable {
    case poorLighting
    case timeout
    case deviceUnsupported
    case cameraPermissionDenied
    case sessionFailed(String)
}

/// Lightweight ARSession wrapper that reads blendshape data without any rendering view.
///
/// No ARSCNView or ARView is used — we run ARSession directly and only extract
/// the 52 blendshape Float coefficients from ARFaceAnchor delegate callbacks.
/// This minimizes memory footprint for the iMessage extension sandbox.
@MainActor
final class FaceTrackingManager: NSObject, ARSessionDelegate {

    // MARK: - Callbacks

    /// Called when an expression is confidently detected. Provides 3 emoji candidates.
    var onExpressionDetected: (([String]) -> Void)?

    /// Called when an error prevents detection.
    var onError: ((ErrorKind) -> Void)?

    // MARK: - Tunable Constants

    /// Number of consecutive frames the same expression must be detected
    /// before locking in. At 60fps, 10 frames ≈ 170ms of sustained expression.
    static let requiredConsecutiveFrames = 10

    /// Maximum time (seconds) to wait for a confident expression before timing out.
    static let timeoutSeconds: TimeInterval = 7.0

    /// Duration of continuous poor tracking before reporting a lighting error.
    static let poorTrackingGracePeriod: TimeInterval = 2.0

    // MARK: - Private State

    private let session = ARSession()
    private let classifier = ExpressionClassifier()

    /// The expression currently being tracked for consecutive-frame confirmation.
    private var currentCandidate: ExpressionType?

    /// How many consecutive frames `currentCandidate` has been detected.
    private var consecutiveFrameCount = 0

    /// Whether an expression has been successfully locked in (prevents double-fire).
    private var isResolved = false

    /// Timer that fires on timeout.
    private var timeoutTimer: Timer?

    /// Timestamp when tracking state became `.limited` — used for poor-lighting grace period.
    private var limitedTrackingStart: Date?

    // MARK: - Public API

    /// Starts the face tracking session. Checks device support first.
    func start() {
        guard ARFaceTrackingConfiguration.isSupported else {
            onError?(.deviceUnsupported)
            return
        }

        // Reset state
        currentCandidate = nil
        consecutiveFrameCount = 0
        isResolved = false
        limitedTrackingStart = nil

        let config = ARFaceTrackingConfiguration()
        config.maximumNumberOfTrackedFaces = 1

        // delegateQueue stays nil → callbacks arrive on main queue → safe with @MainActor
        session.delegate = self
        session.run(config)

        // Start timeout timer
        timeoutTimer?.invalidate()
        timeoutTimer = Timer.scheduledTimer(
            withTimeInterval: Self.timeoutSeconds,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleTimeout()
            }
        }
    }

    /// Stops the face tracking session and releases resources.
    func stop() {
        session.pause()
        session.delegate = nil
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        currentCandidate = nil
        consecutiveFrameCount = 0
        isResolved = false
        limitedTrackingStart = nil
        expressionHistory.removeAll()
    }

    // MARK: - ARSessionDelegate

    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        Task { @MainActor [weak self] in
            self?.processAnchors(anchors)
        }
    }

    nonisolated func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        let state = camera.trackingState
        Task { @MainActor [weak self] in
            self?.handleTrackingStateChange(state)
        }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor [weak self] in
            guard let self, !self.isResolved else { return }
            self.isResolved = true
            self.stop()
            self.onError?(.sessionFailed(message))
        }
    }

    // MARK: - Private Logic

    /// History of recent expressions for the rolling window filter.
    private var expressionHistory: [ExpressionType] = []
    
    /// Size of the rolling window.
    static let historyWindowSize = 10
    
    /// Number of times an expression must appear in the window to be confirmed.
    static let requiredModeCount = 7

    /// Processes face anchor updates — classifies expression and tracks history.
    private func processAnchors(_ anchors: [ARAnchor]) {
        guard !isResolved else { return }
        guard let faceAnchor = anchors.first(where: { $0 is ARFaceAnchor }) as? ARFaceAnchor else {
            return
        }

        // Clear poor-lighting tracker since we got a valid face
        limitedTrackingStart = nil

        let expression = classifier.classify(blendShapes: faceAnchor.blendShapes)

        // Maintain rolling window
        expressionHistory.append(expression)
        if expressionHistory.count > Self.historyWindowSize {
            expressionHistory.removeFirst()
        }
        
        // Wait until window is full
        guard expressionHistory.count == Self.historyWindowSize else { return }

        // Find the most frequent expression in the window
        var counts: [ExpressionType: Int] = [:]
        for exp in expressionHistory {
            counts[exp, default: 0] += 1
        }
        
        if let (modeExpression, count) = counts.max(by: { $0.value < $1.value }) {
            if modeExpression != .neutral && count >= Self.requiredModeCount {
                // Confident detection — lock in
                isResolved = true
                let emojis = modeExpression.emojiCandidates
                stop()
                onExpressionDetected?(emojis)
            }
        }
    }

    /// Handles changes in ARCamera tracking state for poor-lighting detection.
    private func handleTrackingStateChange(_ state: ARCamera.TrackingState) {
        guard !isResolved else { return }

        switch state {
        case .limited(let reason) where reason == .insufficientFeatures || reason == .excessiveMotion:
            if limitedTrackingStart == nil {
                limitedTrackingStart = Date()
            } else if let start = limitedTrackingStart,
                      Date().timeIntervalSince(start) >= Self.poorTrackingGracePeriod {
                isResolved = true
                stop()
                onError?(.poorLighting)
            }
        case .normal:
            limitedTrackingStart = nil
        default:
            break
        }
    }

    /// Called when the timeout timer fires without a confident expression.
    private func handleTimeout() {
        guard !isResolved else { return }
        isResolved = true
        stop()
        onError?(.timeout)
    }
}
