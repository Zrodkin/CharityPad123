import SwiftUI

struct AdminDashboardView: View {
    @State private var selectedTab: String? = "home"
    // @State private var showingKiosk = false // This state variable seems unused
    @State private var showLogoutAlert = false
    @State private var isLoggingOut = false
    @AppStorage("isInAdminMode") private var isInAdminMode: Bool = true
    @EnvironmentObject private var organizationStore: OrganizationStore
    @EnvironmentObject private var kioskStore: KioskStore
    @EnvironmentObject private var donationViewModel: DonationViewModel
    @EnvironmentObject private var squareAuthService: SquareAuthService
    @EnvironmentObject private var squarePaymentService: SquarePaymentService
    @EnvironmentObject private var squareReaderService: SquareReaderService
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            VStack {
                List(selection: $selectedTab) {
                    Text(organizationStore.name)
                        .font(.headline)
                        .padding(.vertical, 8)
                        .tag(nil as String?) // Allows no selection text to show initially if selectedTab is nil
                    
                    NavigationLink(value: "home") {
                        Label("Home Page", systemImage: "house")
                    }
                    
                    NavigationLink(value: "presetAmounts") {
                        Label("Preset Amounts", systemImage: "dollarsign.circle")
                    }
                    
                    NavigationLink(value: "receipts") {
                        Label("Email Receipts", systemImage: "envelope")
                    }
                    
                    NavigationLink(value: "timeout") {
                        Label("Timeout Settings", systemImage: "clock")
                    }
                    
                    NavigationLink(value: "readers") {
                        Label("Card Readers", systemImage: "creditcard.wireless")
                    }
                    
                    Spacer()
                        .frame(height: 20)
                        .tag(nil as String?) // Needs a unique tag if it's selectable, or make it non-selectable
                    
                    Button(action: {
                        showLogoutAlert = true
                    }) {
                        Label("Logout", systemImage: "arrow.right.square")
                            .foregroundColor(.red)
                    }
                    .tag(nil as String?) // Needs a unique tag or handle selection appropriately
                }
                .listStyle(SidebarListStyle())
                
                // Square connection status
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Circle()
                            .fill(squareAuthService.isAuthenticated ? Color.green : Color.red)
                            .frame(width: 10, height: 10)
                        
                        Text(squareAuthService.isAuthenticated ? "Connected to Square" : "Not connected to Square")
                            .font(.caption)
                            .foregroundColor(squareAuthService.isAuthenticated ? .green : .red)
                    }
                    
