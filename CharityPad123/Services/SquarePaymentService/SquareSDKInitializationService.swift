import Foundation
import SquareMobilePaymentsSDK

/// Service responsible for Square SDK initialization and authorization
class SquareSDKInitializationService: NSObject, AuthorizationStateObserver {
    // MARK: - Private Properties
    
    private weak var authService: SquareAuthService?
    private weak var paymentService: SquarePaymentService?
    private var isInitialized = false
    
    // MARK: - Public Methods
    
    /// Configure the service with necessary dependencies
    func configure(with authService: SquareAuthService, paymentService: SquarePaymentService) {
        self.authService = authService
        self.paymentService = paymentService
    }
    
    /// Check if the Square SDK is initialized and ready to use
    func checkIfInitialized() -> Bool {
        if !isInitialized {
            // Mark as initialized
            isInitialized = true
            
            // Register as authorization observer
            MobilePaymentsSDK.shared.authorizationManager.add(self)
            
            print("Square SDK initialized and available")
        }
        
        return true
    }
    
    /// Debug function to print SDK information
    func debugSquareSDK() {
        // Don't proceed if not initialized
        guard checkIfInitialized() else {
            print("Cannot debug Square SDK - not yet initialized")
            return
        }
        
        print("\n--- Square SDK Debug Information ---")
        
        // SDK version and environment
        print("SDK Version: \(String(describing: MobilePaymentsSDK.version))")
        print("SDK Environment: \(MobilePaymentsSDK.shared.settingsManager.sdkSettings.environment)")
        
        // Authorization state
        print("Authorization State: \(MobilePaymentsSDK.shared.authorizationManager.state)")
        
        // FIXED: Check current location info from SDK
        if let currentLocation = MobilePaymentsSDK.shared.authorizationManager.location {
            print("Current Location ID: \(currentLocation.id)")
            print("Current Location Name: \(currentLocation.name)")
        } else {
            print("No current location set in SDK")
        }
        
        // Prompt parameters exploration
        print("\n--- Prompt Parameters ---")
        let promptParams = PromptParameters(mode: .default, additionalMethods: .all)
        print("Successfully created PromptParameters")
        print("- mode: \(promptParams.mode)")
        print("- additionalMethods: \(promptParams.additionalMethods)")
        
        // Payment parameters with correct Money class
        print("\n--- Payment Parameters ---")
        let moneyAmount = Money(amount: 100, currency: .USD)
        let paymentParams = PaymentParameters(
            idempotencyKey: UUID().uuidString,
            amountMoney: moneyAmount,
            processingMode: .onlineOnly
        )
        print("Successfully created PaymentParameters")
        print("- idempotencyKey: \(paymentParams.idempotencyKey)")
        print("- amountMoney: \(paymentParams.amountMoney.amount) \(paymentParams.amountMoney.currency)")
        print("- processingMode: \(paymentParams.processingMode)")
        
        print("\n--- Debug Complete ---")
    }
    
    /// Initialize the Square Mobile Payments SDK
    func initializeSDK(onSuccess: @escaping () -> Void = {}) {
        // Check if SDK is available first
        guard checkIfInitialized() else {
            updateConnectionStatus("SDK not initialized")
            return
        }
        
        // ADD DETAILED DEBUGGING
        print("🔍 DEBUG: Starting SDK initialization")
        print("🔍 AuthService available: \(authService != nil)")
        print("🔍 Access token available: \(authService?.accessToken != nil)")
        print("🔍 Location ID: \(authService?.locationId ?? "NIL")")
        print("🔍 Merchant ID: \(authService?.merchantId ?? "NIL")")
        
        // Get credentials from auth service
        guard let authService = authService,
              let accessToken = authService.accessToken else {
            updatePaymentError("No access token available")
            updateConnectionStatus("Missing access token")
            print("❌ CRITICAL: No access token available")
            return
        }
        
        // CRITICAL FIX: Don't fallback to merchant ID - require proper location ID
        guard let locationID = authService.locationId else {
            print("❌ CRITICAL: No location ID available for SDK authorization")
            print("❌ This is required for reader connectivity")
            print("❌ User needs to select a location during OAuth flow")
            updatePaymentError("No location selected - please reconnect to Square and select a location")
            updateConnectionStatus("Location required")
            return
        }
        
        print("✅ Using Location ID for SDK: \(locationID)")
        
        // Check if already authorized with the SAME location
        if MobilePaymentsSDK.shared.authorizationManager.state == .authorized {
            // Verify we're authorized with the correct location
            if let currentLocation = MobilePaymentsSDK.shared.authorizationManager.location,
               currentLocation.id == locationID {
                print("✅ Square SDK already authorized with correct location: \(locationID)")
                updateConnectionStatus("SDK authorized")
                onSuccess()
                return
            } else {
                let currentLocationId = MobilePaymentsSDK.shared.authorizationManager.location?.id ?? "unknown"
                print("⚠️ SDK authorized but with different location: \(currentLocationId) vs \(locationID)")
                print("🔄 Re-authorizing with correct location...")
                
                // Deauthorize first, then re-authorize with correct location
                MobilePaymentsSDK.shared.authorizationManager.deauthorize {
                    DispatchQueue.main.async {
                        self.performAuthorization(accessToken: accessToken, locationID: locationID, onSuccess: onSuccess)
                    }
                }
                return
            }
        }
        
        // Perform the authorization
        performAuthorization(accessToken: accessToken, locationID: locationID, onSuccess: onSuccess)
    }

