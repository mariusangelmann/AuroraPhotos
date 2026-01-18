import SwiftUI
import ServiceManagement

@main
struct AuroraPhotosApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var uploadManager = UploadManager()
    @StateObject private var folderWatchService = FolderWatchService()
    @Environment(\.openWindow) private var openWindow
    
    var body: some Scene {
        Window("Aurora Photos", id: "main") {
            MainWindowView()
                .environmentObject(appState)
                .environmentObject(uploadManager)
                .frame(width: 340, height: 480)
                .onAppear {
                    if !appState.hasCompletedOnboarding {
                        NSApp.activate(ignoringOtherApps: true)
                        openWindow(id: "onboarding")
                    }
                    updateFolderWatching()
                }
                .onChange(of: appState.watchFolderEnabled) { _, _ in
                    updateFolderWatching()
                }
                .onChange(of: appState.watchFolderPath) { _, _ in
                    updateFolderWatching()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        
        
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
        
        
        Window("Welcome to Aurora Photos", id: "onboarding") {
            OnboardingContainerView()
                .environmentObject(appState)
                .frame(width: 520, height: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
    
    private func updateFolderWatching() {
        if appState.watchFolderEnabled, let path = appState.watchFolderPath {
            folderWatchService.startWatching(path: path, recursive: appState.recursiveScan) { [uploadManager, appState] urls in
                uploadManager.addFiles(urls: urls, appState: appState)
            }
        } else {
            folderWatchService.stopWatching()
        }
    }
}


@MainActor
class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }
    @Published var selectedAccountEmail: String? {
        didSet { UserDefaults.standard.set(selectedAccountEmail, forKey: "selectedAccountEmail") }
    }
    @Published var isUploading: Bool = false
    @Published var deleteAfterUpload: Bool {
        didSet { UserDefaults.standard.set(deleteAfterUpload, forKey: "deleteAfterUpload") }
    }
    @Published var uploadThreads: Int {
        didSet { UserDefaults.standard.set(uploadThreads, forKey: "uploadThreads") }
    }
    @Published var recursiveScan: Bool {
        didSet { UserDefaults.standard.set(recursiveScan, forKey: "recursiveScan") }
    }
    @Published var forceUpload: Bool {
        didSet { UserDefaults.standard.set(forceUpload, forKey: "forceUpload") }
    }
    @Published var useQuota: Bool {
        didSet { UserDefaults.standard.set(useQuota, forKey: "useQuota") }
    }
    @Published var storageSaver: Bool {
        didSet { UserDefaults.standard.set(storageSaver, forKey: "storageSaver") }
    }
    @Published var notifyOnComplete: Bool {
        didSet { UserDefaults.standard.set(notifyOnComplete, forKey: "notifyOnComplete") }
    }
    @Published var notifyOnError: Bool {
        didSet { UserDefaults.standard.set(notifyOnError, forKey: "notifyOnError") }
    }
    @Published var playSounds: Bool {
        didSet { UserDefaults.standard.set(playSounds, forKey: "playSounds") }
    }
    
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            updateLaunchAtLogin()
        }
    }
    @Published var showInDock: Bool {
        didSet {
            UserDefaults.standard.set(showInDock, forKey: "showInDock")
            updateDockVisibility()
        }
    }
    @Published var watchFolderEnabled: Bool {
        didSet { UserDefaults.standard.set(watchFolderEnabled, forKey: "watchFolderEnabled") }
    }
    @Published var watchFolderPath: String? {
        didSet { UserDefaults.standard.set(watchFolderPath, forKey: "watchFolderPath") }
    }
    
    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.selectedAccountEmail = UserDefaults.standard.string(forKey: "selectedAccountEmail")
        self.deleteAfterUpload = UserDefaults.standard.bool(forKey: "deleteAfterUpload")
        
        let savedThreads = UserDefaults.standard.integer(forKey: "uploadThreads")
        self.uploadThreads = savedThreads > 0 ? savedThreads : 3
        
        self.recursiveScan = UserDefaults.standard.bool(forKey: "recursiveScan")
        self.forceUpload = UserDefaults.standard.bool(forKey: "forceUpload")
        self.useQuota = UserDefaults.standard.bool(forKey: "useQuota")
        self.storageSaver = UserDefaults.standard.bool(forKey: "storageSaver")
        self.notifyOnComplete = UserDefaults.standard.object(forKey: "notifyOnComplete") as? Bool ?? true
        self.notifyOnError = UserDefaults.standard.object(forKey: "notifyOnError") as? Bool ?? true
        self.playSounds = UserDefaults.standard.object(forKey: "playSounds") as? Bool ?? false
        self.launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        self.showInDock = UserDefaults.standard.bool(forKey: "showInDock")
        self.watchFolderEnabled = UserDefaults.standard.bool(forKey: "watchFolderEnabled")
        self.watchFolderPath = UserDefaults.standard.string(forKey: "watchFolderPath")
        
        syncLaunchAtLoginState()
    }
    
    private func syncLaunchAtLoginState() {
        if #available(macOS 13.0, *) {
            let currentStatus = SMAppService.mainApp.status
            let isEnabled = currentStatus == .enabled
            if isEnabled != launchAtLogin {
                launchAtLogin = isEnabled
            }
        }
    }
    
    private func updateLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update launch at login: \(error)")
            }
        }
    }
    
    func updateDockVisibility() {
        let policy: NSApplication.ActivationPolicy = showInDock ? .regular : .accessory
        NSApp.setActivationPolicy(policy)
    }
}

