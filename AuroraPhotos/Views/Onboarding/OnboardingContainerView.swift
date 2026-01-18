import SwiftUI

struct OnboardingContainerView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStep = 0
    @Environment(\.dismiss) private var dismiss
    
    private let totalSteps = 4
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch currentStep {
                case 0:
                    WelcomeStepView(onContinue: nextStep)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case 1:
                    SetupGuideStepView(onContinue: nextStep, onBack: previousStep)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case 2:
                    AddCredentialStepView(onContinue: nextStep, onBack: previousStep)
                        .environmentObject(appState)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case 3:
                    CompletionStepView(onFinish: finishOnboarding)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                default:
                    EmptyView()
                }
            }
            .animation(.default, value: currentStep)
            
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 24)
        }
        .background(.background)
    }
    
    private func nextStep() {
        withAnimation {
            currentStep = min(currentStep + 1, totalSteps - 1)
        }
    }
    
    private func previousStep() {
        withAnimation {
            currentStep = max(currentStep - 1, 0)
        }
    }
    
    private func finishOnboarding() {
        appState.hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        dismiss()
    }
}


struct WelcomeStepView: View {
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "photo.stack.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text("Welcome to Aurora Photos")
                    .font(.largeTitle.weight(.bold))
                
                Text("Upload photos and videos to Google Photos with unlimited storage")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "hand.draw.fill", title: "Drag & Drop", description: "Drop files into the app window to upload")
                FeatureRow(icon: "infinity", title: "Unlimited Storage", description: "No quota limits on your uploads")
                FeatureRow(icon: "arrow.left.arrow.right", title: "Copy or Move", description: "Choose to keep or delete originals")
                FeatureRow(icon: "bolt.fill", title: "Fast Uploads", description: "Multi-threaded concurrent uploads")
            }
            .padding(.horizontal, 48)
            
            Spacer()
            
            Button("Get Started") {
                onContinue()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 48)
        }
        .padding(.vertical, 40)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}


struct SetupGuideStepView: View {
    let onContinue: () -> Void
    let onBack: () -> Void
    
    @State private var copiedCommand = false
    
    private let adbCommand = "adb logcat | grep \"auth%2Fphotos.native\""
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                
                Text("One-Time Setup")
                    .font(.title.weight(.bold))
                
                Text("To enable unlimited uploads, you need credentials from the Google Photos Android app.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    StepCard(number: 1, title: "Install GmsCore", description: "On your Android device or emulator, install GmsCore from the ReVanced project.")
                    
                    StepCard(number: 2, title: "Install Google Photos ReVanced", description: "Download and install the patched Google Photos app.")
                    
                    StepCard(number: 3, title: "Connect via ADB", description: "Connect your device to your Mac via USB and enable ADB.")
                    
                    VStack(alignment: .leading, spacing: 8) {
                        StepCard(number: 4, title: "Run ADB Command", description: "Execute this command in Terminal:")
                        
                        HStack {
                            Text(adbCommand)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(adbCommand, forType: .string)
                                copiedCommand = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    copiedCommand = false
                                }
                            } label: {
                                Image(systemName: copiedCommand ? "checkmark" : "doc.on.doc")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(copiedCommand ? .green : .blue)
                        }
                        .padding(12)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    StepCard(number: 5, title: "Log into Google Photos", description: "Open the ReVanced app and log into your Google account.")
                    
                    StepCard(number: 6, title: "Copy Credential", description: "A log line will appear in Terminal. Copy the text starting with 'androidId=' to the end of the line.")
                }
                .padding(.horizontal, 24)
            }
            
            HStack {
                Button("Back") {
                    onBack()
                }
                
                Spacer()
                
                Button("Continue") {
                    onContinue()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 24)
    }
}

struct StepCard: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.accentColor))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}


struct AddCredentialStepView: View {
    @EnvironmentObject var appState: AppState
    let onContinue: () -> Void
    let onBack: () -> Void
    
    @State private var authString = ""
    @State private var validationResult: CredentialValidationResult?
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "person.badge.key.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                
                Text("Add Your Credential")
                    .font(.title.weight(.bold))
                
                Text("Paste the auth string you copied from the ADB output:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $authString)
                    .font(.system(.caption, design: .monospaced))
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                validationResult?.isValid == true ? Color.green :
                                    validationResult?.isValid == false ? Color.red :
                                    Color.primary.opacity(0.2),
                                lineWidth: 1
                            )
                    )
                    .onChange(of: authString) { _, newValue in
                        if !newValue.isEmpty {
                            validationResult = CredentialValidator.validate(newValue)
                        } else {
                            validationResult = nil
                        }
                    }
                
                if let result = validationResult {
                    HStack {
                        Image(systemName: result.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result.isValid ? .green : .red)
                        
                        if result.isValid, let email = result.email {
                            VStack(alignment: .leading) {
                                Text("Valid credential detected")
                                    .font(.subheadline)
                                Text("Account: \(email)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else if let error = result.error {
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                HStack {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(.green)
                    Text("Stored securely in macOS Keychain")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            HStack {
                Button("Back") {
                    onBack()
                }
                
                Spacer()
                
                Button("Skip") {
                    onContinue()
                }
                
                Button("Add Account") {
                    if let email = validationResult?.email {
                        let credential = Credential(
                            email: email,
                            authString: authString,
                            addedDate: Date()
                        )
                        KeychainService.shared.saveCredential(credential)
                        appState.selectedAccountEmail = email
                        onContinue()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(validationResult?.isValid != true)
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 24)
    }
}


struct CompletionStepView: View {
    let onFinish: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
            
            VStack(spacing: 8) {
                Text("You're All Set")
                    .font(.largeTitle.weight(.bold))
                
                Text("Aurora Photos is now in your menu bar")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    HStack(spacing: 16) {
                        Image(systemName: "wifi")
                        Image(systemName: "battery.100")
                        
                        Image(systemName: "photo.stack.fill")
                            .foregroundStyle(Color.accentColor)
                            .font(.title3)
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal, 40)
                
                Text("Click the icon to get started")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            
            Spacer()
            
            Button("Start Using Aurora") {
                onFinish()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 48)
        }
        .padding(.vertical, 40)
    }
}

#Preview {
    OnboardingContainerView()
        .environmentObject(AppState())
        .frame(width: 520, height: 600)
}
