import SwiftUI

struct DonationSelectionView: View {
    @EnvironmentObject var kioskStore: KioskStore
    @EnvironmentObject var donationViewModel: DonationViewModel
    @EnvironmentObject var squareAuthService: SquareAuthService
    @EnvironmentObject var catalogService: SquareCatalogService
    
    @State private var navigateToCustomAmount = false
    @State private var navigateToCheckout = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        ZStack {
            // Background image
            backgroundImageView
            
            // Dark overlay
            Color.black.opacity(0.55)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 10) {
                Text("Donation Amount")
                    .font(.system(size: horizontalSizeClass == .regular ? 50 : 32, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 170)
                    .padding(.bottom, 30)
                
                VStack(spacing: 16) {
                    // Grid layout for preset amounts - CLEAN, no status indicators
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16) {
                        ForEach(0..<kioskStore.presetDonations.count, id: \.self) { index in
                            presetAmountButton(for: index)
                        }
                    }
                    
                    // Custom amount button
                    if kioskStore.allowCustomAmount {
                        customAmountButton
                    }
                }
                .frame(maxWidth: horizontalSizeClass == .regular ? 800 : 500)
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .onAppear {
            if squareAuthService.isAuthenticated {
                kioskStore.connectCatalogService(catalogService)
                kioskStore.loadPresetDonationsFromCatalog()
            }
            updateDonationViewModel()
        }
        // Navigation to your beautiful custom amount view
        .navigationDestination(isPresented: $navigateToCustomAmount) {
            UpdatedCustomAmountView { amount in
                handleCustomAmountSelection(amount: amount)
            }
        }
        // Navigation to checkout
        .navigationDestination(isPresented: $navigateToCheckout) {
            UpdatedCheckoutView(
                amount: donationViewModel.selectedAmount ?? 0,
                isCustomAmount: donationViewModel.isCustomAmount,
                onDismiss: {
                    handleCheckoutDismiss()
                }
            )
        }
    }
    
    // MARK: - Computed Properties
    
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
                .font(.system(size: horizontalSizeClass == .regular ? 24 : 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: horizontalSizeClass == .regular ? 80 : 60)
                .background(Color.white.opacity(0.3))
                .cornerRadius(15)
        }
        .padding(.top, 10)
    }
    
    // MARK: - Helper Methods
    
    private func presetAmountButton(for index: Int) -> some View {
        let amount = Double(kioskStore.presetDonations[index].amount) ?? 0
        
        return Button(action: {
            handlePresetAmountSelection(amount: amount)
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.white.opacity(0.3))
                
                // CLEAN - just the amount, no status indicators
                Text("$\(Int(amount))")
                    .font(.system(size: horizontalSizeClass == .regular ? 24 : 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(height: horizontalSizeClass == .regular ? 80 : 60)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func handlePresetAmountSelection(amount: Double) {
        donationViewModel.selectedAmount = amount
        donationViewModel.isCustomAmount = false
        navigateToCheckout = true
    }
    
    private func handleCustomAmountButtonPress() {
        donationViewModel.isCustomAmount = true
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
