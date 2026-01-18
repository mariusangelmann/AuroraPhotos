import SwiftUI
import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var appState: AppState?
    private var uploadManager: UploadManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        let showInDock = UserDefaults.standard.bool(forKey: "showInDock")
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "photo.stack.fill", accessibilityDescription: "Aurora Photos")
            button.action = #selector(statusItemClicked)
            button.target = self
        }
    }
    
    @objc private func statusItemClicked() {
        let mainWindow = NSApp.windows.first { window in
            let identifier = window.identifier?.rawValue ?? ""
            return identifier.contains("main") || window.title == "Aurora Photos"
        }
        
        if let window = mainWindow, window.isVisible && window.isKeyWindow {
            window.orderOut(nil)
        } else {
            showMainWindow()
        }
    }
    
    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        
        let mainWindow = NSApp.windows.first { window in
            let identifier = window.identifier?.rawValue ?? ""
            return identifier.contains("main") || window.title == "Aurora Photos"
        }
        
        if let window = mainWindow {
            if let button = statusItem?.button, let buttonWindow = button.window {
                let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
                let windowWidth: CGFloat = 340
                let x = buttonRect.midX - (windowWidth / 2)
                let y = buttonRect.minY - 10
                window.setFrameTopLeftPoint(NSPoint(x: x, y: y))
            }
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    func updateIcon(isUploading: Bool) {
        guard let button = statusItem?.button else { return }
        let symbolName = isUploading ? "arrow.up.circle.fill" : "photo.stack.fill"
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Aurora Photos")
        if isUploading {
            button.contentTintColor = .controlAccentColor
        } else {
            button.contentTintColor = nil
        }
    }
}
