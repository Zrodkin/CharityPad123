import SwiftUI

struct UpdatedCustomAmountView: View {
    @EnvironmentObject var kioskStore: KioskStore
    @Environment(\.dismiss) private var dismiss
    @State private var amountString: String = ""
    @State private var errorMessage: String? = nil
    @State private var shakeOffset: CGFloat = 0
    
    // Callback for when amount is selected
    var onAmountSelected: (Double) -> Void
    
    var body: some View {
        ZStack {
            // Background image (from old design)
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
            
            // Dark overlay (from old design)
            Color.black.opacity(0.55)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                // Clean amount display with cute shake animation
                Text("$\(amountString.isEmpty ? "0" : amountString)")
                    .font(.system(size: 65, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 120)
                    .padding(.bottom, 10)
                    .offset(x: shakeOffset)
                    .animation(.easeInOut(duration: 0.1), value: shakeOffset)
                
                // Error message (with modern animations)
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.7))
                        .cornerRadius(10)
                        .transition(.opacity)
                }
                
                // Keypad (old design layout with modern functionality)
                VStack(spacing: 12) {
                    // Row 1
                    HStack(spacing: 12) {
                        ForEach(1...3, id: \.self) { num in
                            KeypadButton(number: num, letters: num == 2 ? "ABC" : num == 3 ? "DEF" : "") {
                                handleNumberPress(String(num))
                            }
                        }
                    }
                    
                    // Row 2
                    HStack(spacing: 12) {
                        ForEach(4...6, id: \.self) { num in
                            KeypadButton(number: num, letters: num == 4 ? "GHI" : num == 5 ? "JKL" : "MNO") {
                                handleNumberPress(String(num))
                            }
                        }
                    }
                    
                    // Row 3
                    HStack(spacing: 12) {
                        ForEach(7...9, id: \.self) { num in
                            KeypadButton(number: num, letters: num == 7 ? "PQRS" : num == 8 ? "TUV" : "WXYZ") {
                                handleNumberPress(String(num))
                            }
                        }
                    }
                    
                    // Row 4 (old design layout)
                    HStack(spacing: 12) {
                        // Delete button (old design)
                        Button(action: handleDelete) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 64)
                                
                                Image(systemName: "delete.left")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                            }
                        }
                        
                        // 0 button
                        KeypadButton(number: 0, letters: "") {
                            handleNumberPress("0")
                        }
                        
                        // Next button (always enabled so we can show cute shake)
                        Button(action: {
                            handleDone()
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 64)
                                
                                Image(systemName: "arrow.forward")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: 800)
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Circle().fill(Color.white.opacity(0.2)))
                }
            }
        }
        .onAppear {
            print("📱 UpdatedCustomAmountView appeared")
        }
        .onDisappear {
            print("📱 UpdatedCustomAmountView disappeared")
        }
    }
    
    // MARK: - Helper Methods (modern functionality)
    
    private func handleNumberPress(_ num: String) {
        let maxDigits = 7
        
        // Prevent leading zeros
        if amountString.isEmpty && num == "0" {
            return
        }
        
        // Check if adding this number would exceed maximum
        let tempAmount = amountString + num
        if let amount = Double(tempAmount),
           let maxAmount = Double(kioskStore.maxAmount) {
            if amount > maxAmount {
                withAnimation(.easeInOut(duration: 0.3)) {
                    errorMessage = "Maximum amount is $\(Int(maxAmount))"
                }
                
                // Clear error after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        errorMessage = nil
                    }
                }
                return
            }
        }
        
        // Add the number if under max digits
        if amountString.count < maxDigits {
            amountString += num
            print("💰 Amount updated to: \(amountString)")
        }
        
        // Clear any existing error (with animation)
        if errorMessage != nil {
            withAnimation(.easeInOut(duration: 0.3)) {
                errorMessage = nil
            }
        }
        
        // Modern haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func handleDelete() {
        if !amountString.isEmpty {
            amountString.removeLast()
            print("🗑️ Amount after delete: \(amountString)")
        }
        
        // Clear any existing error (with animation)
        if errorMessage != nil {
            withAnimation(.easeInOut(duration: 0.3)) {
                errorMessage = nil
            }
        }
        
        // Modern haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func handleDone() {
        print("✅ handleDone called with amountString: '\(amountString)'")
        
        // Convert amount to Double
        guard let amount = Double(amountString), amount > 0 else {
            // Cute shake animation for $0 or empty amount! 🎯
            if amountString.isEmpty {
                print("💫 Triggering cute shake animation for $0")
                withAnimation(.interpolatingSpring(stiffness: 600, damping: 5)) {
                    shakeAmount()
                }
                
                // Add a playful haptic pattern
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    impactFeedback.impactOccurred()
                }
                
                return // Don't show error message, just the cute shake
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    errorMessage = "Please enter a valid amount"
                }
            }
            print("❌ Invalid amount entered: '\(amountString)'")
            return
        }
        
        // Check minimum amount
        if let minAmount = Double(kioskStore.minAmount), amount < minAmount {
            withAnimation(.easeInOut(duration: 0.3)) {
                errorMessage = "Minimum amount is $\(Int(minAmount))"
            }
            print("❌ Amount below minimum: \(amount) < \(minAmount)")
            return
        }
        
        // Check maximum amount
        if let maxAmount = Double(kioskStore.maxAmount), amount > maxAmount {
            withAnimation(.easeInOut(duration: 0.3)) {
                errorMessage = "Maximum amount is $\(Int(maxAmount))"
            }
            print("❌ Amount above maximum: \(amount) > \(maxAmount)")
            return
        }
        
        print("✅ Valid amount entered: $\(amount)")
        print("🚀 Calling onAmountSelected callback...")
        
        // Modern haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Call the callback with the selected amount
        onAmountSelected(amount)
        
        print("📤 Callback completed")
    }
    
    // MARK: - Cute shake animation helper
    private func shakeAmount() {
        let shakeSequence: [CGFloat] = [0, -8, 8, -6, 6, -4, 4, -2, 2, 0]
        
        for (index, offset) in shakeSequence.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
                shakeOffset = offset
            }
        }
    }
}

// MARK: - Keypad Button Component (old design with modern touch feedback)

struct KeypadButton: View {
    let number: Int
    let letters: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            // Modern haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            action()
        }) {
            VStack(spacing: 2) {
                Text("\(number)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                if !letters.isEmpty {
                    Text(letters)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.2))
            )
        }
        .buttonStyle(KeypadButtonStyle())
    }
}

// MARK: - Modern Button Style

struct KeypadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

struct UpdatedCustomAmountView_Previews: PreviewProvider {
    static var previews: some View {
        UpdatedCustomAmountView { amount in
            print("Preview: Selected amount \(amount)")
        }
        .environmentObject(KioskStore())
    }
}
