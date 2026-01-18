import Foundation
import SwiftProtobuf
import Compression

class GooglePhotosAPI {
    private let credential: Credential
    private let appState: AppState
    
    private let androidAPIVersion: Int64 = 28
    private var model: String = "Pixel XL"
    private let make: String = "Google"
    private let clientVersionCode: Int64 = 49029607
    
    private var authCache: (token: String, expiry: Date)?
    
    private var userAgent: String {
        "com.google.android.apps.photos/\(clientVersionCode) (Linux; U; Android 9; \(credential.language ?? "en"); \(model); Build/PQ2A.190205.001; Cronet/127.0.6510.5) (gzip)"
    }
    
    init(credential: Credential, appState: AppState) {
        self.credential = credential
        self.appState = appState
    }
    
    private func getBearerToken() async throws -> String {
        if let cached = authCache, cached.expiry > Date() {
            return cached.token
        }
        
        let authResponse = try await getAuthToken()
        
        guard let token = authResponse["Auth"], !token.isEmpty else {
            throw APIError.authenticationFailed("No auth token in response")
        }
        
        guard let expiryString = authResponse["Expiry"],
              let expiry = TimeInterval(expiryString) else {
            throw APIError.authenticationFailed("No expiry in response")
        }
        
        authCache = (token, Date(timeIntervalSince1970: expiry))
        return token
    }
    
