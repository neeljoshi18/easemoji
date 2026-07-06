import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var permissionGranted = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    @State private var showingTrainingMode = false

    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Icon Header
                ZStack {
                    Circle()
                        .fill(permissionGranted ? Color.green.opacity(0.2) : Color.blue.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: permissionGranted ? "checkmark.circle.fill" : "face.dashed")
                        .font(.system(size: 64))
                        .foregroundStyle(permissionGranted ? .green : .blue)
                        .contentTransition(.symbolEffect(.replace))
                        .onLongPressGesture(minimumDuration: 2.0) {
                            showingTrainingMode = true
                        }
                }
                
                // Text Content
                VStack(spacing: 12) {
                    Text(permissionGranted ? "You're all set!" : "Welcome to Emojeasy")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text(permissionGranted 
                         ? "Emojeasy is ready to use. Open any conversation in Messages and tap the Emojeasy icon in the App Drawer to start."
                         : "Emojeasy needs access to your camera to read your facial expressions and suggest the perfect emoji. The camera is only active while the extension is open.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                Spacer()
                
                // Action Button
                if !permissionGranted {
                    Button {
                        requestCameraAccess()
                    } label: {
                        Text("Grant Camera Access")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(16)
                            .padding(.horizontal, 32)
                    }
                } else {
                    Button {
                        // Normally we'd deep link to Messages, but opening an explicit URL is tricky
                        // Just show a nice success state.
                    } label: {
                        Text("Ready to use in Messages")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(16)
                            .padding(.horizontal, 32)
                    }
                    .disabled(true)
                }
                
                Spacer()
                    .frame(height: 20)
                    
                // DEV TOOL: Training Mode Button
                Button {
                    showingTrainingMode = true
                } label: {
                    Text("Open Data Logger (Dev)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .underline()
                }
                .padding(.bottom, 20)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: permissionGranted)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            checkPermissionStatus()
        }
        .sheet(isPresented: $showingTrainingMode) {
            TrainingModeView()
        }
    }
    
    private func checkPermissionStatus() {
        permissionGranted = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }
    
    private func requestCameraAccess() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                self.permissionGranted = granted
            }
        }
    }
}
