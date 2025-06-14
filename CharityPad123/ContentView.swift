import SwiftUI

struct ContentView: View {
    // Add a state variable to force refreshes
    @State private var refreshTrigger = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("isInAdminMode") private var isInAdminMode: Bool = false  // CHANGED: Default to false
    @EnvironmentObject private var donationViewModel: DonationViewModel
    @EnvironmentObject private var organizationStore: OrganizationStore
    @EnvironmentObject private var kioskStore: KioskStore
    @EnvironmentObject private var squareAuthService: SquareAuthService
    @EnvironmentObject private var squarePaymentService: SquarePaymentService
    
    var body: some View {
        Group {
            // FIXED: Check onboarding FIRST, before anything else
            if !hasCompletedOnboarding {
                OnboardingView()
                    .environmentObject(organizationStore)
                    .environmentObject(kioskStore)
                    .environmentObject(donationViewModel)
                    .environmentObject(squareAuthService)
                    .onAppear {
                        // Reset any other state when showing onboarding
                        resetAppState()
                    }
            } else if isInAdminMode {
                AdminDashboardView()
                    .environmentObject(organizationStore)
                    .environmentObject(kioskStore)
                    .environmentObject(donationViewModel)
                    .environmentObject(squareAuthService)
            } else {
                HomeView()
                    .environmentObject(donationViewModel)
                    .environmentObject(kioskStore)
                    .environmentObject(squareAuthService)
            }
        }
        // Add this to force UI refresh when needed
        .id("main-content-\(refreshTrigger)")
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ForceViewRefresh"))) { _ in
            // Force view refresh by toggling the trigger
            refreshTrigger.toggle()
        }
        .onAppear {
            // Don't do state checks during logout
            if !squareAuthService.isExplicitlyLoggingOut {
                ensureStateConsistency()
                squareAuthService.checkAuthentication()
                
                // Initialize the SDK if we're already authenticated
                if squareAuthService.isAuthenticated {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        squarePaymentService.initializeSDK()
                    }
                }
            }
            
            // Health check monitoring can run regardless
            squarePaymentService.startHealthCheckMonitoring()
            
            if squareAuthService.isAuthenticated && !squareAuthService.isExplicitlyLoggingOut {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    squarePaymentService.performHealthCheck()
                }
            }
        }
        // Add listener for authentication state changes
        .onChange(of: squareAuthService.isAuthenticated) { _, isAuthenticated in
            // 🔧 FIX: Don't react to auth changes during explicit logout
            if squareAuthService.isExplicitlyLoggingOut {
                print("🚫 Ignoring auth state change during explicit logout")
                return
            }
            
            if isAuthenticated {
                // Initialize the SDK when authentication state changes to authenticated
                squarePaymentService.initializeSDK()
            }
            // Let the proper logout flow in AdminDashboardView handle logout instead
        }
        // NEW: Listen for forced logout notifications
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ForceReturnToOnboarding"))) { _ in
            print("🚨 Received force logout notification - returning to onboarding")
            hasCompletedOnboarding = false
            isInAdminMode = false
        }
    }
    // NEW: Ensure app state is consistent on startup
    private func ensureStateConsistency() {
        print("🔧 Checking app state consistency...")
        print("📱 hasCompletedOnboarding: \(hasCompletedOnboarding)")
        print("📱 isInAdminMode: \(isInAdminMode)")
        print("📱 squareAuthService.isAuthenticated: \(squareAuthService.isAuthenticated)")
        
        // If not onboarded, force admin mode off
        if !hasCompletedOnboarding {
            print("🔧 App not onboarded - resetting admin mode to false")
            isInAdminMode = false
            return
        }
        
        
        print("✅ App state consistency check passed")
    }
    
    // Add a function to reset app state when needed
    private func resetAppState() {
        // Reset any in-memory state that might be causing issues
        // This runs when returning to onboarding/login screen
        squareAuthService.authError = nil
        squareAuthService.isAuthenticating = false
        
        // Reset donation state
        donationViewModel.resetDonation()
        
        
        // Ensure in-memory state is clean for a fresh start
        print("App state reset for fresh onboarding")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let authService = SquareAuthService()
        let catalogService = SquareCatalogService(authService: authService)
        
        return ContentView()
            .environmentObject(DonationViewModel())
            .environmentObject(OrganizationStore())
            .environmentObject(KioskStore())
            .environmentObject(authService)
            .environmentObject(catalogService)
            .environmentObject(SquarePaymentService(authService: authService, catalogService: catalogService))
    }
}