                    if squareAuthService.isAuthenticated {
                        HStack {
                            Circle()
                                .fill(squarePaymentService.isReaderConnected ? Color.green : Color.orange)
                                .frame(width: 10, height: 10)
                            
                            Text(squarePaymentService.connectionStatus)
                                .font(.caption)
                                .foregroundColor(squarePaymentService.isReaderConnected ? .green : .orange)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 5)
                
                // Launch Kiosk Button
                Button(action: {
                    kioskStore.updateDonationViewModel(donationViewModel)
                    isInAdminMode = false
                }) {
                    Label("Launch Kiosk", systemImage: "play.circle")
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .padding(.horizontal)
                .background(Color.white.opacity(0.1))
                .disabled(!squareAuthService.isAuthenticated)
            }
            .navigationTitle("Admin Dashboard")
            .onChange(of: squareAuthService.isAuthenticated) { newIsAuthenticatedValue in // Use new value
                if newIsAuthenticatedValue {
                    squarePaymentService.initializeSDK()
                }
            }
            .onAppear {
                // MODIFICATION: Temporarily disable reader service monitoring for diagnostics
                // DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                //     if self.isInAdminMode {
                //         // squareReaderService.startMonitoring() // COMMENT OUT
                //     }
                // }
                print("AdminDashboardView: Reader monitoring TEMPORARILY DISABLED for diagnostics.")

                if squareAuthService.isAuthenticated {
                    squarePaymentService.initializeSDK()
                }
            }
            .onDisappear {
                // squareReaderService.stopMonitoring() // COMMENT OUT
            }

        } detail: {
            // Detail content based on selection
            if let selectedTab = selectedTab {
                switch selectedTab {
                case "home":
                    HomePageSettingsView().environmentObject(kioskStore)
                case "presetAmounts":
                    PresetAmountsView().environmentObject(kioskStore)
                case "receipts":
                    EmailReceiptsView().environmentObject(organizationStore)
                case "timeout":
                    TimeoutSettingsView().environmentObject(kioskStore)
                case "readers":
                    ReaderManagementView()
                        .environmentObject(squareAuthService)
                        .environmentObject(squareReaderService)
                default:
                    Text("Select an option from the sidebar")
                        .font(.title).foregroundColor(.gray)
                }
            } else {
                Text("Select an option from the sidebar") // Default view when no tab is selected
                    .font(.title).foregroundColor(.gray)
            }
        }
        .alert(isPresented: $showLogoutAlert) {
            Alert(
                title: Text("Are you sure you want to logout?"),
                message: Text("You will need to log back in to access the admin panel."),
                primaryButton: .destructive(Text("Logout")) {
                    showLogoutAlert = false // Dismiss alert first
                    // Increased delay to ensure alert dismissal before starting heavy logout ops
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        initiateLogoutProcess()
                    }
                },
                secondaryButton: .cancel() {
                    showLogoutAlert = false
                }
            )
        }
        .overlay(
            Group {
                if isLoggingOut {
                    ZStack {
                        Color.black.opacity(0.6).edgesIgnoringSafeArea(.all)
                        VStack(spacing: 16) {
                            ProgressView().scaleEffect(1.5).padding()
                            Text("Logging out...").font(.headline).foregroundColor(.white).padding(.bottom, 4)
                            Text("Please wait while we clean up your session").font(.caption).foregroundColor(.white.opacity(0.8))
                        }
                        .padding(24).background(Color(.systemBackground).opacity(0.9)).cornerRadius(16).shadow(radius: 10)
                    }
                    .transition(.opacity).animation(.easeInOut, value: isLoggingOut)
                }
            }
        )
        .onReceive(NotificationCenter.default.publisher(for: .squareAuthenticationStatusChanged)) { _ in
            print("AdminDashboardView: Received .squareAuthenticationStatusChanged notification")
            // Potentially refresh parts of the UI if needed, but avoid causing re-render loops.
        }
    }
    
    // MARK: - Refactored Logout Methods
    
    private func initiateLogoutProcess() {
        isLoggingOut = true // Show "Logging out..." overlay

        // Step 1: Deauthorize Square SDK (if currently authenticated)
        if squareAuthService.isAuthenticated {
            print("Logout: Deauthorizing Square SDK...")
            squarePaymentService.deauthorizeSDK {
                print("Logout: SDK deauthorization complete.")
                self.attemptServerDisconnect()
            }
        } else {
            print("Logout: SDK already deauthorized or was never authorized. Skipping deauth.")
            self.attemptServerDisconnect()
        }
    }
    
    private func attemptServerDisconnect() {
        // Step 2: Attempt to disconnect from your backend server
        print("Logout: Attempting to disconnect from server...")
        squareAuthService.disconnectFromServer { serverDisconnectSuccess in
            print("Logout: Server disconnect attempt finished (success: \(serverDisconnectSuccess)).")
            // Regardless of server disconnect success, proceed with client-side cleanup.
            self.finalizeClientSideLogout()
        }
    }
    
    private func finalizeClientSideLogout() {
        print("Logout: Finalizing client-side logout...")
        // Step 3: Stop other services like reader monitoring
        squareReaderService.stopMonitoring()
        
        // Step 4: Reset local view models and non-auth related state
        donationViewModel.resetDonation()
        
        // Step 5: Clear all local Square authentication data.
        // This will set squareAuthService.isAuthenticated to false,
        // which should trigger UI updates in ContentView via @AppStorage and @EnvironmentObject.
        squareAuthService.clearLocalAuthData()
        print("Logout: Local auth data cleared. isAuthenticated should be false.")

        // Step 6: Perform final UI state transitions to navigate to Onboarding
        // A short delay can help ensure that state changes from clearLocalAuthData propagate
        // before these final @AppStorage changes take full effect for ContentView.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { // Minimal delay for state propagation
            self.isInAdminMode = true // Ensure this is set correctly for ContentView logic
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding") // Key trigger for ContentView
            
            // Hide the "Logging out..." overlay
            self.isLoggingOut = false
            print("Logout: Process complete. Should navigate to Onboarding.")

            // Consider removing ForceViewRefresh if @AppStorage and @EnvironmentObject changes
            // are reliably updating ContentView. If not, it can be a fallback.
            // NotificationCenter.default.post(name: NSNotification.Name("ForceViewRefresh"), object: nil)
        }
    }
}

// Preview remains the same
struct AdminDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        let authService = SquareAuthService()
        let catalogService = SquareCatalogService(authService: authService)
        let paymentService = SquarePaymentService(authService: authService, catalogService: catalogService)
        let readerService = SquareReaderService(authService: authService)
        // Crucial: Connect readerService to paymentService (if this pattern is used in your app setup)
        // paymentService.setReaderService(readerService) // Assuming paymentService has such a method

        return AdminDashboardView()
            .environmentObject(OrganizationStore())
            .environmentObject(KioskStore())
            .environmentObject(DonationViewModel())
            .environmentObject(authService)
            .environmentObject(catalogService)
            .environmentObject(paymentService)
            .environmentObject(readerService)
    }
}
