import SwiftUI

@main
struct EmojeasyApp: App {
    @State private var isCapturing = false
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if isCapturing {
                    CaptureView()
                } else {
                    ContentView()
                }
            }
            .onOpenURL { url in
                if url.host == "capture" {
                    isCapturing = true
                }
            }
        }
    }
}
