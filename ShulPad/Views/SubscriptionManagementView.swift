// Views/SubscriptionManagementView.swift
import SwiftUI

struct SubscriptionManagementView: View {
    @ObservedObject var subscriptionService: SubscriptionService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPlan: String = "monthly"
    @State private var deviceCount: Int = 1
    @State private var customerEmail: String = ""
    @State private var promoCode: String = ""
    @State private var isCreatingSubscription = false
    
    // Real payment collection
    @StateObject private var paymentCollectionService: SquarePaymentCollectionService
    @State private var currentStep: SubscriptionStep = .planSelection
    @State private var collectedCardID: String? = nil
    
    enum SubscriptionStep {
        case planSelection
        case paymentCollection
        case processing
    }
    
    init(subscriptionService: SubscriptionService, authService: SquareAuthService) {
        self.subscriptionService = subscriptionService
        self._paymentCollectionService = StateObject(wrappedValue: SquarePaymentCollectionService(authService: authService))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Choose Your Plan")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Start with a 30-day free trial")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Step Indicator
                    StepIndicatorView(currentStep: currentStep)
                    
                    // Current Status (if any)
                    if let status = subscriptionService.subscriptionStatus,
                       status.hasSubscription {
                        CurrentSubscriptionCard(status: status)
                    }
                    
