import SwiftUI

struct UpdatedCustomAmountView: View {
    @EnvironmentObject var kioskStore: KioskStore
    @EnvironmentObject var donationViewModel: DonationViewModel
    @EnvironmentObject var squareAuthService: SquareAuthService
    @EnvironmentObject var paymentService: SquarePaymentService
    @Environment(\.dismiss) private var dismiss
    @State private var amountString: String = ""
    @State private var errorMessage: String? = nil
    @State private var shakeOffset: CGFloat = 0
    @State private var navigateToCheckout = false
    @State private var navigateToHome = false
    @State private var selectedAmount: Double = 0
    
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
    
    // Callback for when amount is selected
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
                        
                        // Process Payment button
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
            if !paymentService.isReaderConnected {
                paymentService.connectToReader()
            }
        }
        .navigationDestination(isPresented: $navigateToCheckout) {
            CheckoutView(
                amount: selectedAmount,
                isCustomAmount: true,
                onDismiss: {
                    navigateToCheckout = false
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
        // 🔧 REMOVED: The problematic onReceive that was causing race conditions
        // This was interfering with the completion handler and causing cancelled payments
        // to incorrectly show the thank you screen
    }
    
    // MARK: - UI Overlays
    
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
    
    private var receiptPromptOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
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
    
    private var emailEntryOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
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
        
        if amountString.isEmpty && num == "0" {
            return
        }
        
        let tempAmount = amountString + num
        if let amount = Double(tempAmount),
           let maxAmount = Double(kioskStore.maxAmount) {
            if amount > maxAmount {
                withAnimation(.easeInOut(duration: 0.3)) {
                    errorMessage = "Maximum amount is $\(Int(maxAmount))"
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        errorMessage = nil
                    }
                }
                return
            }
        }
        
        if amountString.count < maxDigits {
            amountString += num
        }
        
        if errorMessage != nil {
            withAnimation(.easeInOut(duration: 0.3)) {
                errorMessage = nil
            }
        }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func handleDelete() {
        if !amountString.isEmpty {
            amountString.removeLast()
        }
        
        if errorMessage != nil {
            withAnimation(.easeInOut(duration: 0.3)) {
                errorMessage = nil
            }
        }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func handleDone() {
        guard !isProcessingPayment else {
            return
        }
        
        guard let amount = Double(amountString), amount > 0 else {
            if amountString.isEmpty {
                withAnimation(.interpolatingSpring(stiffness: 600, damping: 5)) {
                    shakeAmount()
                }
                
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    impactFeedback.impactOccurred()
                }
                
                return
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    errorMessage = "Please enter a valid amount"
                }
            }
            return
        }
        
        if let minAmount = Double(kioskStore.minAmount), amount < minAmount {
            withAnimation(.easeInOut(duration: 0.3)) {
                errorMessage = "Minimum amount is $\(Int(minAmount))"
            }
            return
        }
        
        if let maxAmount = Double(kioskStore.maxAmount), amount > maxAmount {
            withAnimation(.easeInOut(duration: 0.3)) {
                errorMessage = "Maximum amount is $\(Int(maxAmount))"
            }
            return
        }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        selectedAmount = amount
        donationViewModel.selectedAmount = amount
        donationViewModel.isCustomAmount = true
        
        onAmountSelected(amount)
        
        processPayment(amount: amount, isCustomAmount: true)
    }
    
    // 🔧 FIXED: Updated processPayment method to handle cancellations properly
    private func processPayment(amount: Double, isCustomAmount: Bool) {
        if !squareAuthService.isAuthenticated {
            showingSquareAuth = true
            return
        }
        
        if !paymentService.isReaderConnected {
            handleSilentFailureOrCancellation()
            return
        }
        
        resetPaymentState()
        isProcessingPayment = true
        
        paymentService.processPayment(
            amount: amount,
            orderId: nil,
            isCustomAmount: isCustomAmount,
            catalogItemId: nil,
            allowOffline: true
        ) { success, transactionId in
            print("🎯 CustomAmount Completion handler: success=\(success), transactionId=\(transactionId ?? "nil")")
            
            DispatchQueue.main.async {
                // Always reset processing state first
                self.isProcessingPayment = false
                
                if success {
                    print("✅ CustomAmount Success: Recording donation and showing thank you")
                    // Record the donation
                    self.donationViewModel.recordDonation(amount: amount, transactionId: transactionId)
                    self.orderId = self.paymentService.currentOrderId
                    self.paymentId = transactionId
                    
                    // Show success briefly then go home
                    self.showingThankYou = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.handleSuccessfulCompletion()
                    }
                } else {
                    print("❌ CustomAmount Cancelled/Failed: Going back to previous screen")
                    // Payment was cancelled or failed - just go back
                    self.handleSilentFailureOrCancellation()
                }
            }
        }
    }
    
    private func handleNavigateToHome() {
        // Navigate directly to home view
        navigateToHome = true
    }
    
    private func handleSilentFailureOrCancellation() {
        paymentService.paymentError = nil
        resetPaymentState()
        // Use dismiss to go back to DonationSelectionView, then that view will handle going to home
        dismiss()
    }
    
    private func handleSuccessfulCompletion() {
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
    
    private func validateEmail(_ email: String) {
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        isEmailValid = emailPredicate.evaluate(with: email)
    }
    
    private func sendReceipt() {
        guard isEmailValid && !emailAddress.isEmpty else { return }
        
        isSendingReceipt = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isSendingReceipt = false
            self.showEmailSuccessAndComplete()
        }
    }
    
    private func showEmailSuccessAndComplete() {
        showingEmailEntry = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.handleSuccessfulCompletion()
        }
    }
    
    private func shakeAmount() {
        let shakeSequence: [CGFloat] = [0, -8, 8, -6, 6, -4, 4, -2, 2, 0]
        
        for (index, offset) in shakeSequence.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
                shakeOffset = offset
            }
        }
    }
}

// MARK: - Supporting Components

struct KeypadButton: View {
    let number: Int
    let letters: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
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

struct KeypadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}



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
