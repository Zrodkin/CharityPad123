import SwiftUI
import PhotosUI

struct HomePageSettingsView: View {
    @EnvironmentObject private var kioskStore: KioskStore
    @State private var headline: String = ""
    @State private var subtext: String = ""
    @State private var homePageEnabled = true
    @State private var showingBackgroundImagePicker = false
    @State private var showToast = false
    @State private var toastMessage = "Settings saved"
    
    @State private var textVerticalPosition: KioskLayoutConstants.VerticalTextPosition = .center
    @State private var textVerticalFineTuning: Double = 0.0
    @State private var headlineTextSize: Double = KioskLayoutConstants.defaultHeadlineSize
    @State private var subtextTextSize: Double = KioskLayoutConstants.defaultSubtextSize
    
    // Layout section state
    @State private var isLayoutSectionExpanded = false
    @State private var showLayoutSaveToast = false
    @State private var showFullScreenPreview = false
    
    // Track original values to detect changes
    @State private var originalTextVerticalPosition: KioskLayoutConstants.VerticalTextPosition = .center
    @State private var originalTextVerticalFineTuning: Double = 0.0
    @State private var originalHeadlineTextSize: Double = KioskLayoutConstants.defaultHeadlineSize
    @State private var originalSubtextTextSize: Double = KioskLayoutConstants.defaultSubtextSize
    
    // Auto-save timer
    @State private var autoSaveTimer: Timer?
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Page header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "house.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        
                        Text("Home Page Settings")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        // Enable/disable toggle
                        Toggle("Enabled", isOn: $homePageEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                            .onChange(of: homePageEnabled) { _, newValue in
                                scheduleAutoSave()
                            }
                    }
                    
                    Text("Customize the appearance of your donation kiosk home screen")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                // Main content in cards
                VStack(spacing: 20) {
                    // Combined Background Image & Preview Card
                    SettingsCard(title: "Background Image", icon: "photo.fill") {
                        VStack(spacing: 16) {
                            
                            // Clickable preview (same layout as before)
                            Button(action: {
                                showFullScreenPreview = true
                            }) {
                                PreviewContent(
                                    backgroundImage: kioskStore.backgroundImage,
                                    logoImage: kioskStore.logoImage,
                                    headline: headline.isEmpty ? "Tap to Donate" : headline,
                                    subtext: subtext,
                                    textVerticalPosition: textVerticalPosition,
                                    textVerticalFineTuning: textVerticalFineTuning,
                                    headlineTextSize: calculatePreviewHeadlineSize(),
                                    subtextTextSize: calculatePreviewSubtextSize(),
                                    height: 300
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .overlay(
                                // Subtle indication it's clickable
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    .opacity(0)
                                    .overlay(
                                        VStack {
                                            Spacer()
                                            HStack {
                                                Spacer()
                                                HStack(spacing: 4) {
                                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                                        .font(.caption2)
                                                    Text("Tap to expand")
                                                        .font(.caption2)
                                                }
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(.ultraThinMaterial)
                                                .foregroundStyle(.secondary)
                                                .clipShape(Capsule())
                                                .padding(8)
                                            }
                                        }
                                    )
                            )
                            
                            // Action buttons (only show when image exists)
                            if kioskStore.backgroundImage != nil {
                                HStack(spacing: 12) {
                                    Button(action: {
                                        showingBackgroundImagePicker = true
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "photo.badge.plus")
                                                .font(.system(size: 16, weight: .medium))
                                            Text("Change Image")
                                                .fontWeight(.medium)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color(.secondarySystemBackground))
                                        .foregroundStyle(.primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            kioskStore.backgroundImage = nil
                                            autoSaveSettings()
                                        }
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "trash")
                                                .font(.system(size: 16, weight: .medium))
                                            Text("Remove")
                                                .fontWeight(.medium)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.red.opacity(0.1))
                                        .foregroundStyle(.red)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                            }
                        }
                    }
                    
                    // Text Content Card
                    SettingsCard(title: "Text Content", icon: "textformat") {
                        VStack(spacing: 24) {
                            // Headline Section
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: "Main Headline", subtitle: "Primary text displayed on the home screen")
                                
                                TextField("Enter headline", text: $headline)
                                    .textFieldStyle(ModernTextFieldStyle())
                                    .onChange(of: headline) { _, _ in
                                        scheduleAutoSave()
                                    }
                            }
                            
                            // Subtext Section
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: "Supporting Text", subtitle: "Additional context or call-to-action")
                                
                                ZStack(alignment: .topLeading) {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.secondarySystemBackground))
                                        .frame(minHeight: 100)
                                    
