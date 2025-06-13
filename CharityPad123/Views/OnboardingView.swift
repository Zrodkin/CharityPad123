// Fixed OnboardingView.swift
import SwiftUI
import SafariServices
import CoreLocation

struct OnboardingView: View {
    @State private var isLoading = false
    @State private var showingSafari = false
    @State private var authURL: URL? = nil
    @State private var safariDismissed = false
    @State private var isPolling = false
    @State private var pollingTimer: Timer? = nil
    @State private var notificationObserver: NSObjectProtocol? = nil
    @State private var showingSupportView = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @EnvironmentObject private var organizationStore: OrganizationStore
    @EnvironmentObject private var squareAuthService: SquareAuthService
    
    // NEW: Location permission manager
    @StateObject private var locationManager = LocationPermissionManager()
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.55, green: 0.47, blue: 0.84),
                    Color(red: 0.56, green: 0.71, blue: 1.0),
                    Color(red: 0.97, green: 0.76, blue: 0.63),
                    Color(red: 0.97, green: 0.42, blue: 0.42)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Content
            VStack(spacing: 0) {
                Spacer()
                
                // Logo
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.9))
                        .frame(width: 120, height: 120)
                    
                    if let logoImage = UIImage(named: "organization-image") {
                        Image(uiImage: logoImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 90, height: 90)
                            .clipShape(Circle())
                    } else {
                        Text("Logo")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 30)
                
                // Title and description
                Text("Welcome to ShulPad")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.black)
                
                Text("Your smarter, simpler way to collect donations with ease.")
                    .font(.headline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 5)
                    .padding(.bottom, 40)
                
                // Features list
                VStack(alignment: .leading, spacing: 20) {
                    FeatureRow(text: "Collect donations easily via Square")
                    FeatureRow(text: "Personalize your kiosk with your own branding")
                    FeatureRow(text: "See live donation reports and insights")
                    FeatureRow(text: "Automatically send thank-you emails to donors")
                }
                .padding(.bottom, 40)
                
                // Status view when checking connection
                if safariDismissed {
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5)
                            .padding()
                        
                        Text("Checking connection status...")
                            .font(.headline)
                            .foregroundColor(.black)
                    }
                    .padding(.vertical)
                } else {
                    // Connect button
                    Button(action: {
                        // 🔧 CRITICAL FIX: Check authentication state first
                        if squareAuthService.isAuthenticated {
                            print("✅ Already authenticated during button press - completing onboarding immediately")
                            completeOnboarding()
                        } else {
                            print("🔄 Not authenticated - starting auth flow")
                            requestLocationThenAuth()
                        }
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.trailing, 10)
                                Text("Connecting...")
                            } else {
                                Image("square-logo")
                                   .resizable()
                                   .scaledToFit()
                                   .frame(height: 20)
                                   .accessibility(label: Text("Square logo"))
                                Text("Connect with Square to Get Started")
                                Image(systemName: "arrow.right")
                                    .padding(.leading, 5)
                            }
                        }
                        .padding(.horizontal, 30)
                        .padding(.vertical, 16)
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                    }
                    .disabled(isLoading)
                    .padding(.horizontal)
                }
                
                Text("By continuing, you agree to connect your Square account to ShulPad.\nWe'll use this to process payments and manage your donations.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.top, 15)
                    .padding(.horizontal)
                
                Spacer()
                
                // Support link
                HStack {
                    Text("Need help?")
                        .foregroundColor(.black)
                    
                    Button("Contact support") {
                        showingSupportView = true
                    }
                    .foregroundColor(.green)
                }
                .font(.subheadline)
                .padding(.bottom, 20)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color.white.opacity(0.85))
                    .shadow(radius: 10)
            )
            .padding(.horizontal, 40)
            .padding(.vertical, 60)
        }
        .sheet(isPresented: $showingSupportView) {
            SupportView()
                .presentationDetents([.large])
                .presentationCornerRadius(20)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingSafari, onDismiss: {
            // Only handle dismiss manually if we haven't already received the OAuth callback
            if !squareAuthService.isAuthenticated {
                safariDismissed = true
                isPolling = true
                print("Safari sheet dismissed manually, starting intensive polling")
                
                // Start intensive polling
                if squareAuthService.pendingAuthState != nil {
                    print("Found pending auth state: \(squareAuthService.pendingAuthState!)")
                    startIntensivePolling()
                } else {
                    print("WARNING: No pending auth state found after Safari dismissed!")
                    isLoading = false
                }
            }
        }) {
            if let url = authURL {
                SafariView(url: url, onDismiss: {
                    if !squareAuthService.isAuthenticated {
                        showingSafari = false
                    }
                })
            }
        }
        .onAppear {
            print("🔍 OnboardingView appeared - checking auth state")
            print("📱 squareAuthService.isAuthenticated: \(squareAuthService.isAuthenticated)")
            print("📱 hasCompletedOnboarding: \(hasCompletedOnboarding)")
            
            // 🔧 CRITICAL FIX: Check if already authenticated on appear
            if squareAuthService.isAuthenticated {
                print("✅ Already authenticated on appear - completing onboarding immediately")
                completeOnboarding()
                return
            }
            
            // Only check authentication if not already authenticated
            squareAuthService.checkAuthentication()
            
            // Set up notification observer for OAuth callback
            notificationObserver = NotificationCenter.default.addObserver(
                forName: .squareOAuthCallback,
                object: nil,
                queue: .main
            ) { notification in
                print("OnboardingView: Received OAuth callback notification")
                handleOAuthCallback(notification)
                
                // Close Safari view if open
                if showingSafari {
                    showingSafari = false
                }
            }
        }
        .onDisappear {
            // Clean up when view disappears
            pollingTimer?.invalidate()
            pollingTimer = nil
            
            // Remove notification observer
            if let observer = notificationObserver {
                NotificationCenter.default.removeObserver(observer)
                notificationObserver = nil
            }
        }
        // 🔧 CRITICAL FIX: Improved monitoring of authentication state changes
        .onReceive(squareAuthService.$isAuthenticated) { isAuthenticated in
            print("🔄 OnboardingView: Auth state changed to \(isAuthenticated)")
            
            if isAuthenticated {
                print("✅ Authentication detected - completing onboarding")
                completeOnboarding()
            }
        }
        // 🔧 ADDITIONAL FIX: Also monitor for explicit authentication success
        .onReceive(NotificationCenter.default.publisher(for: .squareAuthenticationSuccessful)) { _ in
            print("✅ Received explicit authentication success notification")
            completeOnboarding()
        }
        .alert("Location Permission Required", isPresented: $locationManager.showingPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) {
                isLoading = false
            }
        } message: {
            Text("ShulPad needs location access to connect to Square card readers. Please enable Location Services in Settings.")
        }
    }
    
    // 🔧 NEW: Centralized onboarding completion method
    private func completeOnboarding() {
        print("🏁 Completing onboarding...")
        
        // Stop any ongoing timers
        pollingTimer?.invalidate()
        pollingTimer = nil
        
        // Reset loading states
        isLoading = false
        safariDismissed = false
        
        // Complete onboarding
        hasCompletedOnboarding = true
        
        print("✅ Onboarding completed - hasCompletedOnboarding set to true")
        
        // 🔧 POST NOTIFICATION: Ensure all observers know onboarding is complete
        NotificationCenter.default.post(name: NSNotification.Name("OnboardingCompleted"), object: nil)
    }
    
    // Request location permission first, then start auth
    private func requestLocationThenAuth() {
        print("🔍 Requesting location permission before auth...")
        
        isLoading = true
        
        locationManager.requestLocationPermission { [self] granted in
            DispatchQueue.main.async {
                if granted {
                    print("✅ Location permission granted, starting auth")
                    self.startAuth()
                } else {
                    print("❌ Location permission denied")
                    self.isLoading = false
                }
            }
        }
    }
    
    // Handle OAuth callback notification
    private func handleOAuthCallback(_ notification: Notification) {
        print("🔄 Handling OAuth callback in OnboardingView")
        
        // Extract success/error from notification userInfo
        if let userInfo = notification.userInfo,
           let success = userInfo["success"] as? Bool {
            print("OAuth callback received with success: \(success)")
            
            if success {
                // Stop polling and reset state
                pollingTimer?.invalidate()
                pollingTimer = nil
                isLoading = false
                safariDismissed = false
                
                print("🔄 OAuth callback successful - checking auth service state")
                
                // 🔧 FIX: Give the auth service a moment to update, then complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if self.squareAuthService.isAuthenticated {
                        print("✅ Auth service confirmed authenticated - completing onboarding")
                        self.completeOnboarding()
                    } else {
                        print("🔄 Auth service not yet updated - triggering check")
                        self.squareAuthService.checkAuthentication()
                    }
                }
            } else {
                // Handle error
                if let error = userInfo["error"] as? String {
                    print("OAuth error: \(error)")
                }
                
                // Reset state
                isLoading = false
                safariDismissed = false
            }
        }
    }
    
    // Function to start more intensive polling after Safari is dismissed
    private func startIntensivePolling() {
        pollingTimer?.invalidate()
        
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            squareAuthService.checkPendingAuthorization { success in
                if success {
                    print("Polling found successful authentication")
                    pollingTimer?.invalidate()
                    pollingTimer = nil
                    safariDismissed = false
                    
                    // 🔧 FIX: Complete onboarding when polling succeeds
                    DispatchQueue.main.async {
                        self.completeOnboarding()
                    }
                }
            }
        }
        
        // Also immediately check once
        squareAuthService.checkPendingAuthorization { _ in }
        
        // Set a timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            guard self.safariDismissed && !self.squareAuthService.isAuthenticated else { return }
            
            self.pollingTimer?.invalidate()
            self.pollingTimer = nil
            self.isLoading = false
            self.safariDismissed = false
            print("Polling timed out after 30 seconds")
        }
    }
    
    private func startAuth() {
        print("Starting Square OAuth flow directly...")
        
        SquareConfig.generateOAuthURL { url, error, state in
            DispatchQueue.main.async {
                if let error = error {
                    print("Failed to generate authorization URL: \(error.localizedDescription)")
                    isLoading = false
                    return
                }
                
                guard let url = url else {
                    print("Failed to generate authorization URL")
                    isLoading = false
                    return
                }
                
                if let state = state {
                    print("Setting pendingAuthState to: \(state)")
                    squareAuthService.pendingAuthState = state
                } else {
                    print("WARNING: No state returned from generateOAuthURL")
                }
                
                self.authURL = url
                squareAuthService.isAuthenticating = true
                
                self.showingSafari = true
            }
        }
    }
}

