import SwiftUI

struct ErrorView: View {
    let errorKind: ErrorKind
    let onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if showsRetry {
                Button {
                    onRetry?()
                } label: {
                    Label("Try Again", systemImage: "arrow.counterclockwise")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Computed Properties

    private var iconName: String {
        switch errorKind {
        case .poorLighting:
            return "light.max"
        case .timeout:
            return "face.dashed"
        case .deviceUnsupported:
            return "iphone.slash"
        case .cameraPermissionDenied:
            return "camera.badge.ellipsis"
        case .sessionFailed:
            return "exclamationmark.triangle"
        }
    }

    private var title: String {
        switch errorKind {
        case .poorLighting:
            return "Poor Lighting"
        case .timeout:
            return "No Expression Detected"
        case .deviceUnsupported:
            return "Device Not Supported"
        case .cameraPermissionDenied:
            return "Camera Access Required"
        case .sessionFailed:
            return "Something Went Wrong"
        }
    }

    private var subtitle: String {
        switch errorKind {
        case .poorLighting:
            return "Try moving to a brighter area"
        case .timeout:
            return "Make a clear facial expression and try again"
        case .deviceUnsupported:
            return "Emojeasy requires iPhone X or later with a TrueDepth camera"
        case .cameraPermissionDenied:
            return "Please open the main Emojeasy app on your home screen to grant camera permissions."
        case .sessionFailed(let message):
            return message
        }
    }

    private var showsRetry: Bool {
        switch errorKind {
        case .deviceUnsupported, .cameraPermissionDenied:
            return false
        default:
            return true
        }
    }
}
