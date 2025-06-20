//
//  SubscriptionComponents.swift
//  ShulPad
//
//  Created by Zalman Rodkin on 6/20/25.
//
// Views/SubscriptionComponents.swift
import SwiftUI

// MARK: - Subscription Status Card
struct SubscriptionStatusCard: View {
    let status: SubscriptionStatus
    let onUpgrade: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Subscription Status")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let subscription = status.subscription {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 8, height: 8)
                            
                            Text(statusText)
                                .font(.subheadline)
                                .foregroundColor(statusColor)
                        }
                        
                        if subscription.inTrialPeriod {
                            Text("Trial ends: \(formattedTrialEndDate)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("\(subscription.planType.capitalized) Plan - \(subscription.deviceCount) device(s)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No active subscription")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                }
                
                Spacer()
                
                if !status.canLaunchKiosk {
                    Button("Upgrade") {
                        onUpgrade()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            
            // Device count warning
            if let upgradeNeeded = status.upgradeNeeded, upgradeNeeded {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Device limit exceeded")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        if let current = status.currentDeviceCount,
                           let allowed = status.allowedDeviceCount,
                           let cost = status.additionalCost {
                            Text("\(current)/\(allowed) devices active. Add \(current - allowed) more for $\(String(format: "%.0f", cost))/month")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var statusColor: Color {
        if status.canLaunchKiosk {
            return .green
        } else {
            return .red
        }
    }
    
    private var statusText: String {
        if let subscription = status.subscription {
            if subscription.inTrialPeriod {
                return "Trial Active"
            } else {
                return subscription.status.capitalized
            }
        }
        return "Inactive"
    }
    
    private var formattedTrialEndDate: String {
        guard let subscription = status.subscription else { return "" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        if let date = ISO8601DateFormatter().date(from: subscription.trialEndDate) {
            return formatter.string(from: date)
        }
        
        return subscription.trialEndDate
    }
}

// MARK: - Plan Selection
struct PlanSelectionView: View {
    @Binding var selectedPlan: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Billing Period")
                .font(.headline)
            
            VStack(spacing: 12) {
                PlanCard(
                    title: "Monthly",
                    price: "$49",
                    period: "per month",
                    savings: nil,
                    isSelected: selectedPlan == "monthly"
                ) {
                    selectedPlan = "monthly"
                }
                
                PlanCard(
                    title: "Yearly",
                    price: "$490",
                    period: "per year",
                    savings: "Save 17%",
                    isSelected: selectedPlan == "yearly"
                ) {
                    selectedPlan = "yearly"
                }
            }
        }
    }
}

struct PlanCard: View {
    let title: String
    let price: String
    let period: String
    let savings: String?
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if let savings = savings {
                            Text(savings)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .clipShape(Capsule())
                        }
                    }
                    
                    HStack(alignment: .bottom, spacing: 4) {
                        Text(price)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(period)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color(.separator), lineWidth: isSelected ? 2 : 1)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? Color.blue.opacity(0.05) : Color(.secondarySystemBackground))
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Device Count Selector
struct DeviceCountSelector: View {
    @Binding var deviceCount: Int
    let selectedPlan: String
    
    private var extraDevicePrice: Double {
        selectedPlan == "monthly" ? 15.0 : 150.0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Number of Devices")
                .font(.headline)
            
            HStack {
                Button(action: {
                    if deviceCount > 1 {
                        deviceCount -= 1
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(deviceCount > 1 ? .blue : .gray)
                }
                .disabled(deviceCount <= 1)
                
                Text("\(deviceCount)")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .frame(minWidth: 40)
                
                Button(action: {
                    deviceCount += 1
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                if deviceCount > 1 {
                    Text("+$\(String(format: "%.0f", extraDevicePrice * Double(deviceCount - 1))) extra")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("Each additional device: $\(String(format: "%.0f", extraDevicePrice))/\(selectedPlan == "monthly" ? "month" : "year")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Price Summary
struct PriceSummaryView: View {
    let selectedPlan: String
    let deviceCount: Int
    
    private var basePrice: Double {
        selectedPlan == "monthly" ? 49.0 : 490.0
    }
    
    private var extraDevicePrice: Double {
        selectedPlan == "monthly" ? 15.0 : 150.0
    }
    
    private var totalPrice: Double {
        basePrice + (Double(deviceCount - 1) * extraDevicePrice)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Price Summary")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 8) {
                HStack {
                    Text("Base plan (1 device)")
                    Spacer()
                    Text("$\(String(format: "%.0f", basePrice))")
                }
                .font(.subheadline)
                
                if deviceCount > 1 {
                    HStack {
                        Text("\(deviceCount - 1) additional device(s)")
                        Spacer()
                        Text("$\(String(format: "%.0f", extraDevicePrice * Double(deviceCount - 1)))")
                    }
                    .font(.subheadline)
                }
                
                Divider()
                
                HStack {
                    Text("Total")
                        .fontWeight(.semibold)
                    Spacer()
                    Text("$\(String(format: "%.0f", totalPrice))/\(selectedPlan == "monthly" ? "month" : "year")")
                        .fontWeight(.bold)
                }
                
                HStack {
                    Text("30-day free trial, then billed \(selectedPlan)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Current Subscription Card
struct CurrentSubscriptionCard: View {
    let status: SubscriptionStatus
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Subscription")
                .font(.headline)
            
            if let subscription = status.subscription {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(subscription.planType.capitalized) Plan")
                            .fontWeight(.semibold)
                        
                        Text("$\(String(format: "%.0f", subscription.totalPrice))/\(subscription.planType == "monthly" ? "month" : "year")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if subscription.inTrialPeriod {
                            Text("Trial ends: \(formattedDate(subscription.trialEndDate))")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("\(subscription.deviceCount) device(s)")
                            .font(.subheadline)
                        
                        Circle()
                            .fill(subscription.status == "active" ? .green : .red)
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func formattedDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        if let date = ISO8601DateFormatter().date(from: dateString) {
            return formatter.string(from: date)
        }
        
        return dateString
    }
}
