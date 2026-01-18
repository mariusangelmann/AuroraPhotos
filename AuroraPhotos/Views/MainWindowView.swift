import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var uploadManager: UploadManager
    @State private var isDropTargeted = false
    @State private var showSettings = false
    @State private var showAccounts = false
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
                .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(spacing: 16) {
                    DropZoneView(isDropTargeted: $isDropTargeted) { urls in
                        uploadManager.addFiles(urls: urls, appState: appState)
                    }
                    
                    uploadModeToggle
                        .padding(.horizontal, 4)
                    
                    if !uploadManager.uploads.isEmpty {
                        Divider()
                        
                        UploadQueueView()
                            .environmentObject(uploadManager)
                    }
                }
                .padding(16)
            }
            
            Divider()
            
            footerView
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    
    private var headerView: some View {
        HStack {
            Text("Aurora Photos")
                .font(.headline)
            
            Spacer()
            
            HStack(spacing: 12) {
                SettingsLink {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                
                Button {
                    showAccounts.toggle()
                } label: {
                    Image(systemName: "person.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(appState.selectedAccountEmail != nil ? .primary : .secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showAccounts) {
                    AccountsView()
                        .environmentObject(appState)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    
    private var uploadModeToggle: some View {
        HStack {
            Text("Copy")
                .font(.subheadline)
                .foregroundStyle(appState.deleteAfterUpload ? .secondary : .primary)
            
            Toggle("", isOn: $appState.deleteAfterUpload)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
            
            Text("Move")
                .font(.subheadline)
                .foregroundStyle(appState.deleteAfterUpload ? .primary : .secondary)
            
            Spacer()
            
            if appState.deleteAfterUpload {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Deletes originals")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)
            }
        }
    }
    
    
    private var footerView: some View {
        HStack {
            if let email = appState.selectedAccountEmail {
                Text(email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Button("Add Account") {
                    openWindow(id: "onboarding")
                }
                .font(.subheadline)
            }
            
            Spacer()
            
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}


struct SettingsPopoverView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Settings")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Concurrent Uploads")
                    Spacer()
                    Stepper("\(appState.uploadThreads)", value: $appState.uploadThreads, in: 1...10)
                        .labelsHidden()
                    Text("\(appState.uploadThreads)")
                        .monospacedDigit()
                        .frame(width: 20)
                }
                
                Toggle("Include Subfolders", isOn: $appState.recursiveScan)
                Toggle("Skip Duplicate Check", isOn: $appState.forceUpload)
            }
            
            Divider()
            
            Button("All Settings...") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }
        .padding()
        .frame(width: 280)
    }
}

#Preview {
    MainWindowView()
        .environmentObject(AppState())
        .environmentObject(UploadManager())
        .frame(width: 340, height: 480)
}