    private func getAuthToken() async throws -> [String: String] {
        guard let androidId = credential.androidId,
              let clientSig = credential.clientSig,
              let token = credential.token else {
            throw APIError.invalidCredential
        }
        
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "androidId", value: androidId),
            URLQueryItem(name: "app", value: "com.google.android.apps.photos"),
            URLQueryItem(name: "client_sig", value: clientSig),
            URLQueryItem(name: "callerPkg", value: "com.google.android.apps.photos"),
            URLQueryItem(name: "callerSig", value: credential.callerSig ?? clientSig),
            URLQueryItem(name: "device_country", value: credential.deviceCountry ?? "us"),
            URLQueryItem(name: "Email", value: credential.email),
            URLQueryItem(name: "google_play_services_version", value: credential.googlePlayServicesVersion ?? "242913058"),
            URLQueryItem(name: "lang", value: credential.language ?? "en"),
            URLQueryItem(name: "oauth2_foreground", value: "1"),
            URLQueryItem(name: "sdk_version", value: credential.sdkVersion ?? "28"),
            URLQueryItem(name: "service", value: "oauth2:https://www.googleapis.com/auth/photos.native"),
            URLQueryItem(name: "Token", value: token),
        ]
        
        guard let body = components.percentEncodedQuery?.data(using: .utf8) else {
            throw APIError.invalidRequest
        }
        
        var request = URLRequest(url: URL(string: "https://android.googleapis.com/auth")!)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("com.google.android.apps.photos", forHTTPHeaderField: "app")
        request.setValue("Keep-Alive", forHTTPHeaderField: "Connection")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(androidId, forHTTPHeaderField: "device")
        request.setValue("GoogleAuth/1.4 (Pixel XL PQ2A.190205.001); gzip", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.authenticationFailed("HTTP error")
        }
        
        let decompressed = try decompressGzip(data) ?? data
        
        guard let responseString = String(data: decompressed, encoding: .utf8) else {
            throw APIError.authenticationFailed("Invalid response encoding")
        }
        
        var result: [String: String] = [:]
        for line in responseString.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                result[String(parts[0])] = String(parts[1])
            }
        }
        
        return result
    }
    
    func getUploadToken(sha1Base64: String, fileSize: Int64) async throws -> String {
        let bearerToken = try await getBearerToken()
        
        var protoBody = GetUploadToken()
        protoBody.f1 = 2
        protoBody.f2 = 2
        protoBody.f3 = 1
        protoBody.f4 = 3
        protoBody.fileSizeBytes = fileSize
        
        let serializedData = try protoBody.serializedData()
        
        var request = URLRequest(url: URL(string: "https://photos.googleapis.com/data/upload/uploadmedia/interactive")!)
        request.httpMethod = "POST"
        request.httpBody = serializedData
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
        request.setValue(credential.language ?? "en", forHTTPHeaderField: "Accept-Language")
        request.setValue("application/x-protobuf", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("sha1=\(sha1Base64)", forHTTPHeaderField: "X-Goog-Hash")
        request.setValue("\(fileSize)", forHTTPHeaderField: "X-Upload-Content-Length")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.uploadFailed("Failed to get upload token")
        }
        
        guard let uploadToken = httpResponse.value(forHTTPHeaderField: "X-GUploader-UploadID") else {
            throw APIError.uploadFailed("No upload token in response")
        }
        
        return uploadToken
    }
    
    func findRemoteMediaByHash(sha1Hash: Data) async throws -> String? {
        let bearerToken = try await getBearerToken()
        
        var protoBody = HashCheck()
        var field1 = HashCheckField1Type()
        var field1_1 = HashCheckField1TypeField1Type()
        field1_1.sha1Hash = sha1Hash
        field1.field1 = field1_1
        field1.field2 = HashCheckField1TypeField2Type()
        protoBody.field1 = field1
        
        let serializedData = try protoBody.serializedData()
        
        var request = URLRequest(url: URL(string: "https://photosdata-pa.googleapis.com/6439526531001121323/5084965799730810217")!)
        request.httpMethod = "POST"
        request.httpBody = serializedData
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
        request.setValue(credential.language ?? "en", forHTTPHeaderField: "Accept-Language")
        request.setValue("application/x-protobuf", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            return nil
        }
        
        let decompressed = try decompressGzip(data) ?? data
        let pbResp = try RemoteMatches(serializedBytes: decompressed)
        
        let mediaKey = pbResp.mediaKey
        return mediaKey.isEmpty ? nil : mediaKey
    }
    
    func uploadFile(filePath: URL, uploadToken: String, progressCallback: @escaping (Double) -> Void) async throws -> CommitToken {
        let bearerToken = try await getBearerToken()
        let fileData = try Data(contentsOf: filePath)
        
        print("[GooglePhotosAPI] Uploading file: \(filePath.lastPathComponent), size=\(fileData.count)")
        
        let uploadURL = "https://photos.googleapis.com/data/upload/uploadmedia/interactive?upload_id=\(uploadToken)"
        
        var request = URLRequest(url: URL(string: uploadURL)!)
        request.httpMethod = "PUT"
        request.httpBody = fileData
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
        request.setValue(credential.language ?? "en", forHTTPHeaderField: "Accept-Language")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await uploadWithProgress(request: request, data: fileData, progressCallback: progressCallback)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.uploadFailed("No HTTP response")
        }
        
        print("[GooglePhotosAPI] Upload response status: \(httpResponse.statusCode), data size: \(data.count)")
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.uploadFailed("Upload failed with status \(httpResponse.statusCode)")
        }
        
        
        let commitToken = try CommitToken(serializedBytes: data)
        print("[GooglePhotosAPI] CommitToken parsed: field1=\(commitToken.field1), field2 size=\(commitToken.field2.count)")
        
        return commitToken
    }
    
    func commitUpload(commitToken: CommitToken, fileName: String, sha1Hash: Data, timestamp: Int64, storageSaver: Bool, useQuota: Bool) async throws -> String {
        let bearerToken = try await getBearerToken()
        
        var qualityVal: Int64 = 3
        var uploadModel = model
        
        if storageSaver {
            qualityVal = 1
            uploadModel = "Pixel 2"
        }
        
        if useQuota {
            uploadModel = "Pixel 8"
        }
        
        print("[GooglePhotosAPI] Commit upload: fileName=\(fileName), storageSaver=\(storageSaver), useQuota=\(useQuota)")
        print("[GooglePhotosAPI] CommitToken: field1=\(commitToken.field1), field2 size=\(commitToken.field2.count)")
        
        var protoBody = CommitUpload()
        
        var field1 = CommitUploadField1Type()
        var field1_1 = CommitUploadField1TypeField1Type()
        field1_1.field1 = commitToken.field1
        field1_1.field2 = commitToken.field2
        field1.field1 = field1_1
        field1.fileName = fileName
        field1.sha1Hash = sha1Hash
        
        var field1_4 = CommitUploadField1TypeField4Type()
        field1_4.fileLastModifiedTimestamp = timestamp
        field1_4.field2 = 46000000
        field1.field4 = field1_4
        field1.quality = qualityVal
        field1.field10 = 1
        protoBody.field1 = field1
        
        var field2 = CommitUploadField2Type()
        field2.model = uploadModel
        field2.make = make
        field2.androidApiVersion = androidAPIVersion
        protoBody.field2 = field2
        
        protoBody.field3 = Data([1, 3])
        
        let serializedData = try protoBody.serializedData()
        
        var request = URLRequest(url: URL(string: "https://photosdata-pa.googleapis.com/6439526531001121323/16538846908252377752")!)
        request.httpMethod = "POST"
        request.httpBody = serializedData
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
        request.setValue(credential.language ?? "en", forHTTPHeaderField: "Accept-Language")
        request.setValue("application/x-protobuf", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("CgcIAhClARgC", forHTTPHeaderField: "x-goog-ext-173412678-bin")
        request.setValue("CgIIAg==", forHTTPHeaderField: "x-goog-ext-174067345-bin")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.uploadFailed("No HTTP response")
        }
        
        print("[GooglePhotosAPI] Commit response status: \(httpResponse.statusCode)")
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            let decompressed = try? decompressGzip(data) ?? data
            let bodyStr = String(data: decompressed ?? data, encoding: .utf8) ?? "non-utf8 data"
            print("[GooglePhotosAPI] Commit failed: status=\(httpResponse.statusCode), body=\(bodyStr)")
            throw APIError.uploadFailed("Commit failed with status \(httpResponse.statusCode)")
        }
        
        let decompressed = try decompressGzip(data) ?? data
        print("[GooglePhotosAPI] Commit response size: \(decompressed.count) bytes")
        
        let pbResp = try CommitUploadResponse(serializedBytes: decompressed)
        
        guard let mediaKey = pbResp.field1?.field3?.mediaKey, !mediaKey.isEmpty else {
            print("[GooglePhotosAPI] No media key! field1=\(pbResp.field1 != nil), field3=\(pbResp.field1?.field3 != nil)")
            throw APIError.uploadFailed("No media key in response")
        }
        
        return mediaKey
    }
    
    private func uploadWithProgress(request: URLRequest, data: Data, progressCallback: @escaping (Double) -> Void) async throws -> (Data, URLResponse) {
        progressCallback(0.5)
        let result = try await URLSession.shared.data(for: request)
        progressCallback(1.0)
        return result
    }
    
    private func decompressGzip(_ data: Data) throws -> Data? {
        guard data.count >= 2, data[0] == 0x1f, data[1] == 0x8b else {
            return nil
        }
        
        let decompressedSize = data.count * 10
        var decompressedData = Data(count: decompressedSize)
        
        let result = decompressedData.withUnsafeMutableBytes { destBuffer in
            data.dropFirst(10).withUnsafeBytes { srcBuffer in
                compression_decode_buffer(
                    destBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    decompressedSize,
                    srcBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    data.count - 10,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        
        guard result > 0 else { return nil }
        decompressedData.count = result
        return decompressedData
    }
}

enum APIError: LocalizedError {
    case invalidCredential
    case invalidRequest
    case authenticationFailed(String)
    case uploadFailed(String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidCredential: return "Invalid credential"
        case .invalidRequest: return "Invalid request"
        case .authenticationFailed(let msg): return "Authentication failed: \(msg)"
        case .uploadFailed(let msg): return "Upload failed: \(msg)"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        }
    }
}

struct GetUploadToken: SwiftProtobuf.Message, Equatable {
    static let protoMessageName = "GetUploadToken"
    var unknownFields = SwiftProtobuf.UnknownStorage()
    var f1: Int64 = 0
    var f2: Int64 = 0
    var f3: Int64 = 0
    var f4: Int64 = 0
    var fileSizeBytes: Int64 = 0
    init() {}
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {}
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if f1 != 0 { try visitor.visitSingularInt64Field(value: f1, fieldNumber: 1) }
        if f2 != 0 { try visitor.visitSingularInt64Field(value: f2, fieldNumber: 2) }
        if f3 != 0 { try visitor.visitSingularInt64Field(value: f3, fieldNumber: 3) }
        if f4 != 0 { try visitor.visitSingularInt64Field(value: f4, fieldNumber: 4) }
        if fileSizeBytes != 0 { try visitor.visitSingularInt64Field(value: fileSizeBytes, fieldNumber: 5) }
        try unknownFields.traverse(visitor: &visitor)
    }
    func isEqualTo(message: any SwiftProtobuf.Message) -> Bool { (message as? Self) == self }
}

