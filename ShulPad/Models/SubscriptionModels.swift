//
//  SubscriptionModels.swift
//  ShulPad
//
//  Created by Zalman Rodkin on 6/20/25.
//

// Models/SubscriptionModels.swift
import Foundation

struct SubscriptionStatus: Codable {
    let hasSubscription: Bool
    let canLaunchKiosk: Bool
    let subscription: SubscriptionDetails?
    let message: String
    let upgradeNeeded: Bool?
    let currentDeviceCount: Int?
    let allowedDeviceCount: Int?
    let additionalCost: Double?
    
    enum CodingKeys: String, CodingKey {
        case hasSubscription = "has_subscription"
        case canLaunchKiosk = "can_launch_kiosk"
        case subscription, message
        case upgradeNeeded = "upgrade_needed"
        case currentDeviceCount = "current_device_count"
        case allowedDeviceCount = "allowed_device_count"
        case additionalCost = "additional_cost"
    }
}

struct SubscriptionDetails: Codable {
    let id: Int
    let planType: String
    let deviceCount: Int
    let status: String
    let trialEndDate: String
    let inTrialPeriod: Bool
    let totalPrice: Double
    
    enum CodingKeys: String, CodingKey {
        case id
        case planType = "plan_type"
        case deviceCount = "device_count"
        case status
        case trialEndDate = "trial_end_date"
        case inTrialPeriod = "in_trial_period"
        case totalPrice = "total_price"
    }
}

struct CreateSubscriptionRequest: Codable {
    let organizationId: String
    let planType: String
    let deviceCount: Int
    let customerEmail: String
    let promoCode: String?
    let cardId: String?
    
    enum CodingKeys: String, CodingKey {
        case organizationId = "organization_id"
        case planType = "plan_type"
        case deviceCount = "device_count"
        case customerEmail = "customer_email"
        case promoCode = "promo_code"
        case cardId = "card_id"
    }
}

struct CreateSubscriptionResponse: Codable {
    let success: Bool
    let subscription: SubscriptionDetails?
    let error: String?
}

struct PricingTier {
    let name: String
    let basePrice: Double
    let extraDevicePrice: Double
    let billingPeriod: String
    let savings: String?
    
    func totalPrice(deviceCount: Int) -> Double {
        return basePrice + (Double(deviceCount - 1) * extraDevicePrice)
    }
    
    func formattedPrice(deviceCount: Int) -> String {
        let total = totalPrice(deviceCount: deviceCount)
        return String(format: "$%.0f/%@", total, billingPeriod)
    }
}
