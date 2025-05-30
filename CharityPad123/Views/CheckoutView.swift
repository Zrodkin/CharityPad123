// MARK: - Updated CheckoutView with Silent Cancel to Home
import SwiftUI
import SquareMobilePaymentsSDK

struct CheckoutView: View {
    let amount: Double
    let isCustomAmount: Bool
    
    // Environment objects
    @EnvironmentObject private var kioskStore: KioskStore
    @EnvironmentObject private var donationViewModel: DonationViewModel
    @EnvironmentObject private var squareAuthService: SquareAuthService
    @EnvironmentObject private var catalogService: SquareCatalogService
    @EnvironmentObject private var paymentService: SquarePaymentService
    
    // Navigation via callback function
    var onDismiss: () -> Void
    
    // 🆕 NEW: Add navigation to home callback
    var onNavigateToHome: (() -> Void)? = nil
    
    // State
    @State private var showingThankYou = false
    @State private var showingSquareAuth = false
    @State private var processingState: ProcessingState = .ready
    @State private var orderId: String? = nil
    @State private var paymentId: String? = nil
    
    // 🆕 Receipt functionality
    @State private var showingReceiptPrompt = false
    @State private var showingEmailEntry = false
    @State private var emailAddress = ""
    @State private var isEmailValid = false
    @State private var isSendingReceipt = false
    
    // Processing state enum
    enum ProcessingState {
        case ready
        case creatingOrder
        case processingPayment
        case completed
        // 🗑️ REMOVED: .error state - we don't show errors anymore
    }
    
    var body: some View {
        ZStack {
            // Background
            if let backgroundImage = kioskStore.backgroundImage {
                Image(uiImage: backgroundImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .edgesIgnoringSafeArea(.all)
                    .blur(radius: 5)
            } else {
                Color.blue
                    .edgesIgnoringSafeArea(.all)
            }
            
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
            
            // CONSISTENT: Same layout structure as other kiosk views
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: KioskLayoutConstants.topContentOffset)
                
                // Title
                Text("Donation Amount")
                    .font(.system(size: KioskLayoutConstants.titleFontSize, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                    .frame(height: 20)
                
                // Amount display
                Text(formatAmount(amount))
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                    .frame(height: KioskLayoutConstants.titleBottomSpacing)
                
                // Content area - Status and button
                VStack(spacing: 24) {
                    // Status section
                    statusSection
                    
                    // Process payment button
                    Button(action: processPayment) {
                        HStack {
                            Image(systemName: buttonIcon)
                            Text(buttonText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(buttonColor)
                        )
                        .foregroundColor(.white)
                        .font(.headline)
                    }
                    .disabled(isButtonDisabled)
                    
                    // Cancel button
                    Button("Cancel") {
                        handleCancel()
                    }
                    .foregroundColor(.white)
                    .padding()
                }
                .frame(maxWidth: KioskLayoutConstants.maxContentWidth)
                .padding(.horizontal, KioskLayoutConstants.contentHorizontalPadding)
                
                Spacer()
                    .frame(height: KioskLayoutConstants.bottomSafeArea)
            }
            
            // Success overlay
            if showingThankYou {
                thankYouOverlay
            }
            
            // 🗑️ REMOVED: Error overlay - we don't show errors anymore
            
            // 🆕 Receipt prompt overlay
            if showingReceiptPrompt {
                receiptPromptOverlay
            }
            
            // 🆕 Email entry overlay
            if showingEmailEntry {
                emailEntryOverlay
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    handleCancel()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Circle().fill(Color.white.opacity(0.2)))
                }
            }
        }
        .onAppear {
            print("🎯 CheckoutView appeared - starting payment flow")
            NotificationCenter.default.post(name: NSNotification.Name("PaymentFlowStarted"), object: nil)
            
            if !paymentService.isReaderConnected {
                paymentService.connectToReader()
            }
        }
        .onDisappear {
            print("🎯 CheckoutView disappeared - ending payment flow")
            NotificationCenter.default.post(name: NSNotification.Name("PaymentFlowEnded"), object: nil)
        }
        // 🗑️ REMOVED: Error state monitoring - we don't handle errors in UI anymore
        .onReceive(paymentService.$isProcessingPayment) { isProcessing in
            if isProcessing {
                processingState = .processingPayment
            } else if processingState == .processingPayment && !isProcessing {
                // 🔧 MODIFIED: Check if payment was successful vs cancelled/failed
                if paymentService.paymentError == nil {
                    processingState = .completed
                    showingThankYou = true
                } else {
                    // 🆕 NEW: Silent handling of payment failures/cancellations
                    handleSilentFailureOrCancellation()
                }
            }
        }
        .sheet(isPresented: $showingSquareAuth) {
            SquareAuthorizationView()
        }
    }
    
