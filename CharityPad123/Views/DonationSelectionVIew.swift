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
        .navigationDestination(isPresented: $navigateToCustomAmount) {
            UpdatedCustomAmountView { amount in
                handleCustomAmountSelection(amount: amount)
            }
        }
        .navigationDestination(isPresented: $navigateToCheckout) {
            CheckoutView(
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
                .font(.system(size: horizontalSizeClass == .regular ? KioskLayoutConstants.buttonFontSize : KioskLayoutConstants.buttonFontSizeCompact, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: horizontalSizeClass == .regular ? KioskLayoutConstants.buttonHeight : KioskLayoutConstants.buttonHeightCompact)
                .background(Color.white.opacity(0.3))
                .cornerRadius(15)
        }
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
                
                Text("$\(Int(amount))")
                    .font(.system(size: horizontalSizeClass == .regular ? KioskLayoutConstants.buttonFontSize : KioskLayoutConstants.buttonFontSizeCompact, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(height: horizontalSizeClass == .regular ? KioskLayoutConstants.buttonHeight : KioskLayoutConstants.buttonHeightCompact)
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
