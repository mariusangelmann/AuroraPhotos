import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct DropZoneView: View {
    @Binding var isDropTargeted: Bool
    let onDrop: ([URL]) -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: isDropTargeted ? "arrow.down.doc.fill" : "photo.on.rectangle.angled")
                .font(.system(size: 28))
                .foregroundStyle(isDropTargeted ? Color.accentColor : .secondary)
            
            VStack(spacing: 2) {
                Text(isDropTargeted ? "Release to upload" : "Drop photos & videos")
                    .font(.system(size: 13, weight: .medium))
                
                Text("or click to browse")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(isDropTargeted ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isDropTargeted ? Color.accentColor : Color(nsColor: .separatorColor),
                    style: StrokeStyle(lineWidth: 1, dash: isDropTargeted ? [] : [5, 3])
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            openFilePicker()
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
        .animation(.easeInOut(duration: 0.15), value: isDropTargeted)
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        print("[DropZone] handleDrop called with \(providers.count) providers")
        
        for (index, provider) in providers.enumerated() {
            print("[DropZone] Provider \(index): registeredTypeIdentifiers = \(provider.registeredTypeIdentifiers)")
        }
        
        var collectedURLs: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            
            // Use the completion-based loadFileRepresentation for file URLs
            // This is the most reliable way to get file URLs on macOS
            provider.loadFileRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { url, error in
                defer { group.leave() }
                
                if let error = error {
                    print("[DropZone] loadFileRepresentation error: \(error)")
                }
                
                if let url = url {
                    // loadFileRepresentation provides a temporary copy, we need the original URL
                    // The URL from loadFileRepresentation is a temporary file, so we need a different approach
                    print("[DropZone] Got temp URL: \(url)")
                }
            }
        }
        
        // Try alternative approach: load as Data
        for provider in providers {
            group.enter()
            
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, error in
                defer { group.leave() }
                
                if let error = error {
                    print("[DropZone] loadDataRepresentation error: \(error)")
                    return
                }
                
                guard let data = data else {
                    print("[DropZone] No data returned")
                    return
                }
                
                print("[DropZone] Got data of \(data.count) bytes")
                
                // Try to decode as file URL bookmark data
                if let url = URL(dataRepresentation: data, relativeTo: nil, isAbsolute: true) {
                    print("[DropZone] Decoded URL from data representation: \(url)")
                    collectedURLs.append(url)
                    return
                }
                
                // Try to decode as UTF-8 string path (file:// URL)
                if let urlString = String(data: data, encoding: .utf8) {
                    print("[DropZone] Data as string: \(urlString)")
                    // Remove null terminator if present
                    let cleanedString = urlString.trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
                    if let url = URL(string: cleanedString) {
                        print("[DropZone] Decoded URL from string: \(url)")
                        collectedURLs.append(url)
                        return
                    }
                    // Try as file path
                    if cleanedString.hasPrefix("/") {
                        let url = URL(fileURLWithPath: cleanedString)
                        print("[DropZone] Created URL from path: \(url)")
                        collectedURLs.append(url)
                        return
                    }
                }
                
                print("[DropZone] Could not decode data as URL")
            }
        }
        
        group.notify(queue: .main) {
            if !collectedURLs.isEmpty {
                self.onDrop(collectedURLs)
            } else {
                self.tryPasteboardFallback(providers: providers)
            }
        }
    }
    
    
    private func tryPasteboardFallback(providers: [NSItemProvider]) {
        let pasteboard = NSPasteboard.general
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            onDrop(urls)
        }
    }
    
    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .movie]
        
        if panel.runModal() == .OK {
            onDrop(panel.urls)
        }
    }
}

#Preview {
    DropZoneView(isDropTargeted: .constant(false)) { _ in }
        .padding()
        .frame(width: 320)
}