                                    TextEditor(text: $subtext)
                                        .padding(12)
                                        .background(Color.clear)
                                        .onChange(of: subtext) { _, _ in
                                            scheduleAutoSave()
                                        }
                                    
                                    if subtext.isEmpty {
                                        Text("Enter supporting text...")
                                            .foregroundStyle(.tertiary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 20)
                                            .allowsHitTesting(false)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Collapsible Layout & Positioning Section
                    CollapsibleLayoutSection(
                        isExpanded: $isLayoutSectionExpanded,
                        textVerticalPosition: $textVerticalPosition,
                        textVerticalFineTuning: $textVerticalFineTuning,
                        headlineTextSize: $headlineTextSize,
                        subtextTextSize: $subtextTextSize,
                        showSaveToast: $showLayoutSaveToast,
                        hasChanges: hasLayoutChanges,
                        onSave: saveLayoutSettings,
                        onRevertToDefault: revertLayoutToDefault,
                        backgroundImage: kioskStore.backgroundImage,
                        headline: headline.isEmpty ? "Sample Headline" : headline,
                        subtext: subtext
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            headline = kioskStore.headline
            subtext = kioskStore.subtext
            homePageEnabled = kioskStore.homePageEnabled
            textVerticalPosition = kioskStore.textVerticalPosition
            textVerticalFineTuning = kioskStore.textVerticalFineTuning
            headlineTextSize = kioskStore.headlineTextSize
            subtextTextSize = kioskStore.subtextTextSize
            
            // Store original values for change detection
            originalTextVerticalPosition = kioskStore.textVerticalPosition
            originalTextVerticalFineTuning = kioskStore.textVerticalFineTuning
            originalHeadlineTextSize = kioskStore.headlineTextSize
            originalSubtextTextSize = kioskStore.subtextTextSize
        }
        .sheet(isPresented: $showingBackgroundImagePicker) {
            ImagePicker(selectedImage: $kioskStore.backgroundImage, isPresented: $showingBackgroundImagePicker)
                .onDisappear {
                    if kioskStore.backgroundImage != nil {
                        autoSaveSettings()
                    }
                }
        }
        .overlay(
            Group {
                if showLayoutSaveToast {
                    ToastNotification(message: "Layout settings saved")
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showLayoutSaveToast)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showLayoutSaveToast = false
                            }
                        }
                }
            },
            alignment: .top
        )
        .fullScreenCover(isPresented: $showFullScreenPreview) {
            FullScreenPreviewView(
                backgroundImage: kioskStore.backgroundImage,
                logoImage: nil,
                headline: headline.isEmpty ? "Tap to Donate" : headline,
                subtext: subtext.isEmpty ? "" : subtext,
                textVerticalPosition: textVerticalPosition,
                textVerticalFineTuning: textVerticalFineTuning,
                headlineTextSize: headlineTextSize,
                subtextTextSize: subtextTextSize,
                isPresented: $showFullScreenPreview
            )
        }
    }
    
    // MARK: - Preview Calculation Methods
    
    private func calculateTextVerticalPosition(in size: CGSize) -> CGFloat {
        let basePosition: CGFloat
        
        switch textVerticalPosition {
        case .top:
            basePosition = size.height * 0.25
        case .center:
            basePosition = size.height * 0.5
        case .bottom:
            basePosition = size.height * 0.75
        }
        
        // Apply fine tuning (scale it down for preview)
        let scaledFineTuning = textVerticalFineTuning * 0.3
        return basePosition - scaledFineTuning
    }
    
    private func calculatePreviewHeadlineSize() -> CGFloat {
        // Scale down the actual size for preview
        return headlineTextSize * 0.4
    }
    
    private func calculatePreviewSubtextSize() -> CGFloat {
        // Scale down the actual size for preview
        return subtextTextSize * 0.4
    }
    
    private func calculateTextSpacing() -> CGFloat {
        // Dynamic spacing based on text sizes
        return (headlineTextSize + subtextTextSize) * 0.1
    }
    
    // MARK: - Layout Settings Methods
    
    private var hasLayoutChanges: Bool {
        return textVerticalPosition != originalTextVerticalPosition ||
               textVerticalFineTuning != originalTextVerticalFineTuning ||
               headlineTextSize != originalHeadlineTextSize ||
               subtextTextSize != originalSubtextTextSize
    }
    
    private func saveLayoutSettings() {
        kioskStore.textVerticalPosition = textVerticalPosition
        kioskStore.textVerticalFineTuning = textVerticalFineTuning
        kioskStore.headlineTextSize = headlineTextSize
        kioskStore.subtextTextSize = subtextTextSize
        
        kioskStore.saveSettings()
        
        // Update original values after saving
        originalTextVerticalPosition = textVerticalPosition
        originalTextVerticalFineTuning = textVerticalFineTuning
        originalHeadlineTextSize = headlineTextSize
        originalSubtextTextSize = subtextTextSize
        
        showLayoutSaveToast = true
    }
    
    private func revertLayoutToDefault() {
        textVerticalPosition = .center
        textVerticalFineTuning = 0.0
        headlineTextSize = KioskLayoutConstants.defaultHeadlineSize
        subtextTextSize = KioskLayoutConstants.defaultSubtextSize
    }
    
    // MARK: - Auto-Save Functions
    
    private func scheduleAutoSave() {
        // Cancel existing timer
        autoSaveTimer?.invalidate()
        
        // Schedule new timer with 1 second delay
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            autoSaveSettings()
        }
    }
    
    private func autoSaveSettings() {
        kioskStore.headline = headline
        kioskStore.subtext = subtext
        kioskStore.homePageEnabled = homePageEnabled
        
        kioskStore.saveSettings()
    }
}

