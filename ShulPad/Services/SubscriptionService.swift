//
//  SubscriptionService.swift
//  ShulPad
//
//  Created by Zalman Rodkin on 6/20/25.
//

// Services/SubscriptionService.swift
import Foundation
import Combine
import UIKit

@MainActor
class SubscriptionService: ObservableObject {
    @Published var subscriptionStatus: SubscriptionStatus?
    @Published var isLoading = false
    @Published var error: String?
    
    private let authService: SquareAuthService
    private var cancellables = Set<AnyCancellable>()
    
    // Device ID for tracking
    private let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    
    init(authService: SquareAuthService) {
        self.authService = authService
    }
    
    // MARK: - Public Methods
    
    /// Check if user can launch kiosk (main access control method)
    func canLaunchKiosk() async -> Bool {
        await checkSubscriptionStatus()
        return subscriptionStatus?.canLaunchKiosk ?? false
    }
    
    /// Check current subscription status
    func checkSubscriptionStatus() async {
        guard !authService.organizationId.isEmpty else {
            error = "No organization ID available"
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            let url = "\(SquareConfig.backendBaseURL)/api/subscriptions/status?organization_id=\(authService.organizationId)&device_id=\(deviceId)"
            
            guard let requestUrl = URL(string: url) else {
                error = "Invalid URL"
                isLoading = false
                return
            }
            
            let (data, response) = try await URLSession.shared.data(from: requestUrl)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                error = "Invalid response"
                isLoading = false
                return
            }
            
            if httpResponse.statusCode == 200 {
                let subscriptionResponse = try JSONDecoder().decode(SubscriptionStatus.self, from: data)
                subscriptionStatus = subscriptionResponse
                
                // Store subscription status locally for offline access
                saveSubscriptionStatusLocally(subscriptionResponse)
            } else {
                error = "Failed to check subscription status"
                // Try to load cached subscription status
                loadSubscriptionStatusFromCache()
            }
            
        } catch {
            self.error = "Failed to check subscription: \(error.localizedDescription)"
            
            // Try to load cached subscription status
            loadSubscriptionStatusFromCache()
        }
        
        isLoading = false
    }
    
    /// Create a new subscription
    func createSubscription(
        planType: String,
        deviceCount: Int = 1,
        customerEmail: String,
        promoCode: String? = nil,
        cardId: String? = nil
    ) async -> Bool {
        isLoading = true
        error = nil
        
        do {
            let request = CreateSubscriptionRequest(
                organizationId: authService.organizationId,
                planType: planType,
                deviceCount: deviceCount,
                customerEmail: customerEmail,
                promoCode: promoCode,
                cardId: cardId
            )
            
            let url = "\(SquareConfig.backendBaseURL)/api/subscriptions/create"
            
            guard let requestUrl = URL(string: url) else {
                error = "Invalid URL"
                isLoading = false
                return false
            }
            
            var urlRequest = URLRequest(url: requestUrl)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try JSONEncoder().encode(request)
            
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                error = "Invalid response"
                isLoading = false
                return false
            }
            
            let subscriptionResponse = try JSONDecoder().decode(CreateSubscriptionResponse.self, from: data)
            
            if httpResponse.statusCode == 200 && subscriptionResponse.success {
                // Refresh subscription status
                await checkSubscriptionStatus()
                isLoading = false
                return true
            } else {
                error = subscriptionResponse.error ?? "Failed to create subscription"
                isLoading = false
                return false
            }
            
        } catch {
            self.error = "Failed to create subscription: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
    
    /// Get pricing information for display
    func getPricingInfo() -> (monthly: PricingTier, yearly: PricingTier) {
        let monthly = PricingTier(
            name: "Monthly",
            basePrice: 49.0,
            extraDevicePrice: 15.0,
            billingPeriod: "month",
            savings: nil
        )
        
        let yearly = PricingTier(
            name: "Yearly",
            basePrice: 490.0,
            extraDevicePrice: 150.0,
            billingPeriod: "year",
            savings: "Save 17%"
        )
        
        return (monthly, yearly)
    }
    
    // MARK: - Private Methods
    
    private func saveSubscriptionStatusLocally(_ status: SubscriptionStatus) {
        do {
            let data = try JSONEncoder().encode(status)
            UserDefaults.standard.set(data, forKey: "cached_subscription_status")
            UserDefaults.standard.set(Date(), forKey: "subscription_status_cache_date")
        } catch {
            print("Failed to cache subscription status: \(error)")
        }
    }
    
    private func loadSubscriptionStatusFromCache() {
        guard let data = UserDefaults.standard.data(forKey: "cached_subscription_status"),
              let cacheDate = UserDefaults.standard.object(forKey: "subscription_status_cache_date") as? Date else {
            return
        }
        
        // Only use cache if it's less than 1 hour old
        let hourAgo = Date().addingTimeInterval(-3600)
        guard cacheDate > hourAgo else { return }
        
        do {
            let cachedStatus = try JSONDecoder().decode(SubscriptionStatus.self, from: data)
            subscriptionStatus = cachedStatus
        } catch {
            print("Failed to load cached subscription status: \(error)")
        }
    }
}
