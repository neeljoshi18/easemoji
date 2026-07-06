import Foundation
import ARKit

@MainActor
final class DataLogger: NSObject, ObservableObject, ARSessionDelegate {
    @Published var isRunning = false
    @Published var latestBlendShapes: [ARFaceAnchor.BlendShapeLocation: NSNumber] = [:]
    
    private let session = ARSession()
    private var recordedSnapshots: [[String: Any]] = []
    
    override init() {
        super.init()
        session.delegate = self
    }
    
    func start() {
        guard ARFaceTrackingConfiguration.isSupported else { return }
        let config = ARFaceTrackingConfiguration()
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
        isRunning = true
    }
    
    func stop() {
        session.pause()
        isRunning = false
    }
    
    func recordSnapshot(label: String) {
        var snapshot: [String: Any] = ["label": label, "timestamp": Date().timeIntervalSince1970]
        
        for (location, value) in latestBlendShapes {
            snapshot[location.rawValue] = value.floatValue
        }
        
        recordedSnapshots.append(snapshot)
    }
    
    func exportCSV() -> URL? {
        guard !recordedSnapshots.isEmpty else { return nil }
        
        var csvString = "label,timestamp,"
        
        // Get all possible blendshape keys from the first snapshot
        let keys = recordedSnapshots.first!.keys.filter { $0 != "label" && $0 != "timestamp" }.sorted()
        csvString += keys.joined(separator: ",") + "\n"
        
        for snapshot in recordedSnapshots {
            var row = "\(snapshot["label"] as! String),\(snapshot["timestamp"] as! Double),"
            let values = keys.map { String(format: "%.4f", snapshot[$0] as? Float ?? 0.0) }
            row += values.joined(separator: ",") + "\n"
            csvString += row
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("emojeasy_blendshapes_\(Int(Date().timeIntervalSince1970)).csv")
        
        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Failed to write CSV: \(error)")
            return nil
        }
    }
    
    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let faceAnchor = anchors.compactMap({ $0 as? ARFaceAnchor }).first else { return }
        
        Task { @MainActor in
            self.latestBlendShapes = faceAnchor.blendShapes
        }
    }
}