struct HashCheck: SwiftProtobuf.Message, Equatable {
    static let protoMessageName = "HashCheck"
    var unknownFields = SwiftProtobuf.UnknownStorage()
    var field1: HashCheckField1Type?
    init() {}
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {}
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let v = field1 { try visitor.visitSingularMessageField(value: v, fieldNumber: 1) }
        try unknownFields.traverse(visitor: &visitor)
    }
    func isEqualTo(message: any SwiftProtobuf.Message) -> Bool { (message as? Self) == self }
}

struct HashCheckField1Type: SwiftProtobuf.Message, Equatable {
    static let protoMessageName = "HashCheckField1Type"
    var unknownFields = SwiftProtobuf.UnknownStorage()
    var field1: HashCheckField1TypeField1Type?
    var field2: HashCheckField1TypeField2Type?
    init() {}
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {}
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let v = field1 { try visitor.visitSingularMessageField(value: v, fieldNumber: 1) }
        if let v = field2 { try visitor.visitSingularMessageField(value: v, fieldNumber: 2) }
        try unknownFields.traverse(visitor: &visitor)
    }
    func isEqualTo(message: any SwiftProtobuf.Message) -> Bool { (message as? Self) == self }
}

struct HashCheckField1TypeField1Type: SwiftProtobuf.Message, Equatable {
    static let protoMessageName = "HashCheckField1TypeField1Type"
    var unknownFields = SwiftProtobuf.UnknownStorage()
    var sha1Hash: Data = Data()
    init() {}
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {}
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !sha1Hash.isEmpty { try visitor.visitSingularBytesField(value: sha1Hash, fieldNumber: 1) }
        try unknownFields.traverse(visitor: &visitor)
    }
    func isEqualTo(message: any SwiftProtobuf.Message) -> Bool { (message as? Self) == self }
}

