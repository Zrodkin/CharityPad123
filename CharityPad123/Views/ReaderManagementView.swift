import SwiftUI
import SquareMobilePaymentsSDK

struct ReaderManagementView: View {
    @EnvironmentObject var squareAuthService: SquareAuthService
    @EnvironmentObject var squareReaderService: SquareReaderService
    @State private var showingReaderSettings = false
    @State private var showingPairingAlert = false
    @State private var showingSquareAuth = false
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Page header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "creditcard.wireless.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        
                        Text("Square Reader Management")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                    }
                    
                    Text("Manage your Square card readers for in-person payments")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                // Main content
                VStack(spacing: 20) {
                    // Authentication Status Section
                    authenticationStatusSection
                    
                    if squareAuthService.isAuthenticated {
                        // Readers Section
                        readersSection
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            // Start monitoring for readers when view appears
            squareReaderService.startMonitoring()
            
            // Make sure Square SDK is authorized if we have valid credentials
            if squareAuthService.isAuthenticated {
                squareReaderService.refreshAvailableCardInputMethods()
            }
        }
        .onDisappear {
            // Stop monitoring when view disappears to conserve resources
            squareReaderService.stopMonitoring()
        }
        .sheet(isPresented: $showingSquareAuth) {
            SquareAuthorizationView()
        }
        .alert("Pairing in Progress", isPresented: $showingPairingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Pairing is already in progress. Please wait for the current pairing to complete or cancel it.")
        }
    }
    
    // MARK: - View Components (keeping original functionality, updating design)
    
    private var authenticationStatusSection: some View {
        SettingsCard(title: "Connection Status", icon: "wifi.circle.fill") {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(squareAuthService.isAuthenticated ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Circle()
                        .fill(squareAuthService.isAuthenticated ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(squareAuthService.isAuthenticated ? "Connected to Square" : "Not connected to Square")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(squareAuthService.isAuthenticated ? .green : .red)
                    
                    if !squareAuthService.isAuthenticated {
                        Text("Connect to Square to manage card readers")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if !squareAuthService.isAuthenticated {
                    Button("Connect to Square") {
                        showingSquareAuth = true
                    }
                    .buttonStyle(ModernSecondaryButtonStyle())
                }
            }
        }
    }
    
    private var readersSection: some View {
        VStack(spacing: 16) {
            SettingsCard(title: "Card Readers", icon: "creditcard.wireless.fill") {
                VStack(spacing: 16) {
                    // Show readers list or empty state
                    if squareReaderService.readers.isEmpty {
                        emptyReadersView
                    } else {
                        readersListView
                    }
                    
                    Divider()
                    
                    // Pairing controls
                    pairingControlsView
                    
                    // Show Square's built-in settings UI button
                    Button("Open Square Reader Settings") {
                        showingReaderSettings = true
                    }
                    .buttonStyle(ModernSecondaryButtonStyle())
                    .disabled(!squareAuthService.isAuthenticated)
                }
            }
        }
        .background(
            Color(UIColor.systemBackground)
                .fullScreenCover(isPresented: $showingReaderSettings) {
                    VStack {
                        Text("Square Reader Settings")
                            .font(.headline)
                            .padding()
                        
                        Text("Launching Square's built-in reader management interface...")
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        Button("Close") {
                            showingReaderSettings = false
                        }
                        .padding()
                        .onAppear {
                            // Find the presenting view controller to show Square's native UI
                            if let windowScene = UIApplication.shared.connectedScenes
                                .filter({ $0.activationState == .foregroundActive })
                                .compactMap({ $0 as? UIWindowScene })
                                .first,
                               let rootVC = windowScene.windows.first?.rootViewController {
                                
                                // Find the currently presented view controller
                                var currentVC = rootVC
                                while let presentedVC = currentVC.presentedViewController {
                                    currentVC = presentedVC
                                }
                                
                                // Present the Square reader settings
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    squareReaderService.presentReaderSettings(from: currentVC)
                                    
                                    // Dismiss after a short delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                        showingReaderSettings = false
                                    }
                                }
                            }
                        }
                    }
                }
        )
    }
    
    private var emptyReadersView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(.tertiarySystemBackground))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "creditcard.wireless")
                    .font(.system(size: 36))
                    .foregroundStyle(.tertiary)
            }
            
            VStack(spacing: 8) {
                Text("No readers connected")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Pair a Square reader to process payments")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
    
    private var readersListView: some View {
        VStack(spacing: 12) {
            ForEach(squareReaderService.readers, id: \.serialNumber) { reader in
                ReaderItemView(reader: reader)
                    .environmentObject(squareReaderService)
            }
        }
    }
    
    private var pairingControlsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.blue)
                }
                
                Text("Reader Pairing")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            if squareReaderService.isPairingInProgress {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(0.8)
                        
                        Text(squareReaderService.pairingStatus)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                    
                    Button("Cancel Pairing") {
                        squareReaderService.stopPairing()
                    }
                    .buttonStyle(ModernSecondaryButtonStyle())
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    if let error = squareReaderService.lastPairingError {
                        Text("Error: \(error)")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(12)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    Button("Pair New Reader") {
                        if !squareAuthService.isAuthenticated {
                            showingSquareAuth = true
                            return
                        }
                        
                        if MobilePaymentsSDK.shared.readerManager.isPairingInProgress {
                            showingPairingAlert = true
                            return
                        }
                        
                        squareReaderService.startPairing()
                    }
                    .buttonStyle(ModernPrimaryButtonStyle())
                    .disabled(!squareAuthService.isAuthenticated)
                }
            }
        }
    }
}

