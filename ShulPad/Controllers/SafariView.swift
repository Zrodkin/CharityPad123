import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false
        configuration.barCollapsingEnabled = true
        
        let safariViewController = SFSafariViewController(url: url, configuration: configuration)
        safariViewController.dismissButtonStyle = .close
        safariViewController.delegate = context.coordinator
        
        // Store reference to the safari view controller for dismissal
        context.coordinator.safariViewController = safariViewController
        
        return safariViewController
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // Nothing to update
    }
    
    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(self)
        
        // Add notification observer to handle OAuth callback and close this view
        coordinator.notificationObserver = NotificationCenter.default.addObserver(
            forName: .squareOAuthCallback,  // ← FIXED: Listen for OAuth callback
            object: nil,
            queue: .main
        ) { [weak coordinator] _ in
            print("SafariView received OAuth callback - auto-closing")
            
            if let safariVC = coordinator?.safariViewController {
                safariVC.dismiss(animated: true) {
                    DispatchQueue.main.async {
                        coordinator?.parent.onDismiss()
                    }
                }
            } else {
                DispatchQueue.main.async {
                    coordinator?.parent.onDismiss()
                }
            }
        }
        
        return coordinator
    }
    
    class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let parent: SafariView
        var safariViewController: SFSafariViewController?
        var notificationObserver: NSObjectProtocol?
        
        init(_ parent: SafariView) {
            self.parent = parent
            super.init()
        }
        
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            // User manually closed the safari view
            parent.onDismiss()
        }
        
        // Called when SafariViewController begins to load a URL
        func safariViewController(_ controller: SFSafariViewController, initialLoadDidRedirectTo URL: URL) {
            print("Safari redirected to: \(URL)")
            print("URL scheme: \(URL.scheme ?? "nil")")
            
            // If the URL is our custom scheme, handle it here
            if URL.scheme == "shulpad" {
                print("🎯 Detected shulpad:// scheme - auto-dismissing Safari")
                
                // Extract parameters from the URL
                if let components = URLComponents(url: URL, resolvingAgainstBaseURL: false) {
                    let successItem = components.queryItems?.first(where: { $0.name == "success" })
                    let errorItem = components.queryItems?.first(where: { $0.name == "error" })
                    let merchantIdItem = components.queryItems?.first(where: { $0.name == "merchant_id" })
                    let locationIdItem = components.queryItems?.first(where: { $0.name == "location_id" })
                    let locationNameItem = components.queryItems?.first(where: { $0.name == "location_name" })
                    
                    let success = successItem?.value == "true"
                    let error = errorItem?.value
                    let merchantId = merchantIdItem?.value
                    let locationId = locationIdItem?.value
                    let locationName = locationNameItem?.value
                    
                    print("🎯 Parsed OAuth result:")
                    print("  - Success: \(success)")
                    if let merchantId = merchantId { print("  - Merchant ID: \(merchantId)") }
                    if let locationId = locationId { print("  - Location ID: \(locationId)") }
                    if let locationName = locationName { print("  - Location Name: \(locationName)") }
                    if let error = error { print("  - Error: \(error)") }
                    
                    // Post notification with all parsed data
                    NotificationCenter.default.post(
                        name: .squareOAuthCallback,
                        object: nil,
                        userInfo: [
                            "success": success,
                            "error": error as Any,
                            "merchant_id": merchantId as Any,
                            "location_id": locationId as Any,
                            "location_name": locationName as Any,
                            "url": URL
                        ]
                    )
                    
                    // 🚀 CRITICAL: Auto-dismiss Safari immediately
                    print("🎯 Auto-dismissing Safari after custom scheme redirect")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        controller.dismiss(animated: true) {
                            print("🎯 Safari dismissed successfully")
                            self.parent.onDismiss()
                        }
                    }
                } else {
                    print("❌ Failed to parse URL components")
                    // Still dismiss Safari even if we can't parse the URL
                    controller.dismiss(animated: true) {
                        self.parent.onDismiss()
                    }
                }
            } else {
                print("📍 Not our custom scheme (\(URL.scheme ?? "nil")), continuing...")
            }
        }
        
        deinit {
            // Clean up the notification observer
            if let observer = notificationObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}