    // Enhanced helper method for cleaner authorization
    private func performAuthorization(accessToken: String, locationID: String, onSuccess: @escaping () -> Void) {
        print("🚀 Authorizing Square SDK with location ID: \(locationID)")
        
        // FIXED: Use correct method signature from Square documentation
        MobilePaymentsSDK.shared.authorizationManager.authorize(
            withAccessToken: accessToken,
            locationID: locationID
        ) { [weak self] error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let authError = error {
                    let errorMessage = "SDK Authorization failed: \(authError.localizedDescription)"
                    print("❌ \(errorMessage)")
                    self.updatePaymentError(errorMessage)
                    self.updateConnectionStatus("Authorization failed")
                    
                    // Check if this is a location-related error
                    if authError.localizedDescription.contains("location") ||
                       authError.localizedDescription.contains("Location") {
                        self.updatePaymentError("Invalid location selected - please reconnect to Square")
                        print("❌ Location-specific error detected")
                    }
                    return
                }
                
                // Success!
                let currentLocation = MobilePaymentsSDK.shared.authorizationManager.location
                print("✅ Square Mobile Payments SDK successfully authorized")
                print("✅ Location ID: \(currentLocation?.id ?? "Unknown")")
                print("✅ Location Name: \(currentLocation?.name ?? "Unknown")")
                
                self.updateConnectionStatus("SDK authorized")
                self.updatePaymentError(nil) // Clear any previous errors
                onSuccess()
            }
        }
    }
    
    /// Check if the Square SDK is authorized
    func isSDKAuthorized() -> Bool {
        guard checkIfInitialized() else { return false }
        return MobilePaymentsSDK.shared.authorizationManager.state == .authorized
    }
    
    /// Deauthorize the Square SDK
    func deauthorizeSDK(completion: @escaping () -> Void = {}) {
        guard checkIfInitialized() else {
            completion()
            return
        }
        
        MobilePaymentsSDK.shared.authorizationManager.deauthorize {
            DispatchQueue.main.async { [weak self] in
                self?.updateConnectionStatus("Disconnected")
                
                // Update reader connected state
                if let paymentService = self?.paymentService {
                    paymentService.isReaderConnected = false
                }
                
                completion()
            }
        }
    }
    
    /// Get the currently available card input methods
    func availableCardInputMethods() -> CardInputMethods {
        guard checkIfInitialized() else { return CardInputMethods() }
        return MobilePaymentsSDK.shared.paymentManager.availableCardInputMethods
    }
    
    // MARK: - AuthorizationStateObserver
    
    func authorizationStateDidChange(_ authorizationState: AuthorizationState) {
        DispatchQueue.main.async { [weak self] in
            print("🔄 Authorization state changed to: \(authorizationState)")
            
            if authorizationState == .authorized {
                print("✅ SDK is now authorized")
                self?.updateConnectionStatus("SDK authorized")
                self?.paymentService?.connectToReader()
            } else {
                print("❌ SDK is not authorized")
                self?.updateConnectionStatus("Not authorized")
                
                // Update reader connected state
                if let paymentService = self?.paymentService {
                    paymentService.isReaderConnected = false
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// FIXED: Update the connection status in the payment service (handle nil case)
    private func updateConnectionStatus(_ status: String) {
        DispatchQueue.main.async { [weak self] in
            self?.paymentService?.connectionStatus = status
        }
    }
    
    /// FIXED: Update payment error in the payment service (handle nil case)
    private func updatePaymentError(_ error: String?) {
        DispatchQueue.main.async { [weak self] in
            self?.paymentService?.paymentError = error
        }
    }
}
