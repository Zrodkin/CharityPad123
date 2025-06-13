import SwiftUI
import PhotosUI

struct HomePageSettingsView: View {
    @EnvironmentObject private var kioskStore: KioskStore
    @State private var headline: String = ""
    @State private var subtext: String = ""
    @State private var homePageEnabled = true
    @State private var showingLogoImagePicker = false
    @State private var showingBackgroundImagePicker = false
    @State private var showToast = false
    @State private var toastMessage = "Settings saved"
    
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
                    // Visual Assets Card
                    SettingsCard(title: "Visual Assets", icon: "photo.fill") {
                        VStack(spacing: 24) {
                            // Organization Logo Section
                            VStack(alignment: .leading, spacing: 16) {
                                SectionHeader(title: "Organization Logo", subtitle: "Displayed prominently on your kiosk")
                                
                                HStack(spacing: 16) {
                                    // Logo preview
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color(.secondarySystemBackground))
                                            .frame(width: 100, height: 100)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(Color(.separator), lineWidth: 1)
                                            )
                                        
                                        if let logoImage = kioskStore.logoImage {
                                            Image(uiImage: logoImage)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 90, height: 90)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                        } else {
                                            VStack(spacing: 8) {
                                                Image(systemName: "photo")
                                                    .font(.title2)
                                                    .foregroundStyle(.tertiary)
                                                
                                                Text("No Logo")
                                                    .font(.caption)
                                                    .foregroundStyle(.tertiary)
                                            }
                                        }
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 12) {
                                        Button("Upload Logo") {
                                            showingLogoImagePicker = true
                                        }
                                        .buttonStyle(SecondaryButtonStyle())
                                        
                                        if kioskStore.logoImage != nil {
                                            Button("Remove") {
                                                kioskStore.logoImage = nil
                                                autoSaveSettings()
                                            }
                                            .buttonStyle(DestructiveButtonStyle())
                                        }
                                        
                                        Text("Recommended: 200×200px PNG or JPG")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                            }
                            
                            Divider()
                            
                            // Background Image Section
                            VStack(alignment: .leading, spacing: 16) {
                                SectionHeader(title: "Background Image", subtitle: "Sets the mood for your donation experience")
                                
                                VStack(spacing: 16) {
                                    // Background preview with text overlay
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color(.secondarySystemBackground))
                                            .frame(height: 200)
                                        
                                        if let backgroundImage = kioskStore.backgroundImage {
                                            Image(uiImage: backgroundImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(height: 200)
                                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                        } else {
                                            VStack(spacing: 12) {
                                                Image(systemName: "photo.on.rectangle")
                                                    .font(.system(size: 40))
                                                    .foregroundStyle(.tertiary)
                                                
                                                Text("No Background Image")
                                                    .font(.subheadline)
                                                    .foregroundStyle(.tertiary)
                                            }
                                        }
                                        
                                        // Text preview overlay (only if background exists)
                                        if kioskStore.backgroundImage != nil {
                                            Rectangle()
                                                .fill(.black.opacity(0.4))
                                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                            
                                            VStack(spacing: 8) {
                                                Text(headline.isEmpty ? "Sample Title" : headline)
                                                    .font(.title)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.white)
                                                
                                                if !subtext.isEmpty {
                                                    Text(subtext)
                                                        .font(.subheadline)
                                                        .foregroundColor(.white.opacity(0.9))
                                                        .multilineTextAlignment(.center)
                                                }
                                            }
                                            .padding()
                                        }
                                    }
                                    
                                    HStack(spacing: 12) {
                                        Button("Upload Background") {
                                            showingBackgroundImagePicker = true
                                        }
                                        .buttonStyle(SecondaryButtonStyle())
                                        
                                        if kioskStore.backgroundImage != nil {
                                            Button("Remove") {
                                                kioskStore.backgroundImage = nil
                                                autoSaveSettings()
                                            }
                                            .buttonStyle(DestructiveButtonStyle())
                                        }
                                        
                                        Spacer()
                                    }
                                    
                                    Text("Recommended: 1920×1080px for best quality. A dark overlay will be applied automatically.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
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
                            
                            // Live Preview
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: "Preview", subtitle: "How your text will appear")
                                
                                VStack(spacing: 12) {
                                    Text(headline.isEmpty ? "Your Headline Here" : headline)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.center)
                                    
                                    if !subtext.isEmpty {
                                        Text(subtext)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.center)
                                    } else {
                                        Text("Your supporting text will appear here")
                                            .font(.subheadline)
                                            .foregroundStyle(.tertiary)
                                            .italic()
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(20)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.tertiarySystemBackground))
                                )
                            }
                        }
                    }
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
        }
        .sheet(isPresented: $showingLogoImagePicker) {
            ImagePicker(selectedImage: $kioskStore.logoImage, isPresented: $showingLogoImagePicker)
                .onDisappear {
                    if kioskStore.logoImage != nil {
                        autoSaveSettings()
                    }
                }
        }
        .sheet(isPresented: $showingBackgroundImagePicker) {
            ImagePicker(selectedImage: $kioskStore.backgroundImage, isPresented: $showingBackgroundImagePicker)
                .onDisappear {
                    if kioskStore.backgroundImage != nil {
                        autoSaveSettings()
                    }
                }
        }
       
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

// MARK: - Supporting Views (unchanged)

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
