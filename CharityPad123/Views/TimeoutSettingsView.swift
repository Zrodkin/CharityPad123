import SwiftUI

struct TimeoutSettingsView: View {
    @EnvironmentObject private var kioskStore: KioskStore
    @State private var timeoutDuration: String = "60"
    @State private var isSaving = false
    @State private var showToast = false
    
    let timeoutOptions = [
        ("15", "15 seconds"),
        ("30", "30 seconds"),
        ("60", "1 minute"),
        ("120", "2 minutes"),
        ("300", "5 minutes")
    ]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Page header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        
                        Text("Timeout Settings")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                    }
                    
                    Text("Configure how long the kiosk waits before automatically resetting to the home screen")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                // Main content
                VStack(spacing: 20) {
                    // Timeout Duration Card
                    SettingsCard(title: "Auto-Reset Duration", icon: "timer.circle.fill") {
                        VStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Select how long to wait for user interaction before returning to the home screen")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            // Timeout options
                            VStack(spacing: 12) {
                                ForEach(timeoutOptions, id: \.0) { option in
                                    TimeoutOptionCard(
                                        value: option.0,
                                        label: option.1,
                                        isSelected: timeoutDuration == option.0,
                                        onSelect: {
                                            timeoutDuration = option.0
                                        }
                                    )
                                }
                            }
                        }
                    }
                    
                    // How It Works Card
                    SettingsCard(title: "How Timeout Works", icon: "info.circle.fill") {
                        VStack(spacing: 20) {
                            HStack(alignment: .top, spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.1))
                                        .frame(width: 40, height: 40)
                                    
                                    Image(systemName: "hand.tap.fill")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(.blue)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("User Interaction")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    Text("Timer resets each time a donor taps the screen, selects an amount, or interacts with the kiosk")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            
                            HStack(alignment: .top, spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.orange.opacity(0.1))
                                        .frame(width: 40, height: 40)
                                    
                                    Image(systemName: "clock.badge.exclamationmark.fill")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(.orange)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Timeout Reached")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    Text("When the timeout period elapses without interaction, the kiosk automatically returns to the home screen")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            
                            HStack(alignment: .top, spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.green.opacity(0.1))
                                        .frame(width: 40, height: 40)
                                    
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(.green)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Ready for Next Donor")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    Text("The kiosk is now ready for the next donor, ensuring a clean slate for each donation session")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    
                    // Recommendation Card
                    RecommendationCard()
                }
                .padding(.horizontal, 24)
                
                // Save button
                Button(action: saveSettings) {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.9)
                            
                            Text("Saving...")
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text("Save Settings")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(isSaving)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            timeoutDuration = kioskStore.timeoutDuration
        }
        .overlay(alignment: .top) {
            if showToast {
                ToastNotification(message: "Settings saved successfully")
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showToast)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showToast = false
                        }
                    }
            }
        }
    }
    
    func saveSettings() {
        isSaving = true
        
        kioskStore.timeoutDuration = timeoutDuration
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            kioskStore.saveSettings()
            isSaving = false
            showToast = true
        }
    }
}

// MARK: - Supporting Views

struct TimeoutOptionCard: View {
    let value: String
    let label: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.blue : Color(.separator), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    if value == "60" {
                        Text("Recommended")
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .fontWeight(.medium)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.blue)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.05) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RecommendationCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.green)
                }
                
                Text("Recommendations")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            VStack(spacing: 16) {
                RecommendationItem(
                    icon: "clock",
                    color: .blue,
                    title: "1 minute (Default)",
                    description: "Best for most environments. Gives donors enough time to decide while keeping the kiosk responsive."
                )
                
                RecommendationItem(
                    icon: "speedometer",
                    color: .orange,
                    title: "30 seconds",
                    description: "Use in high-traffic areas where quick turnover is important, like event entrances."
                )
                
                RecommendationItem(
                    icon: "moon.fill",
                    color: .purple,
                    title: "2-5 minutes",
                    description: "Better for quieter environments or when donors might need more time to consider their donation."
                )
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct RecommendationItem: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

struct TimeoutSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        TimeoutSettingsView()
            .environmentObject(KioskStore())
    }
}
