import Foundation
import Combine

@MainActor
class FolderWatchService: ObservableObject {
    @Published var isWatching: Bool = false
    
    private var stream: FSEventStreamRef?
    private var lastEventId: FSEventStreamEventId = FSEventStreamEventId(kFSEventStreamEventIdSinceNow)
    private var watchedPath: String?
    private var onFilesFound: (([URL]) -> Void)?
    private var pendingFiles: [URL: Date] = [:]
    private var debounceTimer: Timer?
    
    private static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "bmp", "tiff", "tif",
        "mp4", "mov", "m4v", "avi", "mkv", "webm", "3gp"
    ]
    
    func startWatching(path: String, recursive: Bool, onFilesFound: @escaping ([URL]) -> Void) {
        stopWatching()
        
        guard FileManager.default.fileExists(atPath: path) else {
            print("[FolderWatch] Path does not exist: \(path)")
            return
        }
        
        self.watchedPath = path
        self.onFilesFound = onFilesFound
        
        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()
        
        let flags: FSEventStreamCreateFlags = UInt32(
            kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagNoDefer
        )
        
        let pathsToWatch = [path] as CFArray
        
        stream = FSEventStreamCreate(
            nil,
            { (streamRef, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds) in
                guard let info = clientCallBackInfo else { return }
                let service = Unmanaged<FolderWatchService>.fromOpaque(info).takeUnretainedValue()
                
                let paths = unsafeBitCast(eventPaths, to: NSArray.self) as! [String]
                let flags = Array(UnsafeBufferPointer(start: eventFlags, count: numEvents))
                
                Task { @MainActor in
                    service.handleEvents(paths: paths, flags: flags)
                }
            },
            &context,
            pathsToWatch,
            lastEventId,
            0.5,
            flags
        )
        
        guard let stream = stream else {
            print("[FolderWatch] Failed to create FSEventStream")
            return
        }
        
        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(stream)
        
        isWatching = true
        print("[FolderWatch] Started watching: \(path)")
    }
    
    func stopWatching() {
        debounceTimer?.invalidate()
        debounceTimer = nil
        pendingFiles.removeAll()
        
        guard let stream = stream else { return }
        
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        
        self.stream = nil
        self.watchedPath = nil
        isWatching = false
        print("[FolderWatch] Stopped watching")
    }
    
    private func handleEvents(paths: [String], flags: [FSEventStreamEventFlags]) {
        
        for (index, path) in paths.enumerated() {
            let flag = flags[index]
            
            let isFile = (flag & UInt32(kFSEventStreamEventFlagItemIsFile)) != 0
            let isCreated = (flag & UInt32(kFSEventStreamEventFlagItemCreated)) != 0
            let isRenamed = (flag & UInt32(kFSEventStreamEventFlagItemRenamed)) != 0
            let isModified = (flag & UInt32(kFSEventStreamEventFlagItemModified)) != 0
            
            guard isFile && (isCreated || isRenamed || isModified) else { continue }
            
            let url = URL(fileURLWithPath: path)
            let ext = url.pathExtension.lowercased()
            
            guard Self.supportedExtensions.contains(ext) else { continue }
            guard FileManager.default.fileExists(atPath: path) else { continue }
            
            // Skip temporary/partial files
            let fileName = url.lastPathComponent
            if fileName.hasPrefix(".") || fileName.hasSuffix(".tmp") || fileName.hasSuffix(".part") {
                continue
            }
            
            pendingFiles[url] = Date()
        }
        
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.processPendingFiles()
            }
        }
    }
    
    private func processPendingFiles() {
        let stableFiles = pendingFiles.filter { (url, firstSeen) in
            guard FileManager.default.fileExists(atPath: url.path) else { return false }
            
            // Check if file size is stable (not still being copied)
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let size = attrs[.size] as? Int64,
                  size > 0 else { return false }
            
            return true
        }.map { $0.key }
        
        pendingFiles.removeAll()
        
        if !stableFiles.isEmpty {
            print("[FolderWatch] Found \(stableFiles.count) new file(s)")
            onFilesFound?(stableFiles)
        }
    }

}
