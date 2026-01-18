import XCTest

final class AuroraPhotosTests: XCTestCase {
    
    // MARK: - Credential Validation Tests
    
    func testValidCredentialParsing() {
        let authString = "androidId=abc123&Email=test@gmail.com&Token=xyz789&client_sig=sig123&service=oauth2&lang=en"
        let result = CredentialValidator.validate(authString)
        
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.email, "test@gmail.com")
        XCTAssertNil(result.error)
    }
    
    func testInvalidCredentialMissingFields() {
        let authString = "androidId=abc123&Email=test@gmail.com"
        let result = CredentialValidator.validate(authString)
        
        XCTAssertFalse(result.isValid)
        XCTAssertNil(result.email)
        XCTAssertNotNil(result.error)
    }
    
    func testEmptyCredential() {
        let authString = ""
        let result = CredentialValidator.validate(authString)
        
        XCTAssertFalse(result.isValid)
    }
    
    func testCredentialWithUrlEncodedEmail() {
        let authString = "androidId=abc123&Email=test%40gmail.com&Token=xyz789&client_sig=sig123&service=oauth2"
        let result = CredentialValidator.validate(authString)
        
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.email, "test@gmail.com")
    }
    
    // MARK: - Credential Model Tests
    
    func testCredentialEmailParsing() {
        let credential = Credential(
            email: "test@gmail.com",
            authString: "androidId=device123&Token=token456&lang=en",
            addedDate: Date()
        )
        
        XCTAssertEqual(credential.androidId, "device123")
        XCTAssertEqual(credential.token, "token456")
        XCTAssertEqual(credential.language, "en")
    }
    
    // MARK: - Upload Item Tests
    
    func testUploadItemStatusText() {
        let url = URL(fileURLWithPath: "/test/photo.jpg")
        var item = UploadItem(filePath: url)
        
        XCTAssertEqual(item.statusText, "Queued")
        
        item.status = .hashing
        XCTAssertEqual(item.statusText, "Hashing...")
        
        item.status = .uploading
        item.progress = 0.5
        XCTAssertEqual(item.statusText, "50%")
        
        item.status = .completed
        XCTAssertEqual(item.statusText, "Done")
        
        item.status = .error
        item.errorMessage = "Network error"
        XCTAssertEqual(item.statusText, "Network error")
    }
    
    // MARK: - File Extension Tests
    
    func testSupportedFileExtensions() {
        let photoExtensions = ["jpg", "jpeg", "png", "heic", "webp", "gif"]
        let videoExtensions = ["mp4", "mov", "mkv", "avi"]
        
        for ext in photoExtensions {
            XCTAssertTrue(isSupportedExtension(ext), "\(ext) should be supported")
        }
        
        for ext in videoExtensions {
            XCTAssertTrue(isSupportedExtension(ext), "\(ext) should be supported")
        }
        
        XCTAssertFalse(isSupportedExtension("txt"))
        XCTAssertFalse(isSupportedExtension("pdf"))
        XCTAssertFalse(isSupportedExtension("doc"))
    }
    
    private func isSupportedExtension(_ ext: String) -> Bool {
        let photoFormats = ["avif", "bmp", "gif", "heic", "ico", "jpg", "jpeg", "png", "tiff", "webp",
                           "cr2", "cr3", "nef", "arw", "orf", "raf", "rw2", "pef", "sr2", "dng"]
        let videoFormats = ["3gp", "3g2", "asf", "avi", "divx", "m2t", "m2ts", "m4v", "mkv", "mmv",
                           "mod", "mov", "mp4", "mpg", "mpeg", "mts", "tod", "wmv", "ts"]
        return photoFormats.contains(ext.lowercased()) || videoFormats.contains(ext.lowercased())
    }
}