                    // Content based on current step
                    switch currentStep {
                    case .planSelection:
                        planSelectionContent
                    case .paymentCollection:
                        paymentCollectionContent
                    case .processing:
                        processingContent
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Error", isPresented: .constant(subscriptionService.error != nil || paymentCollectionService.paymentError != nil)) {
            Button("OK") {
                subscriptionService.error = nil
                paymentCollectionService.paymentError = nil
            }
        } message: {
            Text(subscriptionService.error ?? paymentCollectionService.paymentError ?? "")
        }
    }
    
    // MARK: - Plan Selection Content
    
    @ViewBuilder
    private var planSelectionContent: some View {
        // Plan Selection
        PlanSelectionView(selectedPlan: $selectedPlan)
        
        // Device Count
        DeviceCountSelector(deviceCount: $deviceCount, selectedPlan: selectedPlan)
        
        // Email Input
        VStack(alignment: .leading, spacing: 8) {
            Text("Email Address")
                .font(.headline)
            
            TextField("your@email.com", text: $customerEmail)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
        }
        
        // Promo Code
        VStack(alignment: .leading, spacing: 8) {
            Text("Promo Code (Optional)")
                .font(.headline)
            
            TextField("Enter promo code", text: $promoCode)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.allCharacters)
            
            Text("Try: LEGACY30FREE for existing users")
                .font(.caption)
                .foregroundColor(.blue)
        }
        
        // Total Price Summary
        PriceSummaryView(selectedPlan: selectedPlan, deviceCount: deviceCount)
        
        // Continue to Payment Button
        Button(action: proceedToPayment) {
            HStack {
                Text("Continue to Payment")
                    .fontWeight(.semibold)
                
                Image(systemName: "arrow.right")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.blue, Color.blue.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(customerEmail.isEmpty)
        .opacity(customerEmail.isEmpty ? 0.6 : 1.0)
        
        // Terms
        Text("By starting your trial, you agree to our Terms of Service. You won't be charged until your trial ends.")
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
    }
    
    // MARK: - Payment Collection Content
    
    @ViewBuilder
    private var paymentCollectionContent: some View {
        VStack(spacing: 24) {
            // Payment instruction
            VStack(spacing: 12) {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                Text("Add Payment Method")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("We need a payment method for when your free trial ends. You won't be charged today.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Selected plan summary
            VStack(spacing: 12) {
                HStack {
                    Text("Selected Plan")
                        .font(.headline)
                    Spacer()
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(selectedPlan.capitalized) Plan")
                            .fontWeight(.semibold)
                        Text("\(deviceCount) device(s)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("30 days free")
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                        Text("then \(formatPrice())")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Real card collection button
            Button(action: collectPaymentMethod) {
                HStack {
                    if paymentCollectionService.isCollectingPayment {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "creditcard.fill")
                    }
                    
                    Text(paymentCollectionService.isCollectingPayment ? "Processing..." : "Add Credit Card")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(paymentCollectionService.isCollectingPayment)
            
            // Show collected card info if available
            if let cardID = collectedCardID {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Payment method added successfully")
                        .font(.subheadline)
                    Spacer()
                }
                .padding(12)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Create subscription button
                Button(action: createSubscriptionWithCard) {
                    Text("Start Free Trial")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            // Back button
            Button(action: { currentStep = .planSelection }) {
                HStack {
                    Image(systemName: "arrow.left")
                    Text("Back to Plan Selection")
                }
                .foregroundColor(.blue)
            }
        }
    }
    
    // MARK: - Processing Content
    
    @ViewBuilder
    private var processingContent: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Creating your subscription...")
                .font(.headline)
            
            Text("This may take a few moments")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    // MARK: - Helper Methods
    
    private func proceedToPayment() {
        currentStep = .paymentCollection
    }
    
    private func collectPaymentMethod() {
        // Get the presenting view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            paymentCollectionService.paymentError = "Unable to present payment form"
            return
        }
        
        Task {
            let cardID = await paymentCollectionService.collectPaymentMethod(presentingViewController: rootViewController)
            
            await MainActor.run {
                if let cardID = cardID {
                    self.collectedCardID = cardID
                    print("✅ Successfully collected card ID: \(cardID)")
                } else {
                    print("❌ Failed to collect payment method")
                }
            }
        }
    }
    
    private func createSubscriptionWithCard() {
        guard let cardID = collectedCardID else {
            paymentCollectionService.paymentError = "No payment method available"
            return
        }
        
        currentStep = .processing
        
        Task {
            let success = await subscriptionService.createSubscription(
                planType: selectedPlan,
                deviceCount: deviceCount,
                customerEmail: customerEmail,
                promoCode: promoCode.isEmpty ? nil : promoCode,
                cardId: cardID
            )
            
            await MainActor.run {
                if success {
                    dismiss()
                } else {
                    currentStep = .paymentCollection
                }
            }
        }
    }
    
    private func formatPrice() -> String {
        let basePrice = selectedPlan == "monthly" ? 49.0 : 490.0
        let extraPrice = selectedPlan == "monthly" ? 15.0 : 150.0
        let total = basePrice + (Double(deviceCount - 1) * extraPrice)
        let period = selectedPlan == "monthly" ? "month" : "year"
        return "$\(String(format: "%.0f", total))/\(period)"
    }
}

// MARK: - Step Indicator (same as before)

struct StepIndicatorView: View {
    let currentStep: SubscriptionManagementView.SubscriptionStep
    
    var body: some View {
        HStack(spacing: 0) {
            StepDot(
                number: 1,
                title: "Plan",
                isActive: currentStep == .planSelection,
                isCompleted: stepNumber > 1
            )
            
            StepConnector(isCompleted: stepNumber > 1)
            
            StepDot(
                number: 2,
                title: "Payment",
                isActive: currentStep == .paymentCollection,
                isCompleted: stepNumber > 2
            )
            
            StepConnector(isCompleted: stepNumber > 2)
            
            StepDot(
                number: 3,
                title: "Complete",
                isActive: currentStep == .processing,
                isCompleted: false
            )
        }
        .padding(.horizontal)
    }
    
    private var stepNumber: Int {
        switch currentStep {
        case .planSelection: return 1
        case .paymentCollection: return 2
        case .processing: return 3
        }
    }
}

struct StepDot: View {
    let number: Int
    let title: String
    let isActive: Bool
    let isCompleted: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 32, height: 32)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(number)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(textColor)
                }
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(isActive ? .blue : .secondary)
        }
    }
    
    private var backgroundColor: Color {
        if isCompleted { return .green }
        if isActive { return .blue }
        return Color(.systemGray4)
    }
    
    private var textColor: Color {
        if isActive { return .white }
        return .secondary
    }
}

struct StepConnector: View {
    let isCompleted: Bool
    
    var body: some View {
        Rectangle()
            .fill(isCompleted ? .green : Color(.systemGray4))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
    }
}