struct HashCheckField1TypeField2Type: SwiftProtobuf.Message, Equatable {
    static let protoMessageName = "HashCheckField1TypeField2Type"
    var unknownFields = SwiftProtobuf.UnknownStorage()
    init() {}
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {}
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        try unknownFields.traverse(visitor: &visitor)
    }
    func isEqualTo(message: any SwiftProtobuf.Message) -> Bool { (message as? Self) == self }
}

struct RemoteMatches: SwiftProtobuf.Message, Equatable {
    static let protoMessageName = "RemoteMatches"
    var unknownFields = SwiftProtobuf.UnknownStorage()
    var field1: RemoteMatchesField1Type?
    
    var mediaKey: String {
        return field1?.field2?.field2?.mediaKey ?? ""
    }
    
    init() {}
    init(serializedBytes data: Data) throws {
        self.init()
        try merge(serializedBytes: data)
    }
    
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularMessageField(value: &field1)
            default: break
            }
        }
    }
    
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let v = field1 { try visitor.visitSingularMessageField(value: v, fieldNumber: 1) }
        try unknownFields.traverse(visitor: &visitor)
    }
    func isEqualTo(message: any SwiftProtobuf.Message) -> Bool { (message as? Self) == self }
}

struct RemoteMatchesField1Type: SwiftProtobuf.Message, Equatable {
    static let protoMessageName = "RemoteMatchesField1Type"
    var unknownFields = SwiftProtobuf.UnknownStorage()
    var field2: RemoteMatchesField1TypeField2Type?
    init() {}
    
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 2: try decoder.decodeSingularMessageField(value: &field2)
            default: break
            }
        }
    }
    
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let v = field2 { try visitor.visitSingularMessageField(value: v, fieldNumber: 2) }
        try unknownFields.traverse(visitor: &visitor)
    }
    func isEqualTo(message: any SwiftProtobuf.Message) -> Bool { (message as? Self) == self }
}

