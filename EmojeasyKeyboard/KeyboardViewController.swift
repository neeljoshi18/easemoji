import UIKit
import SwiftUI

class KeyboardViewController: UIInputViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let hostingController = UIHostingController(rootView: KeyboardView(
            insertText: { [weak self] text in
                self?.textDocumentProxy.insertText(text)
            }
        ))
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear
        
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Listen for returned emoji from the main app
        NotificationCenter.default.addObserver(self, selector: #selector(checkSharedStorage), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkSharedStorage()
    }
    
    @objc func checkSharedStorage() {
        // We use UserDefaults with a suite name to share data between the main app and keyboard
        if let defaults = UserDefaults(suiteName: "group.com.emojeasy.app") {
            if let pendingEmoji = defaults.string(forKey: "pendingEmoji") {
                self.textDocumentProxy.insertText(pendingEmoji)
                defaults.removeObject(forKey: "pendingEmoji")
                defaults.synchronize()
            }
        }
    }
}

struct KeyboardView: View {
    var insertText: (String) -> Void
    
    var body: some View {
        VStack {
            // Using a SwiftUI Link to bypass iOS 18 programmatic openURL restrictions
            if let captureURL = URL(string: "emojeasy://capture") {
                Link(destination: captureURL) {
                    HStack {
                        Image(systemName: "face.smiling")
                        Text("Smile to React")
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .padding()
            } else {
                Text("Invalid URL")
            }
        }
        .frame(height: 250)
        .background(Color(UIColor.systemGray6))
    }
}
