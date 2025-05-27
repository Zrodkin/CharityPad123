import SwiftUI
import SquareMobilePaymentsSDK // Ensure this is imported if any Square types are directly used here

@main
struct DonationPadApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - Observable Objects (Services and Stores)
    @StateObject private var authService: SquareAuthService
    @StateObject private var catalogService: SquareCatalogService
    @StateObject private var paymentService: SquarePaymentService
    @StateObject private var readerService: SquareReaderService
    
    // This permission service is specifically for the SquareReaderService.
    // It's a 'let' constant because SquareReaderService holds a weak reference to it,
    // and this ensures it lives as long as DonationPadApp.
    // It does NOT need to be @StateObject if SquarePermissionService is not an ObservableObject
    // and is not directly observed by SwiftUI views.
    private let permissionServiceForReader: SquarePermissionService
    
    @StateObject private var donationViewModel = DonationViewModel()
    @StateObject private var organizationStore = OrganizationStore()
    @StateObject private var kioskStore: KioskStore

    init() {
        // 1. Initialize core services that have no complex dependencies for their direct init
        //    or only depend on services already created.
        let auth = SquareAuthService()
        let catalog = SquareCatalogService(authService: auth)
        let kiosk = KioskStore()

        // 2. Initialize PaymentService. It internally creates some of its own helper services.
        let payment = SquarePaymentService(authService: auth, catalogService: catalog)

        // 3. Initialize ReaderService.
        let reader = SquareReaderService(authService: auth)

        // 4. Initialize the SquarePermissionService instance that will be used by SquareReaderService.
        //    This instance is stored in the 'permissionServiceForReader' property.
        let permForReaderInstance = SquarePermissionService()
        self.permissionServiceForReader = permForReaderInstance // Assign to the 'let' property

        // Assign to @StateObject wrapped properties
        _authService = StateObject(wrappedValue: auth)
        _catalogService = StateObject(wrappedValue: catalog)
        _kioskStore = StateObject(wrappedValue: kiosk)
        _paymentService = StateObject(wrappedValue: payment)
        _readerService = StateObject(wrappedValue: reader)
        // _permissionServiceForReader is already assigned above.

        // MARK: - Post-Initialization Configurations
        // Call configure/connect methods in the correct order.

        // 5. Configure the permissionServiceForReader. It needs the paymentService.
        //    (SquarePermissionService.configure(with: SquarePaymentService))
        permForReaderInstance.configure(with: payment)

        // 6. Set the ReaderService on the PaymentService.
        //    (SquarePaymentService.setReaderService(_: SquareReaderService))
        payment.setReaderService(reader)

        // 7. Configure the ReaderService. It needs the paymentService and the permissionService (permForReaderInstance).
        //    (SquareReaderService.configure(with: SquarePaymentService, permissionService: SquarePermissionService))
        reader.configure(with: payment, permissionService: permForReaderInstance)

        // 8. Connect KioskStore to CatalogService.
        //    (KioskStore.connectCatalogService(_: SquareCatalogService))
        kiosk.connectCatalogService(catalog)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(donationViewModel)
                .environmentObject(organizationStore) // Fixes the original crash
                .environmentObject(kioskStore)
                .environmentObject(authService)
                .environmentObject(catalogService)
                .environmentObject(paymentService)
                .environmentObject(readerService)
                // permissionServiceForReader is primarily a setup dependency for readerService.
                // It's not injected into the environment unless a View directly needs it
                // and SquarePermissionService is made an ObservableObject.
                .onOpenURL { url in
                    print("App received URL: \(url)")
                    // AppDelegate handles URL callbacks
                }
        }
    }
}
