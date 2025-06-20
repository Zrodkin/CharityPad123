// Services/SquarePaymentCollectionService.swift
import Foundation
import SquareInAppPaymentsSDK

@MainActor
class SquarePaymentCollectionService: NSObject, ObservableObject {
    @Published var isCollectingPayment = false
    @Published var paymentError: String?
    @Published var collectedCardID: String?
    
    private let authService: SquareAuthService
    private var cardEntryViewController: SQIPCardEntryViewController?
    private var cardEntryCompletion: ((String?) -> Void)?
    
    init(authService: SquareAuthService) {
        self.authService = authService
        super.init()
        setupSquareInAppPayments()
    }
    
    // MARK: - Setup
    
    private func setupSquareInAppPayments() {
        // Set Square Application ID (this is all that's needed for v1.6.4)
        SQIPInAppPaymentsSDK.squareApplicationID = SquareConfig.clientID
        print("✅ Square In-App Payments SDK configured successfully")
    }
    
    // MARK: - Public Methods
    
    /// Collect payment method for subscription
    func collectPaymentMethod(presentingViewController: UIViewController) async -> String? {
        guard authService.isAuthenticated else {
            paymentError = "Not authenticated with Square"
            return nil
        }
        
        guard let locationID = authService.locationId else {
            paymentError = "No location ID available"
            return nil
        }
        
        isCollectingPayment = true
        paymentError = nil
        collectedCardID = nil
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                self.showCardEntryForm(
                    presentingViewController: presentingViewController
                ) { cardID in
                    self.isCollectingPayment = false
                    self.collectedCardID = cardID
                    continuation.resume(returning: cardID)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func showCardEntryForm(
        presentingViewController: UIViewController,
        completion: @escaping (String?) -> Void
    ) {
        // Create Square theme for card entry (v1.6.4 compatible)
        let theme = SQIPTheme()
        theme.backgroundColor = UIColor.systemBackground
        theme.foregroundColor = UIColor.label
        theme.keyboardAppearance = .default
        
        // Create card entry view controller
        cardEntryViewController = SQIPCardEntryViewController(theme: theme)
        cardEntryViewController?.collectPostalCode = true
        cardEntryViewController?.delegate = self
        
        // Store completion handler
        self.cardEntryCompletion = completion
        
        // Present the card entry form in navigation controller
        if let cardVC = cardEntryViewController {
            let navigationController = UINavigationController(rootViewController: cardVC)
            navigationController.modalPresentationStyle = .formSheet
            
            // Add navigation bar items
            cardVC.navigationItem.title = "Add Payment Method"
            cardVC.navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .cancel,
                target: self,
                action: #selector(cancelCardEntry)
            )
            
            presentingViewController.present(navigationController, animated: true)
        } else {
            completion(nil)
        }
    }
    
    @objc private func cancelCardEntry() {
        cardEntryViewController?.dismiss(animated: true) {
            self.cardEntryCompletion?(nil)
            self.isCollectingPayment = false
        }
    }
    
    private func processPaymentNonce(_ nonce: String, completionHandler: @escaping (Error?) -> Void) {
        guard let locationID = authService.locationId else {
            let error = NSError(domain: "SquarePaymentError", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "No location ID available"
            ])
            completionHandler(error)
            return
        }
        
        // Send nonce to backend to create card on file
        Task {
            do {
                let cardID = try await createCardOnFile(nonce: nonce, locationID: locationID)
                await MainActor.run {
                    self.collectedCardID = cardID
                    completionHandler(nil) // Success - Square will show success animation
                }
            } catch {
                await MainActor.run {
                    self.paymentError = error.localizedDescription
                    completionHandler(error)
                }
            }
        }
    }
    
    private func createCardOnFile(nonce: String, locationID: String) async throws -> String {
        guard let url = URL(string: "\(SquareConfig.backendBaseURL)/api/payment/create-card-on-file") else {
            throw PaymentError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "nonce": nonce,
            "location_id": locationID,
            "organization_id": authService.organizationId
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PaymentError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            // Try to get error message from response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                throw PaymentError.serverError(errorMessage)
            }
            throw PaymentError.serverError("Server returned status code: \(httpResponse.statusCode)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = json["success"] as? Bool,
              success,
              let cardID = json["card_id"] as? String else {
            throw PaymentError.invalidResponse
        }
        
        print("✅ Successfully created card on file: \(cardID)")
        return cardID
    }
}

// MARK: - Card Entry Delegate

extension SquarePaymentCollectionService: SQIPCardEntryViewControllerDelegate {
    
    func cardEntryViewController(_ cardEntryViewController: SQIPCardEntryViewController, didCompleteWith status: SQIPCardEntryCompletionStatus) {
        print("Card entry completed with status: \(status.rawValue)")
        
        switch status {
        case SQIPCardEntryCompletionStatus(rawValue: 0): // Success
            print("✅ Card entry succeeded")
            // Dismiss and call completion with collected card ID
            cardEntryViewController.dismiss(animated: true) {
                self.cardEntryCompletion?(self.collectedCardID)
                self.isCollectingPayment = false
            }
            
        case SQIPCardEntryCompletionStatus(rawValue: 1): // Canceled
            print("🚫 Card entry canceled")
            cardEntryViewController.dismiss(animated: true) {
                self.cardEntryCompletion?(nil)
                self.isCollectingPayment = false
            }
            
        default: // Failed or other
            print("❌ Card entry failed")
            cardEntryViewController.dismiss(animated: true) {
                self.paymentError = "Card entry failed"
                self.cardEntryCompletion?(nil)
                self.isCollectingPayment = false
            }
        }
    }
    
    func cardEntryViewController(_ cardEntryViewController: SQIPCardEntryViewController, didObtain cardDetails: SQIPCardDetails, completionHandler: @escaping (Error?) -> Void) {
        
        print("🔐 Obtained card nonce: \(cardDetails.nonce)")
        
        // Process the card nonce to create a card on file
        processPaymentNonce(cardDetails.nonce, completionHandler: completionHandler)
    }
}

// MARK: - Error Types

enum PaymentError: Error, LocalizedError {
    case invalidURL
    case serverError(String)
    case invalidResponse
    case cardCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid payment URL"
        case .serverError(let message):
            return "Server error: \(message)"
        case .invalidResponse:
            return "Invalid response from payment server"
        case .cardCreationFailed:
            return "Failed to save payment method"
        }
    }
}
