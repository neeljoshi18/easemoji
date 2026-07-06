import SwiftUI

struct TrainingModeView: View {
    @StateObject private var logger = DataLogger()
    @State private var selectedExpression = "smirk"
    @State private var snapshotCount = 0
    @State private var shareURL: URL?
    
    let expressions = ["smirk", "eyeRoll", "disgust", "fear", "tongueOut", "kiss", "wink"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if logger.isRunning {
                    HStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                            .opacity(snapshotCount % 2 == 0 ? 1 : 0.5)
                        Text("AR Tracking Active")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top)
                    
                    Picker("Expression", selection: $selectedExpression) {
                        ForEach(expressions, id: \.self) { expr in
                            Text(expr).tag(expr)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 150)
                    
                    Button {
                        logger.recordSnapshot(label: selectedExpression)
                        snapshotCount += 1
                    } label: {
                        Text("Record Snapshot")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    Text("Recorded: \(snapshotCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    ScrollView {
                        VStack(alignment: .leading) {
                            Text("Top Blendshapes")
                                .font(.headline)
                                .padding(.bottom, 4)
                            
                            let sorted = logger.latestBlendShapes.sorted { $0.value.floatValue > $1.value.floatValue }.prefix(10)
                            ForEach(sorted, id: \.key.rawValue) { key, value in
                                HStack {
                                    Text(key.rawValue)
                                        .font(.caption)
                                    Spacer()
                                    Text(String(format: "%.3f", value.floatValue))
                                        .font(.caption.monospacedDigit())
                                }
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding()
                    }
                } else {
                    ContentUnavailableView(
                        "Training Mode",
                        systemImage: "face.dashed",
                        description: Text("Tap Start to begin AR tracking.")
                    )
                }
            }
            .navigationTitle("Data Logger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(logger.isRunning ? "Stop" : "Start") {
                        if logger.isRunning {
                            logger.stop()
                        } else {
                            logger.start()
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if let url = logger.exportCSV() {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onDisappear {
            logger.stop()
        }
    }
}
