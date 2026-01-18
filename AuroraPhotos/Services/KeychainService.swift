import Foundation
import KeychainAccess

class KeychainService {
    static let shared = KeychainService()
    
    private let keychain = Keychain(service: "com.aurora.photos")
    private let credentialsKey = "credentials"
    
    private init() {}
    
    func saveCredential(_ credential: Credential) {
        var credentials = loadCredentials()
        credentials.removeAll { $0.email == credential.email }
        credentials.append(credential)
        saveCredentials(credentials)
    }
    
    func loadCredentials() -> [Credential] {
        guard let data = try? keychain.getData(credentialsKey),
              let credentials = try? JSONDecoder().decode([Credential].self, from: data) else {
            return []
        }
        return credentials
    }
    
    func deleteCredential(email: String) {
        var credentials = loadCredentials()
        credentials.removeAll { $0.email == email }
        saveCredentials(credentials)
    }
    
    func getCredential(for email: String) -> Credential? {
        return loadCredentials().first { $0.email == email }
    }
    
    private func saveCredentials(_ credentials: [Credential]) {
        guard let data = try? JSONEncoder().encode(credentials) else { return }
        try? keychain.set(data, key: credentialsKey)
    }
    
    func clearAll() {
        try? keychain.removeAll()
    }
}
