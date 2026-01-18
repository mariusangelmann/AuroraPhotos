import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    
    private var isAvailable: Bool {
        return Bundle.main.bundleIdentifier != nil
    }
    
    private init() {
        requestAuthorization()
    }
    
    private func requestAuthorization() {
        guard isAvailable else {
            print("NotificationService: Skipping authorization - no bundle identifier available")
            return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }
    
    func sendUploadCompleteNotification(completed: Int, failed: Int, playSound: Bool) {
        guard isAvailable else { return }
        let content = UNMutableNotificationContent()
        
        if failed > 0 {
            content.title = "Upload Complete with Errors"
            content.body = "\(completed) files uploaded, \(failed) failed"
        } else {
            content.title = "Upload Complete"
            content.body = "\(completed) files uploaded successfully"
        }
        
        if playSound {
            content.sound = .default
        }
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func sendErrorNotification(message: String, playSound: Bool) {
        guard isAvailable else { return }
        let content = UNMutableNotificationContent()
        content.title = "Upload Error"
        content.body = message
        
        if playSound {
            content.sound = .default
        }
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}