struct ReaderItemView: View {
    let reader: ReaderInfo
    @EnvironmentObject var squareReaderService: SquareReaderService
    @State private var showingUnpairAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                // Reader icon based on model
                ZStack {
                    Circle()
                        .fill(stateColor.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: readerIconName(model: reader.model))
                        .font(.title2)
                        .foregroundStyle(stateColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Reader model
                    Text(squareReaderService.readerModelDescription(reader.model))
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    // Serial number
                    Text("S/N: \(String(describing: reader.serialNumber))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // Status badge
                    HStack(spacing: 8) {
                        StatusBadge(text: squareReaderService.readerStateDescription(reader.state), color: stateColor)
                        
                        if squareReaderService.selectedReader?.serialNumber == reader.serialNumber {
                            StatusBadge(text: "Selected", color: .blue)
                        }
                    }
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 8) {
                    if reader.state == .ready {
                        Button("Select Reader") {
                            squareReaderService.selectReader(reader)
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .foregroundColor(.white)
                        .background(Color.blue)
                        .cornerRadius(8)
                        .disabled(reader.state != .ready)
                    }
                    
                    // Only allow forgetting contactless readers
                    if reader.model == .contactlessAndChip {
                        Button("Forget") {
                            showingUnpairAlert = true
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                }
            }
            
            // Battery status if available
            if reader.model == .contactlessAndChip, let batteryStatus = reader.batteryStatus {
                Divider()
                
                HStack(spacing: 12) {
                    Image(systemName: batterySectionView(batteryStatus: batteryStatus))
                        .foregroundColor(batteryLevel(from: batteryStatus.level) <= 0.2 ? .red : (batteryStatus.isCharging ? .green : .gray))
                    
                    Text(squareReaderService.batteryLevelDescription(reader))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
            }
            
            // Display supported payment methods
            Divider()
            
            HStack {
                Text("Accepts:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 6) {
                    PaymentMethodBadge(text: "Tap", isSupported: true)
                    PaymentMethodBadge(text: "Chip", isSupported: true)
                    PaymentMethodBadge(text: "Swipe", isSupported: reader.model != .contactlessAndChip)
                }
                
                Spacer()
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(squareReaderService.selectedReader?.serialNumber == reader.serialNumber ? Color.blue : Color.clear, lineWidth: 2)
        )
        .alert("Forget Reader", isPresented: $showingUnpairAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Forget", role: .destructive) {
                squareReaderService.forgetReader(reader)
            }
        } message: {
            Text("Are you sure you want to unpair this reader? You'll need to pair it again to use it.")
        }
    }
    
    private var stateColor: Color {
        switch reader.state {
        case .ready:
            return .green
        case .connecting:
            return .yellow
        case .updatingFirmware:
            return .blue
        case .failedToConnect, .disconnected:
            return .red
        default:
            // Handle any other cases that might be added in future SDK versions
            return .gray
        }
    }
    
    // Helper function for battery status
    private func batterySectionView(batteryStatus: ReaderBatteryStatus) -> String {
        let level = batteryLevel(from: batteryStatus.level)
        let isCharging = batteryStatus.isCharging
        
        if isCharging {
            return "battery.100.bolt"
        } else {
            let percentage = Int(level * 100)
            if percentage <= 25 {
                return "battery.25"
            } else if percentage <= 50 {
                return "battery.50"
            } else if percentage <= 75 {
                return "battery.75"
            } else {
                return "battery.100"
            }
        }
    }
    
    // Helper function to get battery level as Float
    private func batteryLevel(from level: Any) -> Float {
        if let floatVal = level as? Float {
            return floatVal
        } else if let nsNumber = level as? NSNumber {
            return nsNumber.floatValue
        } else {
            // Default value if conversion fails
            return 0.5
        }
    }
    
    private func readerIconName(model: ReaderModel) -> String {
        switch model {
        case .contactlessAndChip:
            return "creditcard.wireless"
        case .magstripe:
            return "creditcard"
        case .stand:
            return "ipad.and.iphone"
        default:
            // Handle any other cases that might be added in future SDK versions
            return "questionmark.circle"
        }
    }
}

// MARK: - Supporting Components

struct StatusBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

struct PaymentMethodBadge: View {
    let text: String
    let isSupported: Bool
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isSupported ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
            .foregroundStyle(isSupported ? .green : .gray)
            .clipShape(Capsule())
    }
}

struct ModernPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ModernSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.medium)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ReaderManagementView_Previews: PreviewProvider {
    static var previews: some View {
        ReaderManagementView()
            .environmentObject(SquareAuthService())
            .environmentObject(SquareReaderService(authService: SquareAuthService()))
    }
}
