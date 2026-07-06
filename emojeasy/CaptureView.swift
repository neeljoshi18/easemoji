import SwiftUI
import ARKit

struct CaptureView: View {
    @StateObject private var faceTracker = FaceTracker()
    @Environment(\.openURL) var openURL
    
    var body: some View {
        VStack {
            Spacer()
            
            // The Illusion UI: Mimics a keyboard dictation pane
            VStack {
                HStack {
                    Button(action: {
                        returnToHostApp()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title2)
                    }
                    Spacer()
                    Button(action: {
                        // Manual confirm
                        returnToHostApp()
                    }) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title2)
                    }
                }
                .padding()
                
                Spacer()
                
                if faceTracker.detectedEmoji != nil {
                    Text(faceTracker.detectedEmoji!)
                        .font(.system(size: 80))
                        .transition(.scale)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "face.dashed")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                        Text("Reading Expression...")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                }
                
                Spacer()
                
                // Fake globe icon for added illusion
                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding()
            }
            .frame(height: 250) // Match typical keyboard height
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
        // Instead of a solid black background, we use a clear background with a blur effect.
        // On iOS, apps cannot be fully transparent over other apps, but this minimizes the visual "shock" of the transition.
        .background(Color(UIColor.systemBackground).ignoresSafeArea())
        .colorScheme(.dark) // Force dark mode to match the camera theme
        .onAppear {
            faceTracker.startSession { emoji in
                // Save to shared app group
                if let defaults = UserDefaults(suiteName: "group.com.emojeasy.app") {
                    defaults.set(emoji, forKey: "pendingEmoji")
                    defaults.synchronize()
                }
                
                // Auto switchback
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    returnToHostApp()
                }
            }
        }
        .onDisappear {
            faceTracker.stopSession()
        }
    }
    
    func returnToHostApp() {
        // Simple auto-switchback to Messages
        // In a full product, you'd maintain a list of schemes or rely on the iOS back button.
        if let url = URL(string: "sms://") {
            openURL(url)
        }
    }
}

class FaceTracker: NSObject, ObservableObject, ARSessionDelegate, @unchecked Sendable {
    private var session: ARSession?
    @Published var detectedEmoji: String? = nil
    var onEmojiSelected: ((String) -> Void)?
    private var hasSelected = false
    
    func startSession(completion: @escaping (String) -> Void) {
        self.onEmojiSelected = completion
        self.hasSelected = false
        
        guard ARFaceTrackingConfiguration.isSupported else { return }
        
        session = ARSession()
        session?.delegate = self
        
        let config = ARFaceTrackingConfiguration()
        session?.run(config, options: [.resetTracking, .removeExistingAnchors])
    }
    
    func stopSession() {
        session?.pause()
        session = nil
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard !hasSelected, let faceAnchor = anchors.first as? ARFaceAnchor else { return }
        
        // Simple expression logic: Smile
        let smileLeft = faceAnchor.blendShapes[.mouthSmileLeft]?.floatValue ?? 0
        let smileRight = faceAnchor.blendShapes[.mouthSmileRight]?.floatValue ?? 0
        
        if smileLeft > 0.6 && smileRight > 0.6 {
            hasSelected = true
            DispatchQueue.main.async {
                self.detectedEmoji = "😂"
                self.onEmojiSelected?("😂")
            }
        }
    }
}
