import SwiftUI

struct AccountsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAddAccount = false
    @State private var credentials: [Credential] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accounts")
                .font(.headline)
            
            if credentials.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("No accounts added")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(credentials) { credential in
                    AccountRow(
                        credential: credential,
                        isSelected: credential.email == appState.selectedAccountEmail,
                        onSelect: {
                            appState.selectedAccountEmail = credential.email
                        },
                        onDelete: {
                            deleteCredential(credential)
                        }
                    )
                }
            }
            
            Divider()
            
            Button {
                showAddAccount = true
            } label: {
                Label("Add Account", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
        }
        .padding()
        .frame(width: 280)
        .sheet(isPresented: $showAddAccount) {
            AddCredentialSheet(onAdd: { credential in
                credentials.append(credential)
                appState.selectedAccountEmail = credential.email
                KeychainService.shared.saveCredential(credential)
            })
        }
        .onAppear {
            loadCredentials()
        }
    }
    
    private func loadCredentials() {
        credentials = KeychainService.shared.loadCredentials()
        if credentials.count == 1, appState.selectedAccountEmail == nil {
            appState.selectedAccountEmail = credentials.first?.email
        }
        if let selected = appState.selectedAccountEmail,
           !credentials.contains(where: { $0.email == selected }) {
            appState.selectedAccountEmail = credentials.first?.email
        }
    }
    
    private func deleteCredential(_ credential: Credential) {
        KeychainService.shared.deleteCredential(email: credential.email)
        credentials.removeAll { $0.id == credential.id }
        if appState.selectedAccountEmail == credential.email {
            appState.selectedAccountEmail = credentials.first?.email
        }
    }
}

struct AccountRow: View {
    let credential: Credential
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? .blue : .secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(credential.email)
                    .font(.subheadline)
                
                Text("Added \(credential.addedDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            if isHovered {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(isSelected ? Color.blue.opacity(0.1) : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct AddCredentialSheet: View {
    let onAdd: (Credential) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var authString = ""
    @State private var validationResult: CredentialValidationResult?
    @State private var isValidating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Add Account")
                .font(.title2.weight(.semibold))
            
            Text("Paste your credential string from the ADB logcat output:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            TextEditor(text: $authString)
                .font(.system(.caption, design: .monospaced))
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.2))
                )
                .onChange(of: authString) { _, newValue in
                    validateCredential(newValue)
                }
            
            if let result = validationResult {
                HStack {
                    Image(systemName: result.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(result.isValid ? .green : .red)
                    
                    if result.isValid, let email = result.email {
                        Text("Account: \(email)")
                            .font(.subheadline)
                    } else if let error = result.error {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
            }
            
            HStack {
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Add Account") {
                    if let email = validationResult?.email {
                        let credential = Credential(
                            email: email,
                            authString: authString,
                            addedDate: Date()
                        )
                        onAdd(credential)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(validationResult?.isValid != true)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
    
    private func validateCredential(_ string: String) {
        guard !string.isEmpty else {
            validationResult = nil
            return
        }
        
        let result = CredentialValidator.validate(string)
        validationResult = result
    }
}

struct CredentialValidationResult {
    let isValid: Bool
    let email: String?
    let error: String?
}

enum CredentialValidator {
    static func validate(_ authString: String) -> CredentialValidationResult {
        let requiredFields = ["androidId", "Email", "Token", "client_sig", "service"]
        
        var params: [String: String] = [:]
        let pairs = authString.split(separator: "&")
        
        for pair in pairs {
            let keyValue = pair.split(separator: "=", maxSplits: 1)
            if keyValue.count == 2 {
                params[String(keyValue[0])] = String(keyValue[1])
            }
        }
        
        var missingFields: [String] = []
        for field in requiredFields {
            if params[field] == nil || params[field]?.isEmpty == true {
                missingFields.append(field)
            }
        }
        
        if !missingFields.isEmpty {
            return CredentialValidationResult(
                isValid: false,
                email: nil,
                error: "Missing: \(missingFields.joined(separator: ", "))"
            )
        }
        
        guard let email = params["Email"], !email.isEmpty else {
            return CredentialValidationResult(
                isValid: false,
                email: nil,
                error: "Email not found"
            )
        }
        
        return CredentialValidationResult(
            isValid: true,
            email: email.removingPercentEncoding ?? email,
            error: nil
        )
    }
}

#Preview {
    AccountsView()
        .environmentObject(AppState())
}
