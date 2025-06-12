import Foundation
import SwiftUI

class SquareAuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isAuthenticating = false
    @Published var authError: String? = nil
    
    // NEW: Add token validation status separate from reader connectivity
    @Published var tokenStatus: TokenValidationStatus = .unknown
    @Published var lastTokenCheck: Date? = nil
    
    enum TokenValidationStatus {
        case unknown
        case validLocal      // Tokens exist locally and haven't expired
        case validRemote     // Tokens validated with Square API
        case expired         // Tokens exist but expired
        case invalid         // Tokens don't work with Square API
        case networkError    // Can't reach server to validate
    }
    
    // Store tokens in UserDefaults (in a real app, use Keychain for better security)
    private let accessTokenKey = "squareAccessToken"
    private let refreshTokenKey = "squareRefreshToken"
    private let merchantIdKey = "squareMerchantId"
    private let locationIdKey = "squareLocationId"
    private let expirationDateKey = "squareTokenExpirationDate"
    private let pendingAuthStateKey = "squarePendingAuthState"
    private let organizationIdKey = "organizationId"
    
    // MARK: - Device ID Support
       private let deviceIdKey = "squareDeviceId"
       
       /// Unique device identifier for multi-device support
    private var deviceId: String {
        // Check if we already have a stored device ID
        if let stored = UserDefaults.standard.string(forKey: deviceIdKey) {
            return stored
        }
        
        // Generate shorter device ID to avoid overly long organization IDs
        let fullDeviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let shortDeviceId = String(fullDeviceId.prefix(8)) // Use only first 8 characters
        
        // Store it for future use
        UserDefaults.standard.set(shortDeviceId, forKey: deviceIdKey)
        print("🆔 Generated new short device ID: \(shortDeviceId)")
        
        return shortDeviceId
    }
    
    var accessToken: String? {
        get { UserDefaults.standard.string(forKey: accessTokenKey) }
        set { UserDefaults.standard.set(newValue, forKey: accessTokenKey) }
    }
    
    var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: refreshTokenKey) }
        set { UserDefaults.standard.set(newValue, forKey: refreshTokenKey) }
    }
    
    var merchantId: String? {
        get { UserDefaults.standard.string(forKey: merchantIdKey) }
        set { UserDefaults.standard.set(newValue, forKey: merchantIdKey) }
    }
    
    var locationId: String? {
        get { UserDefaults.standard.string(forKey: locationIdKey) }
        set { UserDefaults.standard.set(newValue, forKey: locationIdKey) }
    }
    
    var tokenExpirationDate: Date? {
        get { UserDefaults.standard.object(forKey: expirationDateKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: expirationDateKey) }
    }
    
    var pendingAuthState: String? {
        get { UserDefaults.standard.string(forKey: pendingAuthStateKey) }
        set {
            print("Setting pendingAuthState to: \(newValue ?? "nil")")
            UserDefaults.standard.set(newValue, forKey: pendingAuthStateKey)
        }
    }
    
    var organizationId: String {
        get {
            let baseOrgId = UserDefaults.standard.string(forKey: organizationIdKey) ?? SquareConfig.organizationId
            
            // SAFE APPROACH: Only add device suffix if we detect multi-device usage
            // This prevents breaking existing single-device setups
            if shouldUseDeviceSpecificId() {
                return "\(baseOrgId)_\(deviceId)"
            } else {
                return baseOrgId
            }
        }
        set {
            // Store only the base organization ID (without device suffix)
            let baseOrgId = newValue.components(separatedBy: "_").first ?? newValue
            UserDefaults.standard.set(baseOrgId, forKey: organizationIdKey)
        }
    }
       
       /// Get the base organization ID without device suffix
       var baseOrganizationId: String {
           return UserDefaults.standard.string(forKey: organizationIdKey) ?? SquareConfig.organizationId
       }

    // NEW: Add reference to payment service for health checks
    private weak var paymentService: SquarePaymentService?

    /// Set payment service reference for health checks
    func setPaymentService(_ service: SquarePaymentService) {
        self.paymentService = service
    }

    /// Check if we're FULLY authenticated (tokens + SDK + location + ready for payments)
    func isFullyAuthenticated() -> Bool {
        print("🔍 Checking full authentication status...")
        
        // Must have basic auth
        guard isAuthenticated else {
            print("❌ Not basically authenticated")
            return false
        }
        
        // Must have all required data
        guard let _ = accessToken,
              let _ = locationId,
              let _ = merchantId else {
            print("❌ Missing required auth data (token/location/merchant)")
            return false
        }
        
        // Must have SDK properly initialized
        guard let paymentService = self.paymentService,
              paymentService.isSDKAuthorized() else {
            print("❌ SDK not properly authorized")
            return false
        }
        
        print("✅ Fully authenticated and ready")
        return true
    }

    /// Force complete logout and return to onboarding
    func forceCompleteLogout() {
        print("🚨 Forcing complete logout due to incomplete authentication")
        
        // Clear all local data
        clearLocalAuthData()
        
        // Force return to onboarding
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        
        // Post notification to refresh UI
        NotificationCenter.default.post(name: Notification.Name("ForceReturnToOnboarding"), object: nil)
    }
    
    init() {
        // Check if we have a valid token
        checkAuthentication()
    }
    
    // MARK: - Authentication Methods
    
    func checkAuthentication() {
        // First check if we can use locally stored tokens
        if let _ = accessToken,
           let expirationDate = tokenExpirationDate,
           expirationDate > Date() {
            print("Found valid local token, checking with server...")
        } else {
            print("No valid local token found")
        }
        
        // Always verify with the server, regardless of local token presence
        guard let url = URL(string: "\(SquareConfig.backendBaseURL)\(SquareConfig.statusEndpoint)?organization_id=\(organizationId)&device_id=\(deviceId)") else {
            print("Invalid status URL")
            isAuthenticated = false
            return
        }
        
        print("Checking authentication status with server: \(url)")
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    print("Error checking authentication: \(error)")
                    self.isAuthenticated = false
                    return
                }
                
                // Print HTTP status code for debugging
                if let httpResponse = response as? HTTPURLResponse {
                    print("Status code: \(httpResponse.statusCode)")
                }
                
                guard let data = data else {
                    print("No data received")
                    self.isAuthenticated = false
                    return
                }
                
                // Print raw response for debugging
                let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                print("Authentication status response: \(responseString)")
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let connected = json["connected"] as? Bool {
                            self.isAuthenticated = connected
                            print("Authentication status check: isAuthenticated = \(connected)")
                            
                            // If we're connected, update the merchant ID and location ID if available
                            if connected {
                                if let merchantId = json["merchant_id"] as? String {
                                    self.merchantId = merchantId
                                    print("Updated merchant ID: \(merchantId)")
                                }
                                
                                // Get and store location ID
                                if let locationId = json["location_id"] as? String {
                                    self.locationId = locationId
                                    print("Updated location ID: \(locationId)")
                                }
                                
                                // If expires_at is available, update that too
                                if let expiresAt = json["expires_at"] as? String {
                                    let dateFormatter = ISO8601DateFormatter()
                                    if let expirationDate = dateFormatter.date(from: expiresAt) {
                                        self.tokenExpirationDate = expirationDate
                                        print("Updated token expiration: \(expirationDate)")
                                    }
                                }
                            }
                            
                            // If token needs refresh, trigger refresh
                            if let needsRefresh = json["needs_refresh"] as? Bool, needsRefresh {
                                print("Token needs refresh, triggering refresh flow")
                                self.refreshAccessToken()
                            }
                        } else {
                            self.isAuthenticated = false
                            print("Not connected according to server response")
                        }
                    } else {
                        self.isAuthenticated = false
                        print("Failed to parse server response as JSON")
                    }
                } catch {
                    print("Error parsing authentication response: \(error)")
                    self.isAuthenticated = false
                }
            }
        }.resume()
    }
    
    // MARK: - OAuth Flow Methods
    
    func startOAuthFlow() {
        isAuthenticating = true
        authError = nil
        
        print("Starting OAuth flow")
        
        SquareConfig.generateOAuthURL { [weak self] url, error, state in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    print("Failed to generate authorization URL: \(error.localizedDescription)")
                    self.authError = "Failed to generate authorization URL: \(error.localizedDescription)"
                    self.isAuthenticating = false
                    return
                }
                
                guard let url = url else {
                    self.authError = "Failed to generate authorization URL: No URL returned"
                    self.isAuthenticating = false
                    return
                }
                
                // Set the state directly if we received it
                if let state = state {
                    self.pendingAuthState = state
                    print("Starting OAuth flow with state: \(state)")
                } else {
                    print("WARNING: No state received from generateOAuthURL")
                }
                
                print("Starting OAuth flow with URL: \(url)")
                self.openAuthURL(url)
                
                // Start polling after opening the URL only if we have a state
                if self.pendingAuthState != nil {
                    self.startPollingForAuthStatus()
                } else {
                    print("ERROR: Cannot start polling without pendingAuthState")
                    self.authError = "Authorization failed: No state parameter"
                    self.isAuthenticating = false
                }
            }
        }
    }
    
    func checkPendingAuthorization(completion: @escaping (Bool) -> Void) {
        guard isAuthenticating, !isAuthenticated, let state = pendingAuthState else {
            completion(isAuthenticated)
            return
        }
        
        // Check with our backend if the authorization has been completed
        guard let backendURL = URL(string: "\(SquareConfig.backendBaseURL)\(SquareConfig.statusEndpoint)?state=\(state)&device_id=\(deviceId)") else {
            authError = "Invalid backend URL"
            isAuthenticating = false
            completion(false)
            return
        }
        
        print("Checking authorization status with backend: \(backendURL)")
        
        var request = URLRequest(url: backendURL)
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    print("Network error checking auth status: \(error)")
                    completion(false)
                    return
                }
                
                // Print HTTP status code for debugging
                if let httpResponse = response as? HTTPURLResponse {
                    print("Backend status code: \(httpResponse.statusCode)")
                }
                
                guard let data = data else {
                    print("No data received from backend")
                    completion(false)
                    return
                }
                
                // Print raw response for debugging
                let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                print("Backend response: \(responseString)")
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        // Check if we have a valid token
                        if let isConnected = json["connected"] as? Bool, isConnected,
                           let accessToken = json["access_token"] as? String,
                           let refreshToken = json["refresh_token"] as? String,
                           let merchantId = json["merchant_id"] as? String,
                           let locationId = json["location_id"] as? String,  // CRITICAL: Get location_id
                           let expiresAt = json["expires_at"] as? String {
                            
                            // Store tokens
                            self.accessToken = accessToken
                            self.refreshToken = refreshToken
                            self.merchantId = merchantId
                            self.locationId = locationId  // CRITICAL: Store location ID
                            
                            print("✅ CRITICAL: Stored location ID: \(locationId)")
                            
                            // Parse expiration date
                            let dateFormatter = ISO8601DateFormatter()
                            if let expirationDate = dateFormatter.date(from: expiresAt) {
                                self.tokenExpirationDate = expirationDate
                                print("Token expires at: \(expirationDate)")
                            } else {
                                // If we can't parse the date, set it to 30 days from now
                                self.tokenExpirationDate = Date().addingTimeInterval(30 * 24 * 60 * 60)
                                print("Could not parse expiration date, set to 30 days from now")
                            }
                            
                            self.pendingAuthState = nil
                            self.isAuthenticated = true
                            self.isAuthenticating = false
                            
                            print("✅ Square authentication successful with location!")
                            print("📍 Location ID: \(locationId)")
                            print("🏢 Merchant ID: \(merchantId)")
                            
                            // Post notification that authentication was successful
                            NotificationCenter.default.post(
                                name: .squareOAuthCallback,
                                object: nil,
                                userInfo: [
                                    "accessToken": accessToken,
                                    "merchantId": merchantId,
                                    "locationId": locationId
                                ]
                            )
                            
                            completion(true)
                            return
                        } else if let error = json["error"] as? String {
                            if error == "token_not_found" {
                                // This is normal if the user hasn't completed auth yet
                                print("Token not found yet, waiting for user to complete authorization")
                                completion(false)
                                return
                            } else {
                                self.authError = "Backend error: \(error)"
                                self.isAuthenticating = false
                                print("Backend error: \(error)")
                                completion(false)
                                return
                            }
                        } else if let message = json["message"] as? String, message == "token_not_found" {
                            // This is normal if the user hasn't completed auth yet
                            print("Token not found yet, waiting for user to complete authorization")
                            completion(false)
                            return
                        }
                    }
                    
                    // If we get here, we're still waiting for the user to complete authorization
                    print("Still waiting for authorization to complete")
                    completion(false)
                    
                } catch {
                    print("JSON parsing error: \(error)")
                    completion(false)
                }
            }
        }.resume()
    }
    
    func handleOAuthCallback(url: URL) {
        print("Processing OAuth callback: \(url)")
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            authError = "Invalid callback URL structure"
            isAuthenticating = false
            print("Error: Invalid callback URL structure")
            return
        }
        
        // Check for success parameter from our backend
        if let success = queryItems.first(where: { $0.name == "success" })?.value,
           success == "true",
           let merchantId = queryItems.first(where: { $0.name == "merchant_id" })?.value {
            
            print("Received successful callback with merchant ID: \(merchantId)")
            
            // Store merchant ID immediately
            self.merchantId = merchantId
            
            // Start polling for authentication status
            startPollingForAuthStatus(merchantId: merchantId)
        } else if let error = queryItems.first(where: { $0.name == "error" })?.value {
            authError = "Authorization failed: \(error)"
            isAuthenticating = false
            print("Square OAuth Error: \(error)")
        } else {
            // If we don't have a success parameter, start polling anyway
            print("Callback received without explicit success parameter, starting polling")
            startPollingForAuthStatus()
        }
    }
    
    // Add this method to SquareAuthService.swift

    func startPollingForAuthStatus(merchantId: String? = nil, locationId: String? = nil) {
        print("Starting to poll for authentication status with state: \(pendingAuthState ?? "nil")")
        
        // Add more debug output
        if pendingAuthState == nil {
            print("ERROR: pendingAuthState is nil - polling will not work")
            return
        }
        
        // Store merchant ID if provided
        if let merchantId = merchantId {
            self.merchantId = merchantId
        }
        
        // Store location ID if provided
        if let locationId = locationId {
            self.locationId = locationId
        }
        
        // Make sure we're using a valid state parameter
        let state = pendingAuthState!
        print("Using state for polling: \(state)")
        
        // Poll the server every 3 seconds to check authentication status
        let timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                print("Self is nil, invalidating timer")
                timer.invalidate()
                return
            }
            
            // Check again before each request
            guard let currentState = self.pendingAuthState, currentState == state else {
                print("State changed or was cleared, stopping polling")
                timer.invalidate()
                return
            }
            
            print("Polling for authentication status with state: \(state)")
            
            // Use the state parameter to check authentication status
            let urlString = "\(SquareConfig.backendBaseURL)\(SquareConfig.statusEndpoint)?state=\(state)&device_id=\(deviceId)"
            guard let url = URL(string: urlString) else {
                self.authError = "Invalid status URL"
                self.isAuthenticating = false
                timer.invalidate()
                return
            }
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Network error polling status: \(error)")
                        return // continue polling
                    }
                    
                    // Print HTTP status code for debugging
                    if let httpResponse = response as? HTTPURLResponse {
                        print("Polling status code: \(httpResponse.statusCode)")
                    }
                    
                    guard let data = data else {
                        print("No data received when polling")
                        return // continue polling
                    }
                    
                    // Print raw response for debugging
                    let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                    print("Polling response: \(responseString)")
                    
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            
                            // ✅ CHECK FOR FINAL SUCCESS (tokens + location selected)
                            if let connected = json["connected"] as? Bool, connected,
                               let accessToken = json["access_token"] as? String,
                               let refreshToken = json["refresh_token"] as? String,
                               let merchantId = json["merchant_id"] as? String,
                               let locationId = json["location_id"] as? String,
                               let expiresAt = json["expires_at"] as? String {
                                
                                print("🎉 FINAL SUCCESS - STORING TOKENS")
                                print("📍 Location ID: \(locationId)")
                                
                                // Authentication successful - store tokens
                                self.accessToken = accessToken
                                self.refreshToken = refreshToken
                                self.merchantId = merchantId
                                self.locationId = locationId
                                
                                // Force synchronization
                                UserDefaults.standard.synchronize()
                                
                                // Parse expiration date
                                let dateFormatter = ISO8601DateFormatter()
                                if let expirationDate = dateFormatter.date(from: expiresAt) {
                                    self.tokenExpirationDate = expirationDate
                                } else {
                                    self.tokenExpirationDate = Date().addingTimeInterval(30 * 24 * 60 * 60)
                                }
                                
                                self.pendingAuthState = nil
                                self.isAuthenticated = true
                                self.isAuthenticating = false
                                
                                // Post notification that authentication was successful
                                NotificationCenter.default.post(
                                    name: .squareOAuthCallback,
                                    object: nil,
                                    userInfo: [
                                        "accessToken": accessToken,
                                        "merchantId": merchantId,
                                        "locationId": locationId
                                    ]
                                )
                                
                                print("Authentication successful! Tokens stored.")
                                timer.invalidate()
                                return
                            }
                            
                            // ✅ CHECK FOR LOCATION SELECTION REQUIRED
                            else if let message = json["message"] as? String,
                                    message == "location_selection_required" {
                                
                                print("🏪 Multiple locations found - need user selection")
                                print("📱 This should be handled by web UI, continuing to poll...")
                                
                                // Continue polling - user will select location in web UI
                                // and that will update the state with location_id
                                
                                return // Continue polling
                            }
                            
                            // ✅ CHECK FOR AUTHORIZATION IN PROGRESS
                            else if let message = json["message"] as? String,
                                    message == "authorization_in_progress" {
                                print("⏳ Authorization still in progress...")
                                return // Continue polling
                            }
                            
                            // ✅ CHECK FOR INVALID STATE
                            else if let message = json["message"] as? String,
                                    message == "invalid_state" {
                                print("❌ Invalid state - stopping polling")
                                self.authError = "Invalid authorization state"
                                self.isAuthenticating = false
                                self.pendingAuthState = nil
                                timer.invalidate()
                                return
                            }
                            
                            // ✅ FALLBACK - Still waiting
                            else {
                                print("⏳ Still waiting for authorization completion...")
                                print("Response keys: \(Array(json.keys))")
                            }
                        }
                    } catch {
                        print("Error parsing polling response: \(error)")
                    }
                }
            }.resume()
        }
        
        // Set a timeout after 5 minutes (increased for location selection)
        DispatchQueue.main.asyncAfter(deadline: .now() + 300) { [weak self] in
            timer.invalidate()
            
            guard let self = self, self.isAuthenticating else { return }
            
            self.authError = "Authentication timed out"
            self.isAuthenticating = false
            self.pendingAuthState = nil
            print("Authentication timed out after 5 minutes")
        }
        
        RunLoop.current.add(timer, forMode: .common)
    }

    // ✅ ALSO ADD: Switch to organization-based polling after timeout
    private func switchToOrganizationPolling() {
        print("🔄 Switching to organization-based polling...")
        
        // Clear state-based polling
        pendingAuthState = nil
        
        // Use organization-based status check
        checkAuthentication()
    }
    
    private func shouldUseDeviceSpecificId() -> Bool {
        // Check if we've explicitly enabled multi-device mode
        if UserDefaults.standard.bool(forKey: "enableMultiDeviceMode") {
            return true
        }
        
        // Check if we've detected conflicts (you can set this flag when login conflicts occur)
        if UserDefaults.standard.bool(forKey: "hasDeviceConflicts") {
            return true
        }
        
        // Default: use simple organization ID for backward compatibility
        return false
    }
    
    // MARK: - Token Management
    
    func refreshAccessToken() {
        guard let url = URL(string: "\(SquareConfig.backendBaseURL)\(SquareConfig.refreshEndpoint)") else {
            authError = "Invalid refresh URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "organization_id": organizationId,
            "device_id": deviceId
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            authError = "Failed to serialize request: \(error.localizedDescription)"
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    self.authError = "Network error: \(error.localizedDescription)"
                    self.isAuthenticated = false
                    return
                }
                
                guard let data = data else {
                    self.authError = "No data received"
                    self.isAuthenticated = false
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let error = json["error"] as? String {
                            self.authError = "Refresh error: \(error)"
                            self.isAuthenticated = false
                            return
                        }
                        
                        if let success = json["success"] as? Bool, success {
                            self.isAuthenticated = true
                            print("Square token refreshed successfully!")
                        } else {
                            self.isAuthenticated = false
                        }
                    } else {
                        self.authError = "Invalid response format"
                        self.isAuthenticated = false
                    }
                } catch {
                    self.authError = "Failed to parse response: \(error.localizedDescription)"
                    self.isAuthenticated = false
                }
            }
        }.resume()
    }
    
    func refreshTokenIfNeeded() {
        // Check if we have a refresh token and if the token is expired or about to expire
        guard let refreshToken = refreshToken,
              let expirationDate = tokenExpirationDate else {
            return
        }
        
        // Refresh if token expires in less than 7 days (as recommended by Square)
        let sevenDaysInSeconds: TimeInterval = 7 * 24 * 60 * 60
        if Date().addingTimeInterval(sevenDaysInSeconds) > expirationDate {
            print("Access token will expire soon, refreshing...")
            refreshAccessToken(refreshToken: refreshToken)
        }
    }
    
    // MARK: - Logout Methods
    
    /// Disconnect from the server by calling the disconnect endpoint
    func disconnectFromServer(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(SquareConfig.backendBaseURL)\(SquareConfig.disconnectEndpoint)") else {
            print("Invalid disconnect URL")
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "organization_id": organizationId,
            "device_id": deviceId
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("Failed to serialize disconnect request: \(error.localizedDescription)")
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Network error during server disconnect: \(error.localizedDescription)")
                    completion(false) // Server disconnect failed due to network error
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("Server disconnect response status code: \(httpResponse.statusCode)")
                    if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                        print("Successfully disconnected from server (tokens revoked by server if applicable).")
                        completion(true) // Server disconnect successful
                    } else {
                        print("Server returned error during disconnect (status code: \(httpResponse.statusCode)).")
                        completion(false) // Server disconnect failed (server-side error)
                    }
                } else {
                    print("Invalid response received from server during disconnect.")
                    completion(false) // Server disconnect failed (invalid response)
                }
            }
        }.resume()
    }
    
    /// Clear all local authentication data
    func clearLocalAuthData() {
        print("Clearing all local authentication data")
        
        // Clear all token-related values
        accessToken = nil
        refreshToken = nil
        merchantId = nil
        locationId = nil
        tokenExpirationDate = nil
        pendingAuthState = nil
        
        // ADD THIS LINE HERE:
        UserDefaults.standard.removeObject(forKey: organizationIdKey)
        
        // Reset state
        isAuthenticated = false
        isAuthenticating = false
        authError = nil
        
        // NEW: Clear catalog state when auth changes
        NotificationCenter.default.post(
            name: Notification.Name("ClearCatalogState"),
            object: nil
        )
        
        // Post notification that auth state changed
        NotificationCenter.default.post(name: .squareAuthenticationStatusChanged, object: nil)
        
        print("All local authentication data cleared")
    }
    
    
    
    // MARK: - Helper Methods
    
    func handleCallbackFromBackend(success: Bool) {
        isAuthenticating = false
        
        if success {
            isAuthenticated = true
            print("Successfully authenticated with Square via backend")
        } else {
            authError = "Authentication failed"
            isAuthenticated = false
        }
    }
    
    private func openAuthURL(_ url: URL) {
        // Don't do anything here - we're now handling opening the URL in SquareAuthorizationView
        print("Auth URL generated: \(url)")
        // The actual browser will be shown by the sheet in SquareAuthorizationView
    }
    
    private func refreshAccessToken(refreshToken: String) {
        guard let url = URL(string: "\(SquareConfig.backendBaseURL)\(SquareConfig.refreshEndpoint)") else {
            authError = "Invalid refresh URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "refresh_token": refreshToken,
            "organization_id": organizationId,
            "device_id": deviceId
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            authError = "Failed to serialize request: \(error.localizedDescription)"
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    self.authError = "Network error: \(error.localizedDescription)"
                    self.isAuthenticated = false
                    return
                }
                
                guard let data = data else {
                    self.authError = "No data received"
                    self.isAuthenticated = false
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let error = json["error"] as? String {
                            self.authError = "Refresh error: \(error)"
                            self.isAuthenticated = false
                            return
                        }
                        
                        if let success = json["success"] as? Bool, success,
                           let newAccessToken = json["access_token"] as? String,
                           let newRefreshToken = json["refresh_token"] as? String,
                           let newExpiresIn = json["expires_in"] as? Int {
                            
                            // Store new tokens
                            self.accessToken = newAccessToken
                            self.refreshToken = newRefreshToken
                            self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(newExpiresIn))
                            
                            self.isAuthenticated = true
                            print("Square token refreshed successfully!")
                        } else {
                            self.isAuthenticated = false
                        }
                    } else {
                        self.authError = "Invalid response format"
                        self.isAuthenticated = false
                    }
                } catch {
                    self.authError = "Failed to parse response: \(error.localizedDescription)"
                    self.isAuthenticated = false
                }
            }
        }.resume()
    }
    // MARK: - Device Management
        
        /// Get the current device ID
        func getCurrentDeviceId() -> String {
            return deviceId
        }
        
        /// Reset device ID (for testing or device transfer)
        func resetDeviceId() {
            UserDefaults.standard.removeObject(forKey: deviceIdKey)
            print("🔄 Device ID reset - will generate new one on next access")
        }
        
        /// Check if another device is using the same base organization
        func checkForOtherDevices(completion: @escaping ([String]) -> Void) {
            // This would query your backend for other device IDs using the same base org
            // Implementation depends on your backend API
            completion([]) // Placeholder
        }
    func enableMultiDeviceMode() {
        UserDefaults.standard.set(true, forKey: "enableMultiDeviceMode")
        print("🔄 Multi-device mode enabled - will use device-specific organization IDs")
        
        // Clear authentication to force re-auth with new ID format
        clearLocalAuthData()
    }

    // FIX 4: Add conflict detection (call this when you detect login conflicts)
    func handleDeviceConflict() {
        print("⚠️ Device conflict detected - enabling device-specific IDs")
        UserDefaults.standard.set(true, forKey: "hasDeviceConflicts")
        enableMultiDeviceMode()
    }
    func debugCurrentIdStrategy() {
        print("🔍 Current ID Strategy Debug:")
        print("  - Base Organization ID: \(baseOrganizationId)")
        print("  - Device ID: \(deviceId)")
        print("  - Should Use Device-Specific: \(shouldUseDeviceSpecificId())")
        print("  - Final Organization ID: \(organizationId)")
        print("  - Multi-Device Mode: \(UserDefaults.standard.bool(forKey: "enableMultiDeviceMode"))")
        print("  - Has Conflicts: \(UserDefaults.standard.bool(forKey: "hasDeviceConflicts"))")
    }
}

// MARK: - Notification Names Extension

extension Notification.Name {
    static let squareAuthenticationStatusChanged = Notification.Name("SquareAuthenticationStatusChanged")
}