// MARK: - Preview Content Component

struct PreviewContent: View {
    let backgroundImage: UIImage?
    let logoImage: UIImage?
    let headline: String
    let subtext: String
    let textVerticalPosition: KioskLayoutConstants.VerticalTextPosition
    let textVerticalFineTuning: Double
    let headlineTextSize: CGFloat
    let subtextTextSize: CGFloat
    let height: CGFloat
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .frame(height: height)
                .aspectRatio(16/9, contentMode: .fit)
            
            // Background image if available
            if let backgroundImage = backgroundImage {
                Image(uiImage: backgroundImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                // Empty state for when no background image is set
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: height)
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 40))
                                .foregroundStyle(.blue)
                            
                            VStack(spacing: 4) {
                                Text("Add Background Image")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                
                                Text("Tap to select from your photos")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
            }
            
            // Only show overlay and text if we have a background image
            if backgroundImage != nil {
                // Dark overlay
                Rectangle()
                    .fill(.black.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Text content positioned according to settings
                GeometryReader { geometry in
                    VStack(spacing: calculateTextSpacing()) {
                        Text(headline)
                            .font(.system(size: headlineTextSize, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .shadow(radius: 5)
                        
                        if !subtext.isEmpty {
                            Text(subtext)
                                .font(.system(size: subtextTextSize))
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .shadow(radius: 3)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .position(
                        x: geometry.size.width / 2,
                        y: calculateTextVerticalPosition(in: geometry.size)
                    )
                }
            }
        }
    }
    
    private func calculateTextVerticalPosition(in size: CGSize) -> CGFloat {
        let basePosition: CGFloat
        
        switch textVerticalPosition {
        case .top:
            basePosition = size.height * 0.25
        case .center:
            basePosition = size.height * 0.5
        case .bottom:
            basePosition = size.height * 0.75
        }
        
        // Apply fine tuning (scale based on height)
        let scaledFineTuning = textVerticalFineTuning * (height / 300)
        return basePosition - scaledFineTuning
    }
    
    private func calculateTextSpacing() -> CGFloat {
        // Dynamic spacing based on text sizes and preview height
        return (headlineTextSize + subtextTextSize) * 0.1 * (height / 300)
    }
}

// MARK: - Full Screen Preview

struct FullScreenPreviewView: View {
    let backgroundImage: UIImage?
    let logoImage: UIImage?
    let headline: String
    let subtext: String
    let textVerticalPosition: KioskLayoutConstants.VerticalTextPosition
    let textVerticalFineTuning: Double
    let headlineTextSize: Double
    let subtextTextSize: Double
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            // Full screen background
            if let backgroundImage = backgroundImage {
                Image(uiImage: backgroundImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else {
                // Default gradient background
                LinearGradient(
                    colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
            
            // Dark overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            // Content positioned exactly like the real HomeView
            GeometryReader { geometry in
                VStack(spacing: calculateFullScreenTextSpacing()) {
                    Text(headline)
                        .font(.system(size: headlineTextSize, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .shadow(radius: 10)
                    
                    if !subtext.isEmpty {
                        Text(subtext)
                            .font(.system(size: subtextTextSize))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .shadow(radius: 5)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 40)
                .position(
                    x: geometry.size.width / 2,
                    y: calculateFullScreenTextVerticalPosition(in: geometry.size)
                )
            }
            
            // Close button (top right)
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: {
                        isPresented = false
                    }) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.top, 20)
                .padding(.trailing, 20)
                
                Spacer()
            }
        }
        .statusBarHidden()
    }
    
    private func calculateFullScreenTextVerticalPosition(in size: CGSize) -> CGFloat {
        let basePosition: CGFloat
        
        switch textVerticalPosition {
        case .top:
            basePosition = size.height * 0.25
        case .center:
            basePosition = size.height * 0.5
        case .bottom:
            basePosition = size.height * 0.75
        }
        
        // Apply fine tuning at full scale
        return basePosition - textVerticalFineTuning
    }
    
    private func calculateFullScreenTextSpacing() -> CGFloat {
        // Dynamic spacing based on actual text sizes
        return (headlineTextSize + subtextTextSize) * 0.15
    }
}

// MARK: - Collapsible Layout Section

struct CollapsibleLayoutSection: View {
    @Binding var isExpanded: Bool
    @Binding var textVerticalPosition: KioskLayoutConstants.VerticalTextPosition
    @Binding var textVerticalFineTuning: Double
    @Binding var headlineTextSize: Double
    @Binding var subtextTextSize: Double
    @Binding var showSaveToast: Bool
    
    let hasChanges: Bool
    let onSave: () -> Void
    let onRevertToDefault: () -> Void
    let backgroundImage: UIImage?
    let headline: String
    let subtext: String
    
    // Live preview states
    @State private var isAdjustingPosition = false
    @State private var isAdjustingHeadlineSize = false
    @State private var isAdjustingSubtextSize = false
    
    // Store the values being adjusted for the preview
    @State private var previewTextVerticalFineTuning: Double = 0.0
    @State private var previewHeadlineTextSize: Double = 90.0
    @State private var previewSubtextTextSize: Double = 30.0
    
    // Track which slider is being adjusted for positioning
    @State private var activeSliderPosition: CGPoint = .zero
    
    // Computed property to check if settings are not default
    private var isNotDefault: Bool {
        return textVerticalPosition != .center ||
               textVerticalFineTuning != 0.0 ||
               headlineTextSize != KioskLayoutConstants.defaultHeadlineSize ||
               subtextTextSize != KioskLayoutConstants.defaultSubtextSize
    }
    
    var body: some View {
        ZStack {
            // Main settings card
            VStack(alignment: .leading, spacing: 20) {
                // Header with expand/collapse button
                Button(action: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "rectangle.and.pencil.and.ellipsis")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.blue)
                        }
                        
                        Text("Layout & Positioning")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isExpanded)
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                
                // Collapsible content
                if isExpanded {
                    VStack(spacing: 24) {
                        // Vertical Position Section
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeader(title: "Text Position", subtitle: "Choose where your text appears on screen")
                            
                            // Position presets
                            VStack(spacing: 12) {
                                ForEach(KioskLayoutConstants.VerticalTextPosition.allCases, id: \.self) { position in
                                    PositionOptionCard(
                                        position: position,
                                        isSelected: textVerticalPosition == position,
                                        onSelect: {
                                            textVerticalPosition = position
                                        }
                                    )
                                }
                            }
                            
                            // Fine-tuning slider with geometry reader
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Fine Adjustment")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                GeometryReader { geometry in
                                    HStack {
                                        Text("Higher")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        
                                        Slider(
                                            value: $textVerticalFineTuning,
                                            in: -50...50,
                                            step: 5,
                                            onEditingChanged: { editing in
                                                isAdjustingPosition = editing
                                                if editing {
                                                    previewTextVerticalFineTuning = textVerticalFineTuning
                                                    // Calculate slider position
                                                    let sliderProgress = (textVerticalFineTuning + 50) / 100
                                                    let sliderX = geometry.frame(in: .global).minX + (geometry.size.width * sliderProgress)
                                                    let sliderY = geometry.frame(in: .global).midY
                                                    activeSliderPosition = CGPoint(x: sliderX, y: sliderY)
                                                }
                                            }
                                        )
                                        .onChange(of: textVerticalFineTuning) { _, newValue in
                                            if isAdjustingPosition {
                                                previewTextVerticalFineTuning = newValue
                                            }
                                        }
                                        
                                        Text("Lower")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(height: 44)
                                
                                Text("Current: \(Int(textVerticalFineTuning)) points")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        
                        Divider()
                        
                        // Text Size Section
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeader(title: "Text Size", subtitle: "Adjust the size of your headline and supporting text")
                            
                            VStack(spacing: 16) {
                                // Headline size with geometry reader
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Headline Size")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Spacer()
                                        
                                        Text("\(Int(headlineTextSize))pt")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    GeometryReader { geometry in
                                        Slider(
                                            value: $headlineTextSize,
                                            in: KioskLayoutConstants.headlineSizeRange,
                                            step: 5,
                                            onEditingChanged: { editing in
                                                isAdjustingHeadlineSize = editing
                                                if editing {
                                                    previewHeadlineTextSize = headlineTextSize
                                                    // Calculate slider position
                                                    let range = KioskLayoutConstants.headlineSizeRange.upperBound - KioskLayoutConstants.headlineSizeRange.lowerBound
                                                    let sliderProgress = (headlineTextSize - KioskLayoutConstants.headlineSizeRange.lowerBound) / range
                                                    let sliderX = geometry.frame(in: .global).minX + (geometry.size.width * sliderProgress)
                                                    let sliderY = geometry.frame(in: .global).midY
                                                    activeSliderPosition = CGPoint(x: sliderX, y: sliderY)
                                                }
                                            }
                                        )
                                        .onChange(of: headlineTextSize) { _, newValue in
                                            if isAdjustingHeadlineSize {
                                                previewHeadlineTextSize = newValue
                                            }
                                        }
                                    }
                                    .frame(height: 44)
                                }
                                
                                // Subtext size with geometry reader
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Supporting Text Size")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Spacer()
                                        
                                        Text("\(Int(subtextTextSize))pt")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    GeometryReader { geometry in
                                        Slider(
                                            value: $subtextTextSize,
                                            in: KioskLayoutConstants.subtextSizeRange,
                                            step: 2,
                                            onEditingChanged: { editing in
                                                isAdjustingSubtextSize = editing
                                                if editing {
                                                    previewSubtextTextSize = subtextTextSize
                                                    // Calculate slider position
                                                    let range = KioskLayoutConstants.subtextSizeRange.upperBound - KioskLayoutConstants.subtextSizeRange.lowerBound
                                                    let sliderProgress = (subtextTextSize - KioskLayoutConstants.subtextSizeRange.lowerBound) / range
                                                    let sliderX = geometry.frame(in: .global).minX + (geometry.size.width * sliderProgress)
                                                    let sliderY = geometry.frame(in: .global).midY
                                                    activeSliderPosition = CGPoint(x: sliderX, y: sliderY)
                                                }
                                            }
                                        )
                                        .onChange(of: subtextTextSize) { _, newValue in
                                            if isAdjustingSubtextSize {
                                                previewSubtextTextSize = newValue
                                            }
                                        }
                                    }
                                    .frame(height: 44)
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Action buttons
                        HStack(spacing: 12) {
                            Button("Revert to Default") {
                                onRevertToDefault()
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isNotDefault ? Color.blue : Color(.systemGray4))
                            .foregroundStyle(isNotDefault ? .white : .secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .animation(.easeOut(duration: 0.1), value: isNotDefault)
                            .disabled(!isNotDefault)
                            
                            Button("Save Layout") {
                                onSave()
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(hasChanges ? Color.blue : Color(.systemGray4))
                            .foregroundStyle(hasChanges ? .white : .secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .animation(.easeOut(duration: 0.1), value: hasChanges)
                            .disabled(!hasChanges)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(24)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            
            // Live preview overlay positioned near active slider
            if isAdjustingPosition || isAdjustingHeadlineSize || isAdjustingSubtextSize {
                LivePreviewOverlay(
                    backgroundImage: backgroundImage,
                    headline: headline,
                    subtext: subtext,
                    textVerticalPosition: textVerticalPosition,
                    textVerticalFineTuning: isAdjustingPosition ? previewTextVerticalFineTuning : textVerticalFineTuning,
                    headlineTextSize: isAdjustingHeadlineSize ? previewHeadlineTextSize : headlineTextSize,
                    subtextTextSize: isAdjustingSubtextSize ? previewSubtextTextSize : subtextTextSize
                )
                .position(
                    x: min(max(100, activeSliderPosition.x), UIScreen.main.bounds.width - 100),
                    y: activeSliderPosition.y - 60
                )
                .transition(.opacity.combined(with: .scale))
                .animation(.easeInOut(duration: 0.2), value: isAdjustingPosition || isAdjustingHeadlineSize || isAdjustingSubtextSize)
            }
        }
    }
}
// MARK: - Live Preview Overlay

struct LivePreviewOverlay: View {
    let backgroundImage: UIImage?
    let headline: String
    let subtext: String
    let textVerticalPosition: KioskLayoutConstants.VerticalTextPosition
    let textVerticalFineTuning: Double
    let headlineTextSize: Double
    let subtextTextSize: Double
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
                .frame(width: 120, height: 80)
            
            // Background image if available
            if let backgroundImage = backgroundImage {
                Image(uiImage: backgroundImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 80)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Dark overlay
                RoundedRectangle(cornerRadius: 8)
                    .fill(.black.opacity(0.4))
                    .frame(width: 120, height: 80)
            }
            
            // Text overlay
            VStack(spacing: 2) {
                Text(headline)
                    .font(.system(size: max(6, headlineTextSize * 0.12), weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .shadow(radius: 1)
                
                if !subtext.isEmpty {
                    Text(subtext)
                        .font(.system(size: max(4, subtextTextSize * 0.12)))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .shadow(radius: 1)
                }
            }
            .frame(width: 100, height: 60)
            .offset(y: calculateTextOffset())
        }
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
    
    private func calculateTextOffset() -> CGFloat {
        let range: CGFloat = 15 // Max movement range up/down
        
        let baseOffset: CGFloat
        switch textVerticalPosition {
        case .top:
            baseOffset = -range * 0.7
        case .center:
            baseOffset = 0
        case .bottom:
            baseOffset = range * 0.7
        }
        
        // Apply fine tuning (scaled down) - FIXED: should be positive to match actual behavior
        let fineTuningOffset = (textVerticalFineTuning * 0.2)
        
        return baseOffset + fineTuningOffset
    }
}

// MARK: - Supporting Views

struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.blue)
                }
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            content
        }
        .padding(24)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct SectionHeader: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct PositionOptionCard: View {
    let position: KioskLayoutConstants.VerticalTextPosition
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
                    Text(position.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    Text(position.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Visual position indicator
                VStack(spacing: 2) {
                    Circle()
                        .fill(position == .top ? Color.blue : Color(.systemGray5))
                        .frame(width: 6, height: 6)
                    
                    Circle()
                        .fill(position == .center ? Color.blue : Color(.systemGray5))
                        .frame(width: 6, height: 6)
                    
                    Circle()
                        .fill(position == .bottom ? Color.blue : Color(.systemGray5))
                        .frame(width: 6, height: 6)
                }
                .padding(.trailing, 8)
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

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.medium)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.red.opacity(0.1))
            .foregroundStyle(.red)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ToastNotification: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            
            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .padding(.top, 60)
    }
}

// Keep existing ImagePicker implementation
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.isPresented = false
            
            guard let result = results.first else { return }
            
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                if let image = object as? UIImage {
                    DispatchQueue.main.async {
                        self?.parent.selectedImage = image
                    }
                }
            }
        }
    }
}

struct HomePageSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        HomePageSettingsView()
            .environmentObject(KioskStore())
    }
}
