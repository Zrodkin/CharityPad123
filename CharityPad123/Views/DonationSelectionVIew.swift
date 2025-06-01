// Add this to your DonationSelectionView.swift
// Updated to handle custom amount cancellations and navigate to home

import SwiftUI

struct DonationSelectionView: View {
    @EnvironmentObject var kioskStore: KioskStore
    @EnvironmentObject var donationViewModel: DonationViewModel
    @EnvironmentObject var squareAuthService: SquareAuthService
    @EnvironmentObject var catalogService: SquareCatalogService
    @EnvironmentObject var paymentService: SquarePaymentService
    
    @State private var navigateToCustomAmount = false
    @State private var navigateToCheckout = false
    @State private var navigateToHome = false
    
    // NEW: Track if we're returning from custom amount view with cancellation
    @State private var shouldNavigateToHomeOnAppear = false
    
    // Payment processing states
    @State private var isProcessingPayment = false
    @State private var showingSquareAuth = false
    @State private var showingThankYou = false
    @State private var showingReceiptPrompt = false
    @State private var showingEmailEntry = false
    @State private var emailAddress = ""
    @State private var isEmailValid = false
    @State private var isSendingReceipt = false
    @State private var orderId: String? = nil
    @State private var paymentId: String? = nil
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        ZStack {
            backgroundImageView
            
            Color.black.opacity(0.55)
                .edgesIgnoringSafeArea(.all)
            
            // CONSISTENT: Same layout structure as HomeView
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: KioskLayoutConstants.topContentOffset)
                