    // MARK: - Helper Views
    
    private var statusSection: some View {
        VStack(spacing: 12) {
            // Connection status
            HStack {
                Circle()
                    .fill(paymentService.isReaderConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                
                Text(paymentService.isReaderConnected ?
                    "Ready to process payment" :
                    "Card reader not connected. Please contact staff.")
                    .foregroundColor(.white)
            }
            
            // Processing status
            if processingState == .creatingOrder {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Creating order...")
                        .foregroundColor(.white)
                }
            } else if processingState == .processingPayment {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Processing payment...")
                        .foregroundColor(.white)
                }
            }
            
            // Order ID display
            if let orderId = orderId {
                Text("Order: \(orderId)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.vertical)
    }
    
    private var buttonIcon: String {
        switch processingState {
        case .ready:
            return "creditcard"
        case .creatingOrder, .processingPayment:
            return "hourglass"
        case .completed:
            return "checkmark.circle"
        }
    }
    
    private var buttonText: String {
        switch processingState {
        case .ready:
            return "Process Donation"
        case .creatingOrder:
            return "Creating Order..."
        case .processingPayment:
            return "Processing..."
        case .completed:
            return "Completed"
        }
    }
    
    private var buttonColor: Color {
        switch processingState {
        case .ready:
            return Color.blue
        case .creatingOrder, .processingPayment:
            return Color.gray
        case .completed:
            return Color.green
        }
    }
    
    private var isButtonDisabled: Bool {
        return processingState == .creatingOrder ||
               processingState == .processingPayment ||
               processingState == .completed ||
               !paymentService.isReaderConnected
    }
    
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
    
    // 🆕 Receipt prompt overlay
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
    
    // 🆕 Email entry overlay
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
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
    
    private func handleCancel() {
        print("🚫 Payment cancelled by user")
        resetPaymentState()
        onDismiss()
    }
    
    // 🆕 NEW: Silent handling of payment failures/cancellations
    private func handleSilentFailureOrCancellation() {
        print("🔇 Payment failed or cancelled - silently navigating to home")
        
        // Clear any error state
        paymentService.paymentError = nil
        
        // Reset payment state
        resetPaymentState()
        
        // Navigate directly to home without showing any error
        if let onNavigateToHome = onNavigateToHome {
            onNavigateToHome()
        } else {
            // Fallback - dismiss this view
            onDismiss()
        }
    }
    
    private func handleSuccessfulCompletion() {
        print("✅ Payment completed successfully")
        onDismiss()
    }
    
    private func processPayment() {
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
        processingState = .processingPayment
        
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
                if success {
                    print("✅ Payment successful! Transaction ID: \(transactionId ?? "N/A")")
                    
                    // Record the donation
                    self.donationViewModel.recordDonation(amount: self.amount, transactionId: transactionId)
                    
                    // Store IDs for display
                    self.orderId = self.paymentService.currentOrderId
                    self.paymentId = transactionId
                    
                    // Update state
                    self.processingState = .completed
                    self.showingThankYou = true
                } else {
                    print("🔇 Payment failed/cancelled - silently handling")
                    // Don't set any error state, just handle silently
                    self.handleSilentFailureOrCancellation()
                }
            }
        }
    }
    
    private func resetPaymentState() {
        processingState = .ready
        showingThankYou = false
        showingReceiptPrompt = false
        showingEmailEntry = false
        orderId = nil
        paymentId = nil
        emailAddress = ""
        isEmailValid = false
        isSendingReceipt = false
    }
    
    // 🆕 Email validation
    private func validateEmail(_ email: String) {
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        isEmailValid = emailPredicate.evaluate(with: email)
    }
    
    // 🆕 Send receipt (placeholder for backend integration)
    private func sendReceipt() {
        guard isEmailValid && !emailAddress.isEmpty else { return }
        
        isSendingReceipt = true
        print("📧 Sending receipt to: \(emailAddress)")
        print("📧 Order ID: \(orderId ?? "N/A")")
        print("📧 Payment ID: \(paymentId ?? "N/A")")
        print("📧 Amount: $\(amount)")
        
        // TODO: Implement actual receipt sending with SendGrid
        // For now, simulate sending delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isSendingReceipt = false
            self.showEmailSuccessAndComplete()
        }
    }
    
    // 🆕 Show email success and complete
    private func showEmailSuccessAndComplete() {
        showingEmailEntry = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.handleSuccessfulCompletion()
        }
    }
}

// 🆕 Custom text field style for email input
struct EmailTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.title3)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
            )
            .foregroundColor(.black)
    }
}
