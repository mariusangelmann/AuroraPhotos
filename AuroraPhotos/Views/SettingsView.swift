import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .environmentObject(appState)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            
            UploadSettingsView()
                .environmentObject(appState)
                .tabItem {
                    Label("Uploads", systemImage: "arrow.up.circle")
                }
            
            NotificationSettingsView()
                .environmentObject(appState)
                .tabItem {
                    Label("Notifications", systemImage: "bell")
                }
            
            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 300)
    }
}


struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Form {
            Section {
                Picker("After Upload", selection: $appState.deleteAfterUpload) {
                    Text("Keep files (Copy)").tag(false)
                    Text("Delete files (Move)").tag(true)
                }
                .pickerStyle(.radioGroup)
            } header: {
                Text("Default Behavior")
            }
            
            Section {
                Toggle("Launch at Login", isOn: $appState.launchAtLogin)
                Toggle("Show in Dock", isOn: $appState.showInDock)
            } header: {
                Text("System")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}


struct UploadSettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Concurrent Uploads")
                    Spacer()
                    Stepper("\(appState.uploadThreads)", value: $appState.uploadThreads, in: 1...10)
                }
                
                Toggle("Include Subfolders", isOn: $appState.recursiveScan)
            } header: {
                Text("Behavior")
            }
            
            Section {
                Toggle("Watch Folder", isOn: $appState.watchFolderEnabled)
                
                if appState.watchFolderEnabled {
                    HStack {
                        if let path = appState.watchFolderPath {
                            Text(path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("No folder selected")
                                .foregroundStyle(.tertiary)
                        }
                        
                        Spacer()
                        
                        Button("Select...") {
                            selectWatchFolder()
                        }
                    }
                }
            } header: {
                Text("Auto Upload")
            } footer: {
                Text("New files added to the watched folder will be uploaded automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section {
                Toggle("Skip Duplicate Check", isOn: $appState.forceUpload)
                Toggle("Use Storage Quota", isOn: $appState.useQuota)
                Toggle("Storage Saver Mode", isOn: $appState.storageSaver)
            } header: {
                Text("Advanced")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("• Skip Duplicate Check: Re-upload files even if already in library")
                    Text("• Use Storage Quota: Disable unlimited upload (counts against quota)")
                    Text("• Storage Saver: Compress photos slightly for more storage")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private func selectWatchFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder to watch for new photos and videos"
        panel.prompt = "Select"
        
        if panel.runModal() == .OK, let url = panel.url {
            appState.watchFolderPath = url.path
        }
    }
}


struct NotificationSettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Form {
            Section {
                Toggle("Upload Complete", isOn: $appState.notifyOnComplete)
                Toggle("Upload Failed", isOn: $appState.notifyOnError)
            } header: {
                Text("Notifications")
            }
            
            Section {
                Toggle("Sound Effects", isOn: $appState.playSounds)
            } header: {
                Text("Audio")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}


struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.stack.fill")
                .font(.system(size: 48))
                .foregroundStyle(.linearGradient(
                    colors: [.purple, .pink, .orange],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            VStack(spacing: 4) {
                Text("Aurora Photos")
                    .font(.title2.weight(.semibold))
                
                Text("A native macOS Google Photos client")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text("Version 1.0.1")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Divider()
                .frame(width: 200)
            
            HStack(spacing: 20) {
                Link(destination: URL(string: "https://github.com/mariusangelmann/AuroraPhotos")!) {
                    Label("GitHub", systemImage: "link")
                }
                
                Link(destination: URL(string: "https://github.com/mariusangelmann/AuroraPhotos/issues")!) {
                    Label("Report Bug", systemImage: "ant")
                }
            }
            .font(.subheadline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
