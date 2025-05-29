// MARK: - Updated CheckoutView with Consistent Layout
import SwiftUI
import SquareMobilePaymentsSDK

struct UpdatedCheckoutView: View {
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
    
    // State
    @State private var showingThankYou = false
    @State private var showingError = false
    @State private var showingSquareAuth = false
    @State private var processingState: ProcessingState = .ready
    @State private var orderId: String? = nil
    @State private var paymentId: String? = nil
    @State private var useOrderBasedFlow = true
    
    // Processing state enum
    enum ProcessingState {
        case ready
        case creatingOrder
        case processingPayment
        case completed
        case error
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
                        onDismiss()
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
            
            // Error overlay
            if showingError {
                errorOverlay
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    onDismiss()
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
        .onReceive(paymentService.$paymentError) { error in
            if error != nil {
                processingState = .error
                showingError = true
            }
        }
        .onReceive(paymentService.$isProcessingPayment) { isProcessing in
            if isProcessing {
                processingState = .processingPayment
            } else if processingState == .processingPayment && !isProcessing {
                if paymentService.paymentError == nil {
                    processingState = .completed
                    showingThankYou = true
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
        case .error:
            return "exclamationmark.circle"
        }
    }
    
    private var buttonText: String {
        switch processingState {
        case .ready:
            return useOrderBasedFlow ? "Process Donation" : "Process Payment"
        case .creatingOrder:
            return "Creating Order..."
        case .processingPayment:
            return "Processing..."
        case .completed:
            return "Completed"
        case .error:
            return "Try Again"
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
        case .error:
            return Color.red
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
                    onDismiss()
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
                onDismiss()
            }
        }
    }
    
    private var errorOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.red)
                
                Text("Payment Failed")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(paymentService.paymentError ?? "Payment processing failed")
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Button("Try Again") {
                    resetPaymentState()
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 10)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.top, 20)
            }
            .padding()
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
    
    private func processPayment() {
        if useOrderBasedFlow {
            processOrderBasedPayment()
        } else {
            processDirectPayment()
        }
    }
    
    private func processOrderBasedPayment() {
        if !squareAuthService.isAuthenticated {
            showingSquareAuth = true
            return
        }
        
        if !paymentService.isReaderConnected {
            paymentService.paymentError = "Card reader not connected. Please contact staff."
            showingError = true
            return
        }
        
        resetPaymentState()
        
        processingState = .creatingOrder
        print("🛒 Starting order-based payment flow for amount: $\(amount)")
        
        kioskStore.createDonationOrder(
            amount: amount,
            isCustomAmount: isCustomAmount
        ) { createdOrderId, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Order creation failed: \(error.localizedDescription)")
                    self.paymentService.paymentError = "Failed to create order: \(error.localizedDescription)"
                    self.processingState = .error
                    self.showingError = true
                    return
                }
                
                guard let createdOrderId = createdOrderId else {
                    print("❌ No order ID returned")
                    self.paymentService.paymentError = "Failed to create order: No order ID returned"
                    self.processingState = .error
                    self.showingError = true
                    return
                }
                
                self.orderId = createdOrderId
                print("✅ Order created successfully: \(createdOrderId)")
                
                self.processingState = .processingPayment
                print("💳 Processing payment with order ID: \(createdOrderId)")
                
                self.paymentService.processPaymentWithOrder(
                    amount: self.amount,
                    orderId: createdOrderId
                ) { success, transactionId in
                    DispatchQueue.main.async {
                        if success {
                            print("✅ Payment successful! Transaction ID: \(transactionId ?? "N/A")")
                            
                            self.donationViewModel.recordDonation(amount: self.amount, transactionId: transactionId)
                            self.paymentId = transactionId
                            self.processingState = .completed
                            self.showingThankYou = true
                        } else {
                            print("❌ Payment failed")
                            self.processingState = .error
                            self.showingError = true
                        }
                    }
                }
            }
        }
    }
    
    private func processDirectPayment() {
        if !squareAuthService.isAuthenticated {
            showingSquareAuth = true
            return
        }
        
        if !paymentService.isReaderConnected {
            paymentService.paymentError = "Card reader not connected. Please contact staff."
            showingError = true
            return
        }
        
        resetPaymentState()
        
        var catalogItemId: String? = nil
        
        if !isCustomAmount {
            if let donation = kioskStore.presetDonations.first(where: { Double($0.amount) == amount }) {
                catalogItemId = donation.catalogItemId
            }
        }
        
        processingState = .processingPayment
        
        paymentService.processPayment(
            amount: amount,
            isCustomAmount: isCustomAmount,
            catalogItemId: catalogItemId
        ) { success, transactionId in
            if success {
                donationViewModel.recordDonation(amount: amount, transactionId: transactionId)
                orderId = paymentService.currentOrderId
                paymentId = transactionId
                processingState = .completed
                showingThankYou = true
            } else {
                processingState = .error
                showingError = true
            }
        }
    }
    
    private func resetPaymentState() {
        processingState = .ready
        showingError = false
        showingThankYou = false
        orderId = nil
        paymentId = nil
    }
}

struct UpdatedCheckoutView_Previews: PreviewProvider {
    static var previews: some View {
        let authService = SquareAuthService()
        let catalogService = SquareCatalogService(authService: authService)
        
        return UpdatedCheckoutView(amount: 50.0, isCustomAmount: false, onDismiss: {})
            .environmentObject(KioskStore())
            .environmentObject(DonationViewModel())
            .environmentObject(authService)
            .environmentObject(catalogService)
            .environmentObject(SquarePaymentService(authService: authService, catalogService: catalogService))
    }
}