                // Title
                Text("Donation Amount")
                    .font(.system(size: horizontalSizeClass == .regular ? KioskLayoutConstants.titleFontSize : KioskLayoutConstants.titleFontSizeCompact, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                    .frame(height: KioskLayoutConstants.titleBottomSpacing)
                
                // Content area - buttons
                VStack(spacing: KioskLayoutConstants.buttonSpacing) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: KioskLayoutConstants.buttonSpacing), count: 3), spacing: KioskLayoutConstants.buttonSpacing) {
                        ForEach(0..<kioskStore.presetDonations.count, id: \.self) { index in
                            presetAmountButton(for: index)
                        }
                    }
                    
                    if kioskStore.allowCustomAmount {
                        customAmountButton
                    }
                }
                .frame(maxWidth: KioskLayoutConstants.maxContentWidth)
                .padding(.horizontal, KioskLayoutConstants.contentHorizontalPadding)
                
                Spacer()
                    .frame(height: KioskLayoutConstants.bottomSafeArea)
            }
            
            // Payment processing overlay
            if isProcessingPayment {
                paymentProcessingOverlay
            }
            
            // Success overlay
            if showingThankYou {
                thankYouOverlay
            }
            
            // Receipt prompt overlay
            if showingReceiptPrompt {
                receiptPromptOverlay
            }
            
            // Email entry overlay
            if showingEmailEntry {
                emailEntryOverlay
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .onAppear {
            // 🔧 NEW: Handle navigation to home if returning from cancelled custom amount
            if shouldNavigateToHomeOnAppear {
                shouldNavigateToHomeOnAppear = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    navigateToHome = true
                }
                return
            }
            
            if squareAuthService.isAuthenticated {
                kioskStore.connectCatalogService(catalogService)
                kioskStore.loadPresetDonationsFromCatalog()
            }
            updateDonationViewModel()
            
            // Connect to reader if not already connected
            if !paymentService.isReaderConnected {
                paymentService.connectToReader()
            }
        }
        .navigationDestination(isPresented: $navigateToCustomAmount) {
            UpdatedCustomAmountView { amount in
                handleCustomAmountSelection(amount: amount)
            }
            // 🔧 NEW: Handle when custom amount view is dismissed (cancellation)
            .onDisappear {
                // Check if payment was cancelled/failed and we should go to home
                if donationViewModel.selectedAmount == nil || donationViewModel.selectedAmount == 0 {
                    print("🏠 Custom amount cancelled - setting flag to navigate to home")
                    shouldNavigateToHomeOnAppear = true
                }
            }
        }
        .navigationDestination(isPresented: $navigateToCheckout) {
            CheckoutView(
                amount: donationViewModel.selectedAmount ?? 0,
                isCustomAmount: donationViewModel.isCustomAmount,
                onDismiss: {
                    handleCheckoutDismiss()
                },
                onNavigateToHome: {
                    handleNavigateToHome()
                }
            )
        }
        .navigationDestination(isPresented: $navigateToHome) {
            HomeView()
                .navigationBarBackButtonHidden(true)
        }
        .sheet(isPresented: $showingSquareAuth) {
            SquareAuthorizationView()
        }
        // Monitor payment processing
        .onReceive(paymentService.$isProcessingPayment) { processing in
            if !processing && isProcessingPayment {
                print("🔄 Payment processing state changed to: \(processing)")
            }
        }
    }
    
    // MARK: - Computed Properties (unchanged)
    
    private var backgroundImageView: some View {
        Group {
            if let backgroundImage = kioskStore.backgroundImage {
                Image(uiImage: backgroundImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .edgesIgnoringSafeArea(.all)
                    .blur(radius: 5)
            } else {
                Image("organization-image")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .edgesIgnoringSafeArea(.all)
                    .blur(radius: 5)
            }
        }
    }
    
    private var customAmountButton: some View {
        Button(action: {
            handleCustomAmountButtonPress()
        }) {
            Text("Custom")
                .font(.system(size: horizontalSizeClass == .regular ? KioskLayoutConstants.buttonFontSize : KioskLayoutConstants.buttonFontSizeCompact, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: horizontalSizeClass == .regular ? KioskLayoutConstants.buttonHeight : KioskLayoutConstants.buttonHeightCompact)
                .background(Color.white.opacity(0.3))
                .cornerRadius(15)
        }
    }
    
    // Payment processing overlay (unchanged)
    private var paymentProcessingOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                VStack(spacing: 8) {
                    Text("Processing Payment")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Please follow the prompts on your card reader")
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(40)
        }
    }
    
    // Thank you overlay (unchanged)
    private var thankYouOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.green)
                
                Text("Thank You!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Your donation has been processed.")
                    .foregroundColor(.white)
                
                if let orderId = orderId {
                    Text("Order: \(orderId)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                if let paymentId = paymentId {
                    Text("Payment: \(paymentId)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Button("Done") {
                    showingThankYou = false
                    showingReceiptPrompt = true
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 10)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.top, 20)
            }
            .padding()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if showingThankYou {
                    showingThankYou = false
                    showingReceiptPrompt = true
                }
            }
        }
    }
    
    // Receipt prompt overlay (unchanged)
    private var receiptPromptOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                // Receipt icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                }
                
                VStack(spacing: 16) {
                    Text("Would you like a receipt?")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("We can email you a donation receipt for your tax records")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                VStack(spacing: 16) {
                    // Yes button
                    Button("Yes, send receipt") {
                        showingReceiptPrompt = false
                        showingEmailEntry = true
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .font(.headline)
                    .cornerRadius(12)
                    
                    // No button
                    Button("No thanks") {
                        showingReceiptPrompt = false
                        handleSuccessfulCompletion()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.clear)
                    .foregroundColor(.white)
                    .font(.headline)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    )
                }
                .padding(.horizontal, 40)
            }
            .padding(40)
        }
    }
    
    // Email entry overlay (unchanged)
    private var emailEntryOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                // Email icon
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "at")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(.green)
                }
                
                VStack(spacing: 16) {
                    Text("Enter your email")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("We'll send your donation receipt to this email address")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                // Email input field
                VStack(spacing: 12) {
                    TextField("your.email@example.com", text: $emailAddress)
                        .textFieldStyle(EmailTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: emailAddress) { _, newValue in
                            validateEmail(newValue)
                        }
                    
                    if !emailAddress.isEmpty && !isEmailValid {
                        Text("Please enter a valid email address")
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.horizontal, 40)
                
                VStack(spacing: 16) {
                    // Send button
                    Button(action: sendReceipt) {
                        HStack {
                            if isSendingReceipt {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.9)
                                Text("Sending...")
                            } else {
                                Image(systemName: "paperplane.fill")
                                Text("Send Receipt")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isEmailValid && !isSendingReceipt ? Color.green : Color.gray)
                        .foregroundColor(.white)
                        .font(.headline)
                        .cornerRadius(12)
                    }
                    .disabled(!isEmailValid || isSendingReceipt)
                    
                    // Back button
                    Button("Back") {
                        showingEmailEntry = false
                        showingReceiptPrompt = true
                        emailAddress = ""
                        isEmailValid = false
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.clear)
                    .foregroundColor(.white)
                    .font(.headline)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    )
                    .disabled(isSendingReceipt)
                }
                .padding(.horizontal, 40)
            }
            .padding(40)
        }
    }
    
    // MARK: - Helper Methods
    
    private func presetAmountButton(for index: Int) -> some View {
        let amount = Double(kioskStore.presetDonations[index].amount) ?? 0
        
        return Button(action: {
            // Process payment immediately instead of navigating to checkout
            handlePresetAmountSelection(amount: amount)
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.white.opacity(0.3))
                
                Text("$\(Int(amount))")
                    .font(.system(size: horizontalSizeClass == .regular ? KioskLayoutConstants.buttonFontSize : KioskLayoutConstants.buttonFontSizeCompact, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(height: horizontalSizeClass == .regular ? KioskLayoutConstants.buttonHeight : KioskLayoutConstants.buttonHeightCompact)
        }
        .frame(maxWidth: .infinity)
    }
    
    // Process payment immediately for preset amounts
    private func handlePresetAmountSelection(amount: Double) {
        print("🚀 Preset amount selected: $\(amount) - processing immediately")
        
        donationViewModel.selectedAmount = amount
        donationViewModel.isCustomAmount = false
        
        // Process payment immediately
        processPayment(amount: amount, isCustomAmount: false)
    }
    
    private func handleCustomAmountButtonPress() {
        donationViewModel.isCustomAmount = true
        // 🔧 NEW: Reset the flag before navigating
        shouldNavigateToHomeOnAppear = false
        navigateToCustomAmount = true
    }
    
    private func handleCustomAmountSelection(amount: Double) {
        donationViewModel.selectedAmount = amount
        donationViewModel.isCustomAmount = true
        navigateToCheckout = true
    }
    
    private func handleCheckoutDismiss() {
        navigateToCheckout = false
        donationViewModel.resetDonation()
    }
    
    private func handleNavigateToHome() {
        print("🏠 Navigating to home from DonationSelectionView")
        
        // Reset all navigation states
        navigateToCheckout = false
        navigateToCustomAmount = false
        
        // Reset donation state
        donationViewModel.resetDonation()
        
        // Navigate to home
        navigateToHome = true
    }
    
    // Process payment method (unchanged)
    private func processPayment(amount: Double, isCustomAmount: Bool) {
        // Check authentication
        if !squareAuthService.isAuthenticated {
            showingSquareAuth = true
            return
        }
        
        // Check reader connection - if no reader, silently go back to home
        if !paymentService.isReaderConnected {
            print("🔇 No reader connected - silently navigating to home")
            handleSilentFailureOrCancellation()
            return
        }
        
        resetPaymentState()
        isProcessingPayment = true
        
        print("🚀 Starting payment processing for amount: $\(amount)")
        print("💰 Is custom amount: \(isCustomAmount)")
        
        // Find catalog item ID if this is a preset amount
        var catalogItemId: String? = nil
        if !isCustomAmount {
            if let donation = kioskStore.presetDonations.first(where: { Double($0.amount) == amount }) {
                catalogItemId = donation.catalogItemId
                print("📋 Found catalog item ID: \(catalogItemId ?? "nil")")
            }
        }
        
        // Use the unified payment processing method from SquarePaymentService
        paymentService.processPayment(
            amount: amount,
            orderId: nil,
            isCustomAmount: isCustomAmount,
            catalogItemId: catalogItemId,
            allowOffline: true
        ) { success, transactionId in
            DispatchQueue.main.async {
                // Always reset processing state first
                self.isProcessingPayment = false
                
                if success {
                    print("✅ Payment successful! Transaction ID: \(transactionId ?? "N/A")")
                    
                    // Record the donation
                    self.donationViewModel.recordDonation(amount: amount, transactionId: transactionId)
                    
                    // Store IDs for display
                    self.orderId = self.paymentService.currentOrderId
                    self.paymentId = transactionId
                    
                    // Show success
                    self.showingThankYou = true
                } else {
                    print("🚫 Payment cancelled or failed by user")
                    // Don't navigate away immediately - let user see they're back to selection screen
                    // Reset state but stay on this screen
                    self.resetPaymentState()
                }
            }
        }
    }
    
    // Silent handling of payment failures/cancellations
    private func handleSilentFailureOrCancellation() {
        print("🔇 Payment failed or cancelled - silently navigating to home")
        
        // Clear any error state
        paymentService.paymentError = nil
        
        // Reset payment state
        resetPaymentState()
        
        // Navigate directly to home
        handleNavigateToHome()
    }
    
    private func handleSuccessfulCompletion() {
        print("✅ Payment completed successfully - returning to home")
        resetPaymentState()
        handleNavigateToHome()
    }
    
    private func resetPaymentState() {
        isProcessingPayment = false
        showingThankYou = false
        showingReceiptPrompt = false
        showingEmailEntry = false
        orderId = nil
        paymentId = nil
        emailAddress = ""
        isEmailValid = false
        isSendingReceipt = false
    }
    
    // Email validation (unchanged)
    private func validateEmail(_ email: String) {
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        isEmailValid = emailPredicate.evaluate(with: email)
    }
    
    // Send receipt (unchanged)
    private func sendReceipt() {
        guard isEmailValid && !emailAddress.isEmpty else { return }
        
        isSendingReceipt = true
        print("📧 Sending receipt to: \(emailAddress)")
        print("📧 Order ID: \(orderId ?? "N/A")")
        print("📧 Payment ID: \(paymentId ?? "N/A")")
        print("📧 Amount: \(donationViewModel.selectedAmount ?? 0)")
        
        // TODO: Implement actual receipt sending with SendGrid
        // For now, simulate sending delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isSendingReceipt = false
            self.showEmailSuccessAndComplete()
        }
    }
    
    // Show email success and complete (unchanged)
    private func showEmailSuccessAndComplete() {
        showingEmailEntry = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.handleSuccessfulCompletion()
        }
    }
    
    private func updateDonationViewModel() {
        let amounts = kioskStore.presetDonations.compactMap { Double($0.amount) }
        if !amounts.isEmpty {
            donationViewModel.presetAmounts = amounts
        }
    }
}

struct DonationSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        DonationSelectionView()
            .environmentObject(KioskStore())
            .environmentObject(DonationViewModel())
            .environmentObject(SquareAuthService())
            .environmentObject(SquareCatalogService(authService: SquareAuthService()))
    }
}
