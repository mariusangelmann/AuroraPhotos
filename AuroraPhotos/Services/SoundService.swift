import AppKit

class SoundService {
    static let shared = SoundService()
    
    private init() {}
    
    func playFilesAdded() {
        playSystemSound("Pop")
    }
    
    func playUploadStarted() {
        playSystemSound("Blow")
    }
    
    func playUploadComplete() {
        playSystemSound("Glass")
    }
    
    func playUploadError() {
        playSystemSound("Basso")
    }
    
    func playDuplicateFound() {
        playSystemSound("Tink")
    }
    
    private func playSystemSound(_ name: String) {
        if let sound = NSSound(named: NSSound.Name(name)) {
            sound.play()
        }
    }
}