// Location Permission Manager (unchanged)
class LocationPermissionManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var showingPermissionAlert = false
    
    private var locationManager: CLLocationManager
    private var permissionCompletion: ((Bool) -> Void)?
    
    override init() {
        locationManager = CLLocationManager()
        super.init()
        locationManager.delegate = self
    }
    
    func requestLocationPermission(completion: @escaping (Bool) -> Void) {
        permissionCompletion = completion
        
        let status = locationManager.authorizationStatus
        print("📍 Current location status: \(status)")
        
        switch status {
        case .notDetermined:
            print("📍 Requesting location permission...")
            locationManager.requestWhenInUseAuthorization()
            
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ Location permission already granted")
            completion(true)
            
        case .denied, .restricted:
            print("❌ Location permission denied")
            showingPermissionAlert = true
            completion(false)
            
        @unknown default:
            print("⚠️ Unknown location status")
            completion(false)
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        print("📍 Location authorization changed to: \(status)")
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ Location permission granted")
            permissionCompletion?(true)
            
        case .denied, .restricted:
            print("❌ Location permission denied")
            showingPermissionAlert = true
            permissionCompletion?(false)
            
        case .notDetermined:
            print("📍 Location permission still not determined")
            
        @unknown default:
            print("⚠️ Unknown location authorization status")
            permissionCompletion?(false)
        }
        
        if status != .notDetermined {
            permissionCompletion = nil
        }
    }
}

// Add the FeatureRow struct back
struct FeatureRow: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.black)
                .padding(.top, 2)
            
            Text(text)
                .foregroundColor(Color.gray.opacity(0.8))
        }
    }
}
