import SwiftUI

struct UpdatedCustomAmountView: View {
    @EnvironmentObject var kioskStore: KioskStore
    @EnvironmentObject var donationViewModel: DonationViewModel
    @EnvironmentObject var squareAuthService: SquareAuthService
    @EnvironmentObject var paymentService: SquarePaymentService // Add payment service
    @Environment(\.dismiss) private var dismiss
    @State private var amountString: String = ""
    @State private var errorMessage: String? = nil
    @State private var shakeOffset: CGFloat = 0
    @State private var navigateToHome = false
    
    // NEW: Add payment processing states
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
    @State private var selectedAmount: Double = 0
    
    // Callback for when amount is selected (keeping for compatibility)
    var onAmountSelected: (Double) -> Void
    
    var body: some View {
        ZStack {
            // Background image
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
            
            Color.black.opacity(0.55)
                .edgesIgnoringSafeArea(.all)
            
            // CONSISTENT: Same layout structure as other views
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: KioskLayoutConstants.topContentOffset)
                
                // Amount display
                Text("$\(amountString.isEmpty ? "0" : amountString)")
                    .font(.system(size: 65, weight: .bold))
                    .foregroundColor(.white)
                    .offset(x: shakeOffset)
                    .animation(.easeInOut(duration: 0.1), value: shakeOffset)
                
                Spacer()
                    .frame(height: 20)
                
                // Error message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.7))
                        .cornerRadius(10)
                        .transition(.opacity)
                }
                
                Spacer()
                    .frame(height: 30)
                