struct RemoteMatchesField1TypeField2Type: SwiftProtobuf.Message, Equatable {
    static let protoMessageName = "RemoteMatchesField1TypeField2Type"
    var unknownFields = SwiftProtobuf.UnknownStorage()
    var field2: RemoteMatchesField1TypeField2TypeField2Type?
    init() {}
    
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 2: try decoder.decodeSingularMessageField(value: &field2)
            default: break
            }
        }
    }
    
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let v = field2 { try visitor.visitSingularMessageField(value: v, fieldNumber: 2) }
        try unknownFields.traverse(visitor: &visitor)
    }
    func isEqualTo(message: any SwiftProtobuf.Message) -> Bool { (message as? Self) == self }
}

struct RemoteMatchesField1TypeField2TypeField2Type: SwiftProtobuf.Message, Equatable {
    static let protoMessageName = "RemoteMatchesField1TypeField2TypeField2Type"
    var unknownFields = SwiftProtobuf.UnknownStorage()
    var mediaKey: String = ""
    init() {}
    
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &mediaKey)
            default: break
            }
        }
    }
    
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !mediaKey.isEmpty { try visitor.visitSingularStringField(value: mediaKey, fieldNumber: 1) }
        try unknownFields.traverse(visitor: &visitor)
    }
    func isEqualTo(message: any SwiftProtobuf.Message) -> Bool { (message as? Self) == self }
}

struct CommitToken: SwiftProtobuf.Message, Equatable {
    static let protoMessageName = "CommitToken"
    var unknownFields = SwiftProtobuf.UnknownStorage()
    var field1: Int64 = 0
    var field2: Data = Data()
    
    init() {}
    init(serializedBytes data: Data) throws {
        self.init()
        try merge(serializedBytes: data)
    }
    
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularInt64Field(value: &field1)
            case 2: try decoder.decodeSingularBytesField(value: &field2)
            default: break
            }
        }
    }
    
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if field1 != 0 { try visitor.visitSingularInt64Field(value: field1, fieldNumber: 1) }
        if !field2.isEmpty { try visitor.visitSingularBytesField(value: field2, fieldNumber: 2) }
        try unknownFields.traverse(visitor: &visitor)
    }
    func isEqualTo(message: any SwiftProtobuf.Message) -> Bool { (message as? Self) == self }
}

struct CommitUpload: SwiftProtobuf.Message, Equatable {
    static let protoMessageName = "CommitUpload"
    var unknownFields = SwiftProtobuf.UnknownStorage()
    var field1: CommitUploadField1Type?
    var field2: CommitUploadField2Type?
    var field3: Data = Data()
    init() {}
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {}
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let v = field1 { try visitor.visitSingularMessageField(value: v, fieldNumber: 1) }
        if let v = field2 { try visitor.visitSingularMessageField(value: v, fieldNumber: 2) }
        if !field3.isEmpty { try visitor.visitSingularBytesField(value: field3, fieldNumber: 3) }
        try unknownFields.traverse(visitor: &visitor)
    }
    func isEqualTo(message: any SwiftProtobuf.Message) -> Bool { (message as? Self) == self }
}

struct CommitUploadField1Type: SwiftProtobuf.Message, Equatable {
    static let protoMessageName = "CommitUploadField1Type"
    var unknownFields = SwiftProtobuf.UnknownStorage()
    var field1: CommitUploadField1TypeField1Type?
    var fileName: String = ""
    var sha1Hash: Data = Data()
    var field4: CommitUploadField1TypeField4Type?
    var quality: Int64 = 0
    var field10: Int64 = 0
    init() {}
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {}
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let v = field1 { try visitor.visitSingularMessageField(value: v, fieldNumber: 1) }
        if !fileName.isEmpty { try visitor.visitSingularStringField(value: fileName, fieldNumber: 2) }
        if !sha1Hash.isEmpty { try visitor.visitSingularBytesField(value: sha1Hash, fieldNumber: 3) }
        if let v = field4 { try visitor.visitSingularMessageField(value: v, fieldNumber: 4) }
        if quality != 0 { try visitor.visitSingularInt64Field(value: quality, fieldNumber: 7) }
        if field10 != 0 { try visitor.visitSingularInt64Field(value: field10, fieldNumber: 10) }
        try unknownFields.traverse(visitor: &visitor)
    }
    func isEqualTo(message: any SwiftProtobuf.Message) -> Bool { (message as? Self) == self }
}

