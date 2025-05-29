import SwiftUI

struct PresetAmountsView: View {
    @EnvironmentObject private var kioskStore: KioskStore
    @EnvironmentObject private var squareAuthService: SquareAuthService
    @EnvironmentObject private var catalogService: SquareCatalogService
    
    @State private var allowCustomAmount: Bool = true
    @State private var minAmount: String = "1"
    @State private var maxAmount: String = "100000"
    @State private var isDirty = false
    @State private var isSaving = false
    @State private var showToast = false
    @State private var toastMessage = "Settings saved successfully"
    @State private var showingAuthSheet = false
    @State private var showingAddAmountSheet = false
    @State private var newAmountString = ""
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Page header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        
                        Text("Donation Amounts")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        // Unsaved changes indicator
                        if isDirty {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(.orange)
                                    .frame(width: 8, height: 8)
                                
                                Text("Unsaved Changes")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.orange)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(.orange.opacity(0.1))
                            )
                        }
                    }
                    
                    Text("Configure preset amounts and custom donation limits")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                // Square connection status
                if !squareAuthService.isAuthenticated {
                    ConnectionStatusCard(
                        isConnected: false,
                        onConnect: { showingAuthSheet = true }
                    )
                    .padding(.horizontal, 24)
                } else {
                    ConnectionStatusCard(
                        isConnected: true,
                        isSyncing: kioskStore.isSyncingWithCatalog,
                        lastSyncTime: kioskStore.lastSyncTime,
                        syncError: kioskStore.lastSyncError
                    )
                    .padding(.horizontal, 24)
                }
                
                // Main content
                VStack(spacing: 20) {
                    // Preset Amounts Card
                    SettingsCard(title: "Preset Amounts", icon: "grid.circle.fill") {
                        VStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Set up to 6 preset donation amounts for quick selection")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                if squareAuthService.isAuthenticated {
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                            .font(.caption)
                                        
                                        Text("Amounts will sync with your Square catalog automatically")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            
                            // Preset amounts grid
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                                ForEach(Array(kioskStore.presetDonations.enumerated()), id: \.offset) { index, donation in
                                    PresetAmountCard(
                                        donation: donation,
                                        index: index,
                                        isAuthenticated: squareAuthService.isAuthenticated,
                                        onAmountChange: { newAmount in
                                            kioskStore.updatePresetDonation(at: index, amount: newAmount)
                                            isDirty = true
                                        },
                                        onRemove: {
                                            kioskStore.removePresetDonation(at: index)
                                            isDirty = true
                                        },
                                        canRemove: kioskStore.presetDonations.count > 1
                                    )
                                }
                                
                                // Add new amount button
                                if kioskStore.presetDonations.count < 6 {
                                    AddAmountCard {
                                        showingAddAmountSheet = true
                                    }
                                }
                            }
                        }
                    }
                    
                    // Custom Amount Settings Card
                    SettingsCard(title: "Custom Amount Settings", icon: "textfield.fill") {
                        VStack(spacing: 24) {
                            // Toggle for custom amounts
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Allow Custom Amounts")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text("Let donors enter their own amount")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: $allowCustomAmount)
                                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                                    .onChange(of: allowCustomAmount) { _, _ in
                                        isDirty = true
                                    }
                            }
                            
                            if allowCustomAmount {
                                VStack(spacing: 16) {
                                    Divider()
                                    
                                    // Min/Max amount settings
                                    HStack(spacing: 16) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Minimum Amount")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            
                                            HStack(spacing: 8) {
                                                Text("$")
                                                    .foregroundStyle(.secondary)
                                                    .font(.subheadline)
                                                
                                                TextField("1", text: $minAmount)
                                                    .keyboardType(.numberPad)
                                                    .textFieldStyle(ModernTextFieldStyle())
                                                    .onChange(of: minAmount) { _, _ in
                                                        isDirty = true
                                                    }
                                            }
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Maximum Amount")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            
                                            HStack(spacing: 8) {
                                                Text("$")
                                                    .foregroundStyle(.secondary)
                                                    .font(.subheadline)
                                                
                                                TextField("1000", text: $maxAmount)
                                                    .keyboardType(.numberPad)
                                                    .textFieldStyle(ModernTextFieldStyle())
                                                    .onChange(of: maxAmount) { _, _ in
                                                        isDirty = true
                                                    }
                                            }
                                        }
                                    }
                                    
                                    Text("These limits apply when donors choose to enter a custom amount")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                
                // Save button
                if isDirty {
                    Button(action: saveSettings) {
                        HStack {
                            if isSaving || kioskStore.isSyncingWithCatalog {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.9)
                                
                                Text(kioskStore.isSyncingWithCatalog ? "Syncing with Square..." : "Saving...")
                            } else {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .semibold))
                                
                                Text("Save Changes")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(isSaving || kioskStore.isSyncingWithCatalog)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            loadSettings()
            kioskStore.connectCatalogService(catalogService)
            
            if squareAuthService.isAuthenticated {
                catalogService.fetchPresetDonations()
            }
        }
        .onChange(of: squareAuthService.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                catalogService.fetchPresetDonations()
            }
        }
        .sheet(isPresented: $showingAuthSheet) {
            SquareAuthorizationView()
        }
        .sheet(isPresented: $showingAddAmountSheet) {
            AddAmountSheet(
                newAmountString: $newAmountString,
                isPresented: $showingAddAmountSheet,
                onAdd: { amount in
                    kioskStore.addPresetDonation(amount: amount)
                    isDirty = true
                },
                onError: { message in
                    toastMessage = message
                    showToast = true
                }
            )
        }
        .overlay(alignment: .top) {
            if showToast {
                ToastNotification(message: toastMessage)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showToast)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showToast = false
                        }
                    }
            }
        }
    }
    
    // MARK: - Functions (unchanged functionality)
    
    func loadSettings() {
        allowCustomAmount = kioskStore.allowCustomAmount
        minAmount = kioskStore.minAmount
        maxAmount = kioskStore.maxAmount
        isDirty = false
    }
    
    func saveSettings() {
        isSaving = true
        
        kioskStore.allowCustomAmount = allowCustomAmount
        kioskStore.minAmount = minAmount
        kioskStore.maxAmount = maxAmount
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            kioskStore.saveSettings()
            isSaving = false
            isDirty = false
            toastMessage = "Settings saved successfully"
            showToast = true
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views

struct ConnectionStatusCard: View {
    let isConnected: Bool
    var isSyncing: Bool = false
    var lastSyncTime: Date? = nil
    var syncError: String? = nil
    var onConnect: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isConnected ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                if isSyncing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: isConnected ? .green : .red))
                        .scaleEffect(0.8)
                } else {
                    Circle()
                        .fill(isConnected ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Square Integration")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    if !isConnected {
                        Button("Connect") {
                            onConnect?()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }
                
                if isConnected {
                    if isSyncing {
                        Text("Syncing preset amounts...")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    } else if let error = syncError {
                        Text("Sync error: \(error)")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else if let lastSync = lastSyncTime {
                        Text("Last synced: \(formatDate(lastSync))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Connected and ready")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                } else {
                    Text("Connect to Square to sync preset amounts with your catalog")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct PresetAmountCard: View {
    let donation: PresetDonation
    let index: Int
    let isAuthenticated: Bool
    let onAmountChange: (String) -> Void
    let onRemove: () -> Void
    let canRemove: Bool
    
    @State private var amountText: String = ""
    @State private var isEditing: Bool = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("$")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                        
                        if isEditing {
                            TextField("Amount", text: $amountText)
                                .keyboardType(.numberPad)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .onSubmit {
                                    submitAmount()
                                }
                        } else {
                            Text(donation.amount)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .onTapGesture {
                                    startEditing()
                                }
                        }
                    }
                    
                    // Sync status indicator
                    HStack(spacing: 6) {
                        if isAuthenticated {
                            Image(systemName: donation.isSync ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(donation.isSync ? .green : .orange)
                            
                            Text(donation.isSync ? "Synced" : "Not synced")
                                .font(.caption)
                                .foregroundStyle(donation.isSync ? .green : .orange)
                        } else {
                            Text("Preset #\(index + 1)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                if canRemove {
                    Button(action: onRemove) {
                        Image(systemName: "trash.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(8)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            amountText = donation.amount
        }
    }
    
    private func startEditing() {
        amountText = donation.amount
        isEditing = true
    }
    
    private func submitAmount() {
        if !amountText.isEmpty, Double(amountText) != nil {
            onAmountChange(amountText)
        } else {
            amountText = donation.amount
        }
        isEditing = false
    }
}

struct AddAmountCard: View {
    let onAdd: () -> Void
    
    var body: some View {
        Button(action: onAdd) {
            VStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                Text("Add Amount")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AddAmountSheet: View {
    @Binding var newAmountString: String
    @Binding var isPresented: Bool
    let onAdd: (String) -> Void
    let onError: (String) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Add Preset Amount")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Enter a donation amount that will appear as a quick-select option")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Text("$")
                            .font(.title)
                            .foregroundStyle(.secondary)
                        
                        TextField("0", text: $newAmountString)
                            .font(.title)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .textFieldStyle(ModernTextFieldStyle())
                    }
                    
                    Text("Minimum $1 • Maximum $10,000")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button("Add Amount") {
                        if let amount = Double(newAmountString), amount > 0 {
                            onAdd(newAmountString)
                            newAmountString = ""
                            isPresented = false
                        } else {
                            onError("Please enter a valid amount")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(newAmountString.isEmpty || Double(newAmountString) == nil)
                    
                    Button("Cancel") {
                        newAmountString = ""
                        isPresented = false
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding(24)
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Page-Specific Components

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct PresetAmountsView_Previews: PreviewProvider {
    static var previews: some View {
        PresetAmountsView()
            .environmentObject(KioskStore())
            .environmentObject(SquareAuthService())
            .environmentObject(SquareCatalogService(authService: SquareAuthService()))
    }
}
