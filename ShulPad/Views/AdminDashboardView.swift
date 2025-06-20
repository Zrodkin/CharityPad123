import SwiftUI

struct AdminDashboardView: View {
    @State private var selectedTab: String? = nil
    @State private var showLogoutAlert = false
    @State private var isLoggingOut = false
    @State private var showingSubscriptionSheet = false
    @State private var isProcessingLogout = false
    
    // 🔧 FIX: Create @StateObject properly - will be initialized in onAppear
    @StateObject private var subscriptionService = SubscriptionService(authService: SquareAuthService())
    
    @AppStorage("isInAdminMode") private var isInAdminMode: Bool = true
    @EnvironmentObject private var organizationStore: OrganizationStore
    @EnvironmentObject private var kioskStore: KioskStore
    @EnvironmentObject private var donationViewModel: DonationViewModel
    @EnvironmentObject private var squareAuthService: SquareAuthService
    @EnvironmentObject private var squarePaymentService: SquarePaymentService
    @EnvironmentObject private var squareReaderService: SquareReaderService
    
    var body: some View {
        NavigationSplitView {
            // Clean sidebar with modern styling
            VStack(spacing: 0) {
                // Organization header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        // Organization logo or icon
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 48, height: 48)
                            
                            Text(String(organizationStore.name.prefix(1).uppercased()))
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(organizationStore.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            
                            Text("Admin Dashboard")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                
                // Navigation list
                List(selection: $selectedTab) {
                    Section {
                        NavigationLink(value: "home") {
                            AdminNavItem(
                                icon: "house.fill",
                                title: "Home Page",
                                subtitle: "Customize appearance"
                            )
                        }
                        
                        NavigationLink(value: "presetAmounts") {
                            AdminNavItem(
                                icon: "dollarsign.circle.fill",
                                title: "Donation Amounts",
                                subtitle: "Set preset values"
                            )
                        }
                        
                        NavigationLink(value: "receipts") {
                            AdminNavItem(
                                icon: "envelope.fill",
                                title: "Email Receipts",
                                subtitle: "Organization details"
                            )
                        }
                        
                        NavigationLink(value: "timeout") {
                            AdminNavItem(
                                icon: "clock.fill",
                                title: "Timeout Settings",
                                subtitle: "Auto-reset duration"
                            )
                        }
                        
                        NavigationLink(value: "readers") {
                            AdminNavItem(
                                icon: "creditcard.fill",
                                title: "Card Readers",
                                subtitle: "Hardware management"
                            )
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                
                Spacer()
                
                // Connection status section
                connectionStatusSection
                
                // Action buttons
                actionButtonsSection
            }
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
            
        } detail: {
            detailView
        }
        .alert("Logout", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) {
                print("🚫 Logout cancelled by user")
                showLogoutAlert = false
                isProcessingLogout = false
            }
            Button("Logout", role: .destructive) {
                print("✅ Logout confirmed by user")
                showLogoutAlert = false
                isProcessingLogout = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    initiateLogoutProcess()
                }
            }
        } message: {
            Text("Are you sure you want to logout? You will need to authenticate again to access the admin panel.")
        }
        .overlay(
            Group {
                if isLoggingOut {
                    LogoutOverlay()
                }
            }
        )
        .onChange(of: squareAuthService.isAuthenticated) { _, newValue in
            if newValue {
                squarePaymentService.initializeSDK()
                // Check subscription status when authenticated
                Task {
                    await subscriptionService.checkSubscriptionStatus()
                }
            }
        }
        .onAppear {
            // 🔧 FIX: Create new subscription service with the correct auth service
            // Since @StateObject can't be reassigned, we'll work around this by
            // ensuring the subscription service is initialized properly
            if squareAuthService.isAuthenticated {
                squarePaymentService.initializeSDK()
                
                // Check subscription status when authenticated
                Task {
                    await subscriptionService.checkSubscriptionStatus()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .squareAuthenticationStatusChanged)) { _ in
            // Handle authentication status changes
            if squareAuthService.isAuthenticated {
                Task {
                    await subscriptionService.checkSubscriptionStatus()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LaunchKioskFromQuickSetup"))) { _ in
            print("🚀 Launching kiosk from quick setup")
            kioskStore.updateDonationViewModel(donationViewModel)
            isInAdminMode = false
        }
        .sheet(isPresented: $showingSubscriptionSheet) {
            SubscriptionManagementView(
                subscriptionService: createCurrentSubscriptionService(),
                authService: squareAuthService
            )
        }
    }
    
    // 🔧 FIX: Helper method to create subscription service with current auth service
    private func createCurrentSubscriptionService() -> SubscriptionService {
        return SubscriptionService(authService: squareAuthService)
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var connectionStatusSection: some View {
        VStack(spacing: 16) {
            // Square connection status
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(squareAuthService.isAuthenticated ?
                              Color.green.opacity(0.15) : Color.red.opacity(0.15))
                        .frame(width: 32, height: 32)
                    
                    Circle()
                        .fill(squareAuthService.isAuthenticated ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Square Integration")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(squareAuthService.isAuthenticated ? "Connected" : "Disconnected")
                        .font(.caption)
                        .foregroundStyle(squareAuthService.isAuthenticated ? .green : .red)
                }
                
                Spacer()
            }
            
            // Reader status (only if Square is connected)
            if squareAuthService.isAuthenticated {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(squarePaymentService.isReaderConnected ?
                                  Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "creditcard.wireless.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(squarePaymentService.isReaderConnected ? .green : .orange)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Card Reader")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(squarePaymentService.connectionStatus)
                            .font(.caption)
                            .foregroundStyle(squarePaymentService.isReaderConnected ? .green : .orange)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.tertiarySystemBackground))
        )
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Subscription Status Card (only show if we have status info)
            if let subscription = subscriptionService.subscriptionStatus {
                SubscriptionStatusCard(
                    status: subscription,
                    onUpgrade: {
                        showingSubscriptionSheet = true
                    }
                )
            }
            
            // Launch Kiosk button with subscription awareness
            launchKioskButton
            
            // Logout button
            logoutButton
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }
    
    @ViewBuilder
    private var launchKioskButton: some View {
        let canLaunch = subscriptionService.subscriptionStatus?.canLaunchKiosk == true
        
        Button(action: {
            Task {
                await launchKioskWithSubscriptionCheck()
            }
        }) {
            HStack {
                Image(systemName: canLaunch ? "play.circle.fill" : "lock.circle.fill")
                    .font(.title3)
                
                Text(canLaunch ? "Launch Kiosk" : "Upgrade to Launch")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: canLaunch ?
                            [Color.green, Color.green.opacity(0.8)] :
                            [Color.orange, Color.orange.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!squareAuthService.isAuthenticated || subscriptionService.isLoading)
        .opacity(squareAuthService.isAuthenticated ? 1.0 : 0.6)
    }
    
    @ViewBuilder
    private var logoutButton: some View {
        Button(action: {
            guard !isProcessingLogout && !isLoggingOut else {
                print("⚠️ Logout already in progress, ignoring tap")
                return
            }
            
            print("🔘 Logout button tapped")
            showLogoutAlert = true
        }) {
            HStack {
                Image(systemName: "arrow.right.square.fill")
                    .font(.title3)
                
                Text(isProcessingLogout ? "Processing..." : "Logout")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.tertiarySystemBackground))
            .foregroundStyle(.red)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(isProcessingLogout ? 0.6 : 1.0)
        }
        .disabled(isProcessingLogout || isLoggingOut)
    }
    
    @ViewBuilder
    private var detailView: some View {
        Group {
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
                    EmptyDetailView()
                }
            } else {
                QuickSetupDetailView()
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Methods
    
    private func initiateLogoutProcess() {
        print("🔄 Starting logout process...")
        
        NotificationCenter.default.post(name: NSNotification.Name("ExplicitLogoutInitiated"), object: nil)
        
        DispatchQueue.main.async {
            guard !self.isLoggingOut else {
                print("⚠️ Already logging out, skipping duplicate request")
                return
            }
            
            self.isLoggingOut = true
            self.isProcessingLogout = true
            
            Task {
                await self.performLogoutSequence()
            }
        }
    }
        
    @MainActor
    private func performLogoutSequence() async {
        print("🔄 Performing logout sequence...")
        
        squareReaderService.stopMonitoring()
        donationViewModel.resetDonation()
        squareAuthService.clearLocalAuthData()
        
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        self.isLoggingOut = false
        self.isProcessingLogout = false
        
        print("🌐 Attempting server disconnect...")
        squareAuthService.disconnectFromServer { success in
            print("🌐 Server disconnect result: \(success)")
        }
        
        if squarePaymentService.isSDKAuthorized() {
            print("🔐 Deauthorizing Square SDK...")
            squarePaymentService.deauthorizeSDK {
                print("✅ SDK deauthorization complete")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.squareAuthService.resetLogoutFlags()
                }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.squareAuthService.resetLogoutFlags()
            }
        }
        
        print("✅ Logout process complete!")
    }

    private func launchKioskWithSubscriptionCheck() async {
        // 🔧 FIX: Use the current auth service to create a fresh subscription service
        let currentSubscriptionService = SubscriptionService(authService: squareAuthService)
        let hasAccess = await currentSubscriptionService.canLaunchKiosk()
        
        if hasAccess {
            kioskStore.updateDonationViewModel(donationViewModel)
            isInAdminMode = false
        } else {
            showingSubscriptionSheet = true
        }
    }
}

// MARK: - Supporting Views

struct AdminNavItem: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.blue)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.tertiary)
            
            Text("Select a setting")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            
            Text("Choose an option from the sidebar to get started")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

struct LogoutOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.2)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                VStack(spacing: 8) {
                    Text("Logging out...")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Cleaning up your session")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
            )
            .shadow(radius: 20)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: true)
    }
}

struct QuickSetupDetailView: View {
    @State private var showingGuidedSetup = false
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 64))
                    .foregroundColor(.blue.opacity(0.6))
                
                VStack(spacing: 12) {
                    Text("Welcome to Your Admin Dashboard")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Get started quickly with our guided setup, or choose a specific setting from the sidebar to customize your donation kiosk.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                }
                
                Button(action: {
                    showingGuidedSetup = true
                }) {
                    Text("Start Quick Setup")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color.green, Color.blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(PlainButtonStyle())
                .frame(maxWidth: 300)
            }
            
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showingGuidedSetup) {
            GuidedSetupView()
        }
    }
}

// Preview
struct AdminDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        let authService = SquareAuthService()
        let catalogService = SquareCatalogService(authService: authService)
        let paymentService = SquarePaymentService(authService: authService, catalogService: catalogService)
        let readerService = SquareReaderService(authService: authService)

        return AdminDashboardView()
            .environmentObject(OrganizationStore())
            .environmentObject(KioskStore())
            .environmentObject(DonationViewModel())
            .environmentObject(authService)
            .environmentObject(catalogService)
            .environmentObject(paymentService)
            .environmentObject(readerService)
            .onAppear {
                // Set up any mock data for preview if needed
            }
    }
}