                // Keypad
                VStack(spacing: 12) {
                    // Row 1
                    HStack(spacing: 12) {
                        ForEach(1...3, id: \.self) { num in
                            KeypadButton(number: num, letters: num == 2 ? "ABC" : num == 3 ? "DEF" : "") {
                                handleNumberPress(String(num))
                            }
                        }
                    }
                    
                    // Row 2
                    HStack(spacing: 12) {
                        ForEach(4...6, id: \.self) { num in
                            KeypadButton(number: num, letters: num == 4 ? "GHI" : num == 5 ? "JKL" : "MNO") {
                                handleNumberPress(String(num))
                            }
                        }
                    }
                    
                    // Row 3
                    HStack(spacing: 12) {
                        ForEach(7...9, id: \.self) { num in
                            KeypadButton(number: num, letters: num == 7 ? "PQRS" : num == 8 ? "TUV" : "WXYZ") {
                                handleNumberPress(String(num))
                            }
                        }
                    }
                    
                    // Row 4
                    HStack(spacing: 12) {
                        // Delete button
                        Button(action: handleDelete) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 64)
                                
                                Image(systemName: "delete.left")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                            }
                        }
                        
                        // 0 button
                        KeypadButton(number: 0, letters: "") {
                            handleNumberPress("0")
                        }
                        
                        // CHANGED: Process Payment button instead of Next
                        Button(action: {
                            handleDone()
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.green.opacity(0.8))
                                    .frame(height: 64)
                                
                                if isProcessingPayment {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "creditcard")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .disabled(isProcessingPayment)
                    }
                }
                .frame(maxWidth: KioskLayoutConstants.maxContentWidth)
                .padding(.horizontal, KioskLayoutConstants.contentHorizontalPadding)
                
                Spacer()
                    .frame(height: KioskLayoutConstants.bottomSafeArea)
            }
            
            // NEW: Payment processing overlay
            if isProcessingPayment {
                paymentProcessingOverlay
            }
            
            // NEW: Success overlay
            if showingThankYou {
                thankYouOverlay
            }
            
            // NEW: Receipt prompt overlay
            if showingReceiptPrompt {
                receiptPromptOverlay
            }
            
            // NEW: Email entry overlay
            if showingEmailEntry {
                emailEntryOverlay
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Circle().fill(Color.white.opacity(0.2)))
                }
            }
        }
        .onAppear {
            print("📱 UpdatedCustomAmountView appeared")
            
            // Connect to reader if not already connected
            if !paymentService.isReaderConnected {
                paymentService.connectToReader()
            }
        }
        .onDisappear {
            print("📱 UpdatedCustomAmountView disappeared")
        }
        .navigationDestination(isPresented: $navigateToHome) {
            HomeView()
                .navigationBarBackButtonHidden(true)
        }
        .sheet(isPresented: $showingSquareAuth) {
            SquareAuthorizationView()
        }
        // NEW: Monitor payment processing
        .onReceive(paymentService.$isProcessingPayment) { processing in
            if !processing && isProcessingPayment {
                // Payment finished - but let the completion handler deal with the result
                // Don't immediately handle the result here to avoid interfering with Square UI
                print("🔄 Payment processing state changed to: \(processing)")
            }
        }
    }
    
    // NEW: Payment processing overlay
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
    
    // NEW: Thank you overlay
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
    
    // NEW: Receipt prompt overlay
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
    
    // NEW: Email entry overlay
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
    
    private func handleNumberPress(_ num: String) {
        let maxDigits = 7
        
        // Prevent leading zeros
        if amountString.isEmpty && num == "0" {
            return
        }
        
        // Check if adding this number would exceed maximum
        let tempAmount = amountString + num
        if let amount = Double(tempAmount),
           let maxAmount = Double(kioskStore.maxAmount) {
            if amount > maxAmount {
                withAnimation(.easeInOut(duration: 0.3)) {
                    errorMessage = "Maximum amount is $\(Int(maxAmount))"
                }
                
                // Clear error after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        errorMessage = nil
                    }
                }
                return
            }
        }
        
        // Add the number if under max digits
        if amountString.count < maxDigits {
            amountString += num
            print("💰 Amount updated to: \(amountString)")
        }
        
        // Clear any existing error (with animation)
        if errorMessage != nil {
            withAnimation(.easeInOut(duration: 0.3)) {
                errorMessage = nil
            }
        }
        
        // Modern haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func handleDelete() {
        if !amountString.isEmpty {
            amountString.removeLast()
            print("🗑️ Amount after delete: \(amountString)")
        }
        
        // Clear any existing error (with animation)
        if errorMessage != nil {
            withAnimation(.easeInOut(duration: 0.3)) {
                errorMessage = nil
            }
        }
        
        // Modern haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    // CHANGED: Process payment immediately instead of navigating to checkout
    private func handleDone() {
        print("✅ handleDone called with amountString: '\(amountString)'")
        
        // Convert amount to Double
        guard let amount = Double(amountString), amount > 0 else {
            // Cute shake animation for $0 or empty amount! 🎯
            if amountString.isEmpty {
                print("💫 Triggering cute shake animation for $0")
                withAnimation(.interpolatingSpring(stiffness: 600, damping: 5)) {
                    shakeAmount()
                }
                
                // Add a playful haptic pattern
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    impactFeedback.impactOccurred()
                }
                
                return // Don't show error message, just the cute shake
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    errorMessage = "Please enter a valid amount"
                }
            }
            print("❌ Invalid amount entered: '\(amountString)'")
            return
        }
        
        // Check minimum amount
        if let minAmount = Double(kioskStore.minAmount), amount < minAmount {
            withAnimation(.easeInOut(duration: 0.3)) {
                errorMessage = "Minimum amount is $\(Int(minAmount))"
            }
            print("❌ Amount below minimum: \(amount) < \(minAmount)")
            return
        }
        
        // Check maximum amount
        if let maxAmount = Double(kioskStore.maxAmount), amount > maxAmount {
            withAnimation(.easeInOut(duration: 0.3)) {
                errorMessage = "Maximum amount is $\(Int(maxAmount))"
            }
            print("❌ Amount above maximum: \(amount) > \(maxAmount)")
            return
        }
        
        print("✅ Valid amount entered: $\(amount)")
        print("🚀 Processing payment immediately...")
        
        // Modern haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Store amount and process payment immediately
        selectedAmount = amount
        donationViewModel.selectedAmount = amount
        donationViewModel.isCustomAmount = true
        
        // Call the original callback for compatibility
        onAmountSelected(amount)
        
        // Process payment immediately
        processPayment(amount: amount, isCustomAmount: true)
    }
    
    // NEW: Process payment method
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
        
        // Use the unified payment processing method from SquarePaymentService
        paymentService.processPayment(
            amount: amount,
            orderId: nil,
            isCustomAmount: isCustomAmount,
            catalogItemId: nil, // Custom amounts don't have catalog items
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
                    // Reset state but stay on this screen so user can try again or go back
                    self.resetPaymentState()
                    
                    // Clear the amount string so user can enter a new amount
                    self.amountString = ""
                }
            }
        }
    }
    
    // NEW: Silent handling of payment failures/cancellations
    private func handleSilentFailureOrCancellation() {
        print("🔇 Payment failed or cancelled - silently navigating to home")
        
        // Clear any error state
        paymentService.paymentError = nil
        
        // Reset payment state
        resetPaymentState()
        
        // Navigate directly to home
        navigateToHome = true
    }
    
    private func handleSuccessfulCompletion() {
        print("✅ Payment completed successfully - returning to home")
        resetPaymentState()
        navigateToHome = true
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
    
    // NEW: Email validation
    private func validateEmail(_ email: String) {
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        isEmailValid = emailPredicate.evaluate(with: email)
    }
    
    // NEW: Send receipt
    private func sendReceipt() {
        guard isEmailValid && !emailAddress.isEmpty else { return }
        
        isSendingReceipt = true
        print("📧 Sending receipt to: \(emailAddress)")
        print("📧 Order ID: \(orderId ?? "N/A")")
        print("📧 Payment ID: \(paymentId ?? "N/A")")
        print("📧 Amount: $\(selectedAmount)")
        
        // TODO: Implement actual receipt sending with SendGrid
        // For now, simulate sending delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isSendingReceipt = false
            self.showEmailSuccessAndComplete()
        }
    }
    
    // NEW: Show email success and complete
    private func showEmailSuccessAndComplete() {
        showingEmailEntry = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.handleSuccessfulCompletion()
        }
    }
    
    // MARK: - Cute shake animation helper
    private func shakeAmount() {
        let shakeSequence: [CGFloat] = [0, -8, 8, -6, 6, -4, 4, -2, 2, 0]
        
        for (index, offset) in shakeSequence.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
                shakeOffset = offset
            }
        }
    }
}

// MARK: - Keypad Button Component (old design with modern touch feedback)

struct KeypadButton: View {
    let number: Int
    let letters: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            // Modern haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            action()
        }) {
            VStack(spacing: 2) {
                Text("\(number)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                if !letters.isEmpty {
                    Text(letters)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.2))
            )
        }
        .buttonStyle(KeypadButtonStyle())
    }
}

// MARK: - Modern Button Style

struct KeypadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

struct UpdatedCustomAmountView_Previews: PreviewProvider {
    static var previews: some View {
        UpdatedCustomAmountView { amount in
            print("Preview: Selected amount \(amount)")
        }
        .environmentObject(KioskStore())
        .environmentObject(DonationViewModel())
        .environmentObject(SquareAuthService())
        .environmentObject(SquarePaymentService(authService: SquareAuthService(), catalogService: SquareCatalogService(authService: SquareAuthService())))
    }
}