struct CommitUploadField1TypeField1Type: SwiftProtobuf.Message, Equatable {
    static let protoMessageName = "CommitUploadField1TypeField1Type"
    var unknownFields = SwiftProtobuf.UnknownStorage()
    var field1: Int64 = 0
    var field2: Data = Data()
    init() {}
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {}
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if field1 != 0 { try visitor.visitSingularInt64Field(value: field1, fieldNumber: 1) }
        if !field2.isEmpty { try visitor.visitSingularBytesField(value: field2, fieldNumber: 2) }
        try unknownFields.traverse(visitor: &visitor)
    }
    func isEqualTo(message: any SwiftProtobuf.Message) -> Bool { (message as? Self) == self }
}

struct CommitUploadField1TypeField4Type: SwiftProtobuf.Message, Equatable {
    static let protoMessageName = "CommitUploadField1TypeField4Type"
    var unknownFields = SwiftProtobuf.UnknownStorage()
    var fileLastModifiedTimestamp: Int64 = 0
    var field2: Int64 = 0
    init() {}
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {}
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if fileLastModifiedTimestamp != 0 { try visitor.visitSingularInt64Field(value: fileLastModifiedTimestamp, fieldNumber: 1) }
        if field2 != 0 { try visitor.visitSingularInt64Field(value: field2, fieldNumber: 2) }
        try unknownFields.traverse(visitor: &visitor)
    }
    func isEqualTo(message: any SwiftProtobuf.Message) -> Bool { (message as? Self) == self }
}

struct CommitUploadField2Type: SwiftProtobuf.Message, Equatable {
    static let protoMessageName = "CommitUploadField2Type"
    var unknownFields = SwiftProtobuf.UnknownStorage()
    var model: String = ""
    var make: String = ""
    var androidApiVersion: Int64 = 0
    init() {}
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {}
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !model.isEmpty { try visitor.visitSingularStringField(value: model, fieldNumber: 3) }
        if !make.isEmpty { try visitor.visitSingularStringField(value: make, fieldNumber: 4) }
        if androidApiVersion != 0 { try visitor.visitSingularInt64Field(value: androidApiVersion, fieldNumber: 5) }
        try unknownFields.traverse(visitor: &visitor)
    }
    func isEqualTo(message: any SwiftProtobuf.Message) -> Bool { (message as? Self) == self }
}

struct CommitUploadResponse: SwiftProtobuf.Message, Equatable {
    static let protoMessageName = "CommitUploadResponse"
    var unknownFields = SwiftProtobuf.UnknownStorage()
    var field1: CommitUploadResponseField1?
    
    init() {}
    init(serializedBytes data: Data) throws {
        self.init()
        try merge(serializedBytes: data)
    }
    
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularMessageField(value: &field1)
            default: break
            }
        }
    }
    
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let v = field1 { try visitor.visitSingularMessageField(value: v, fieldNumber: 1) }
        try unknownFields.traverse(visitor: &visitor)
    }
    func isEqualTo(message: any SwiftProtobuf.Message) -> Bool { (message as? Self) == self }
}

struct CommitUploadResponseField1: SwiftProtobuf.Message, Equatable {
    static let protoMessageName = "CommitUploadResponseField1"
    var unknownFields = SwiftProtobuf.UnknownStorage()
    var field3: CommitUploadResponseField1Field3?
    
    init() {}
    
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 3: try decoder.decodeSingularMessageField(value: &field3)
            default: break
            }
        }
    }
    
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let v = field3 { try visitor.visitSingularMessageField(value: v, fieldNumber: 3) }
        try unknownFields.traverse(visitor: &visitor)
    }
    func isEqualTo(message: any SwiftProtobuf.Message) -> Bool { (message as? Self) == self }
}

struct CommitUploadResponseField1Field3: SwiftProtobuf.Message, Equatable {
    static let protoMessageName = "CommitUploadResponseField1Field3"
    var unknownFields = SwiftProtobuf.UnknownStorage()
    var mediaKey: String = ""
    
    init() {}
    
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &mediaKey)
            default: break
            }
        }
    }
    
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !mediaKey.isEmpty { try visitor.visitSingularStringField(value: mediaKey, fieldNumber: 1) }
        try unknownFields.traverse(visitor: &visitor)
    }
    func isEqualTo(message: any SwiftProtobuf.Message) -> Bool { (message as? Self) == self }
}

