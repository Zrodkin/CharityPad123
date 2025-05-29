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
        VStack(spacing: 0) {
            // Scrollable content
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
                    
                    // Main content - just the timeout duration card
                    VStack(spacing: 20) {
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
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 100) // Add padding for fixed save button
                }
            }
            
            // 🆕 Fixed save button at bottom
            VStack(spacing: 0) {
                // Subtle separator
                Rectangle()
                    .fill(Color(.separator))
                    .frame(height: 0.5)
                
                // Save button container
                VStack(spacing: 16) {
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
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(
                    Color(.systemBackground)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
                )
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





struct TimeoutSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        TimeoutSettingsView()
            .environmentObject(KioskStore())
    }
}
