import Foundation

struct Credential: Identifiable, Codable {
    var id: String { email }
    let email: String
    let authString: String
    let addedDate: Date
    
    var androidId: String? {
        parseValue(for: "androidId")
    }
    
    var token: String? {
        parseValue(for: "Token")
    }
    
    var clientSig: String? {
        parseValue(for: "client_sig")
    }
    
    var callerSig: String? {
        parseValue(for: "callerSig")
    }
    
    var language: String? {
        parseValue(for: "lang")
    }
    
    var deviceCountry: String? {
        parseValue(for: "device_country")
    }
    
    var sdkVersion: String? {
        parseValue(for: "sdk_version")
    }
    
    var googlePlayServicesVersion: String? {
        parseValue(for: "google_play_services_version")
    }
    
    private func parseValue(for key: String) -> String? {
        let pairs = authString.split(separator: "&")
        for pair in pairs {
            let keyValue = pair.split(separator: "=", maxSplits: 1)
            if keyValue.count == 2 && String(keyValue[0]) == key {
                return String(keyValue[1]).removingPercentEncoding
            }
        }
        return nil
    }
}

struct UploadItem: Identifiable {
    let id = UUID()
    let filePath: URL
    var fileName: String { filePath.lastPathComponent }
    var status: UploadStatus = .queued
    var progress: Double = 0
    var errorMessage: String?
    var mediaKey: String?
    
    var statusText: String {
        switch status {
        case .queued: return "Queued"
        case .hashing: return "Hashing..."
        case .checking: return "Checking library..."
        case .uploading: return "\(Int(progress * 100))%"
        case .finalizing: return "Finalizing..."
        case .completed: return "Done"
        case .duplicate: return "Duplicate"
        case .error: return errorMessage ?? "Error"
        case .cancelled: return "Cancelled"
        }
    }
}

enum UploadStatus {
    case queued
    case hashing
    case checking
    case uploading
    case finalizing
    case completed
    case duplicate
    case error
    case cancelled
}

struct UploadHistoryEntry: Identifiable, Codable {
    let id: UUID
    let fileName: String
    let filePath: String
    let uploadDate: Date
    let mediaKey: String?
    let wasDeleted: Bool
    let accountEmail: String
    
    init(from upload: UploadItem, wasDeleted: Bool, accountEmail: String) {
        self.id = upload.id
        self.fileName = upload.fileName
        self.filePath = upload.filePath.path
        self.uploadDate = Date()
        self.mediaKey = upload.mediaKey
        self.wasDeleted = wasDeleted
        self.accountEmail = accountEmail
    }
}
