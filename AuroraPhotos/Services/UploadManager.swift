import Foundation
import CryptoKit

class UploadManager: ObservableObject {
    @Published var uploads: [UploadItem] = []
    @Published var isUploading: Bool = false
    @Published var isPaused: Bool = false
    @Published var overallProgress: Double = 0
    
    private var uploadTasks: [UUID: Task<Void, Never>] = [:]
    private var isCancelled = false
    
    @MainActor
    func addFiles(urls: [URL], appState: AppState) {
        print("[UploadManager] addFiles called with \(urls.count) URLs")
        let recursiveScan = appState.recursiveScan
        let supportedFiles = filterSupportedFiles(urls: urls, recursive: recursiveScan)
        print("[UploadManager] Found \(supportedFiles.count) supported files")
        
        for url in supportedFiles {
            let item = UploadItem(filePath: url)
            uploads.append(item)
        }
        
        if !supportedFiles.isEmpty && appState.playSounds {
            SoundService.shared.playFilesAdded()
        }
        
        print("[UploadManager] uploads.isEmpty=\(uploads.isEmpty), isUploading=\(isUploading)")
        if !uploads.isEmpty && !isUploading {
            startUploads(appState: appState)
        }
    }
    
    func cancelAll() {
        isCancelled = true
        for (_, task) in uploadTasks {
            task.cancel()
        }
        uploadTasks.removeAll()
        
        for i in uploads.indices where uploads[i].status != .completed {
            uploads[i].status = .cancelled
        }
        
        isUploading = false
        isCancelled = false
    }
    
    @MainActor
    func pauseAll() {
        isPaused = true
    }
    
    @MainActor
    func resumeAll(appState: AppState) {
        isPaused = false
        if isUploading {
        } else if uploads.contains(where: { $0.status == .queued }) {
            startUploads(appState: appState)
        }
    }
    
    func cancelUpload(id: UUID) {
        if let task = uploadTasks[id] {
            task.cancel()
            uploadTasks.removeValue(forKey: id)
        }
        
        if let index = uploads.firstIndex(where: { $0.id == id }) {
            uploads[index].status = .cancelled
        }
    }
    
    @MainActor
    func retryUpload(id: UUID, appState: AppState) {
        guard let index = uploads.firstIndex(where: { $0.id == id }),
              uploads[index].status == .error else { return }
        
        uploads[index].status = .queued
        uploads[index].progress = 0
        uploads[index].errorMessage = nil
        
        if !isUploading {
            startUploads(appState: appState)
        } else {
            startSingleUpload(at: index, appState: appState)
        }
    }
    
    @MainActor
    func forceUploadDuplicate(id: UUID, appState: AppState) {
        guard let index = uploads.firstIndex(where: { $0.id == id }),
              uploads[index].status == .duplicate else { return }
        
        uploads[index].status = .queued
        uploads[index].progress = 0
        uploads[index].mediaKey = nil
        
        if !isUploading {
            startSingleUpload(at: index, appState: appState, forceUpload: true)
        } else {
            startSingleUpload(at: index, appState: appState, forceUpload: true)
        }
    }
    
    @MainActor
    func retryAllFailed(appState: AppState) {
        for i in uploads.indices where uploads[i].status == .error {
            uploads[i].status = .queued
            uploads[i].progress = 0
            uploads[i].errorMessage = nil
        }
        
        if !isUploading && uploads.contains(where: { $0.status == .queued }) {
            startUploads(appState: appState)
        }
    }
    
    @MainActor
    private func startSingleUpload(at index: Int, appState: AppState, forceUpload: Bool = false) {
        guard let email = appState.selectedAccountEmail,
              let credential = KeychainService.shared.getCredential(for: email) else {
            uploads[index].status = .error
            uploads[index].errorMessage = "No account selected"
            return
        }
        
        let deleteAfterUpload = appState.deleteAfterUpload
        let storageSaver = appState.storageSaver
        let useQuota = appState.useQuota
        let api = GooglePhotosAPI(credential: credential, appState: appState)
        
        let task: Task<Void, Never> = Task { [weak self] in
            await self?.processUpload(at: index, api: api, forceUpload: forceUpload, deleteAfterUpload: deleteAfterUpload, storageSaver: storageSaver, useQuota: useQuota)
        }
        uploadTasks[uploads[index].id] = task
    }
    
    @MainActor
    private func startUploads(appState: AppState) {
        print("[UploadManager] startUploads called")
        print("[UploadManager] selectedAccountEmail: \(appState.selectedAccountEmail ?? "nil")")
        guard let email = appState.selectedAccountEmail,
              let credential = KeychainService.shared.getCredential(for: email) else {
            print("[UploadManager] ERROR: No credential found!")
            for i in uploads.indices {
                uploads[i].status = .error
                uploads[i].errorMessage = "No account selected"
            }
            return
        }
        print("[UploadManager] Found credential for: \(credential.email)")
        
        let forceUpload = appState.forceUpload
        let deleteAfterUpload = appState.deleteAfterUpload
        let notifyOnComplete = appState.notifyOnComplete
        let notifyOnError = appState.notifyOnError
        let playSounds = appState.playSounds
        let storageSaver = appState.storageSaver
        let useQuota = appState.useQuota
        
        isUploading = true
        isCancelled = false
        
        Task { @MainActor in
            let api = GooglePhotosAPI(credential: credential, appState: appState)
            let maxConcurrent = appState.uploadThreads
            
            await withTaskGroup(of: Void.self) { group in
                var activeCount = 0
                var currentIndex = 0
                
                while currentIndex < uploads.count || activeCount > 0 {
                    if activeCount >= maxConcurrent {
                        await group.next()
                        activeCount -= 1
                        updateOverallProgress()
                    }
                    
                    if self.isPaused {
                        break
                    }
                    
                    while activeCount < maxConcurrent && currentIndex < uploads.count {
                        if isCancelled || self.isPaused { break }
                        
                        let index = currentIndex
                        let upload = uploads[index]
                        
                        if upload.status == .queued {
                            activeCount += 1
                            
                            group.addTask { [weak self] in
                                await self?.processUpload(at: index, api: api, forceUpload: forceUpload, deleteAfterUpload: deleteAfterUpload, storageSaver: storageSaver, useQuota: useQuota)
                            }
                        }
                        
                        currentIndex += 1
                    }
                    
                    if activeCount > 0 {
                        await group.next()
                        activeCount -= 1
                    }
                    
                    updateOverallProgress()
                }
            }
            
            isUploading = false
            
            let completedCount = self.uploads.filter { $0.status == .completed }.count
            let failedCount = self.uploads.filter { $0.status == .error }.count
            
            if playSounds {
                if failedCount > 0 {
                    SoundService.shared.playUploadError()
                } else if completedCount > 0 {
                    SoundService.shared.playUploadComplete()
                }
            }
            
            if notifyOnComplete {
                self.sendCompletionNotification(playSounds: playSounds)
            }
            
            if notifyOnError && failedCount > 0 && !notifyOnComplete {
                NotificationService.shared.sendErrorNotification(
                    message: "\(failedCount) file(s) failed to upload",
                    playSound: playSounds
                )
            }
        }
    }
    
    private func processUpload(at index: Int, api: GooglePhotosAPI, forceUpload: Bool, deleteAfterUpload: Bool, storageSaver: Bool, useQuota: Bool) async {
        let uploadsCount = await MainActor.run { uploads.count }
        guard index < uploadsCount else { return }
        
        let filePath = await MainActor.run { uploads[index].filePath }
        
        do {
            let sha1Hash = try await calculateSHA1(for: filePath)
            let sha1Base64 = sha1Hash.base64EncodedString()
            
            if !forceUpload {
                await MainActor.run {
                    uploads[index].status = .checking
                }
                
                if let existingKey = try await api.findRemoteMediaByHash(sha1Hash: sha1Hash) {
                    await MainActor.run {
                        uploads[index].mediaKey = existingKey
                        uploads[index].status = .duplicate
                    }
                    
                    return
                }
            }
            
            await MainActor.run {
                uploads[index].status = .uploading
            }
            
            let fileSize = try FileManager.default.attributesOfItem(atPath: filePath.path)[.size] as? Int64 ?? 0
            
            let uploadToken = try await api.getUploadToken(sha1Base64: sha1Base64, fileSize: fileSize)
            let commitToken = try await api.uploadFile(filePath: filePath, uploadToken: uploadToken) { progress in
                Task { @MainActor in
                    if index < self.uploads.count {
                        self.uploads[index].progress = progress
                    }
                }
            }
            
            await MainActor.run {
                uploads[index].status = .finalizing
            }
            
            let fileName = filePath.lastPathComponent
            let modTime = (try? FileManager.default.attributesOfItem(atPath: filePath.path)[.modificationDate] as? Date)?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
            
            let mediaKey = try await api.commitUpload(
                commitToken: commitToken,
                fileName: fileName,
                sha1Hash: sha1Hash,
                timestamp: Int64(modTime),
                storageSaver: storageSaver,
                useQuota: useQuota
            )
            
            await MainActor.run {
                uploads[index].mediaKey = mediaKey
                uploads[index].status = .completed
                uploads[index].progress = 1.0
            }
            
            if deleteAfterUpload {
                if let _ = try? await api.findRemoteMediaByHash(sha1Hash: sha1Hash) {
                    try? FileManager.default.trashItem(at: filePath, resultingItemURL: nil)
                }
            }
            
        } catch {
            await MainActor.run {
                uploads[index].status = .error
                uploads[index].errorMessage = error.localizedDescription
            }
        }
    }
    
    private func calculateSHA1(for url: URL) async throws -> Data {
        let data = try Data(contentsOf: url)
        let hash = Insecure.SHA1.hash(data: data)
        return Data(hash)
    }
    
    private func updateOverallProgress() {
        let completed = uploads.filter { $0.status == .completed || $0.status == .error }.count
        let total = uploads.count
        overallProgress = total > 0 ? Double(completed) / Double(total) : 0
    }
    
    private func filterSupportedFiles(urls: [URL], recursive: Bool) -> [URL] {
        var result: [URL] = []
        
        let photoExtensions = ["avif", "bmp", "gif", "heic", "ico", "jpg", "jpeg", "png", "tiff", "webp",
                               "cr2", "cr3", "nef", "arw", "orf", "raf", "rw2", "pef", "sr2", "dng"]
        let videoExtensions = ["3gp", "3g2", "asf", "avi", "divx", "m2t", "m2ts", "m4v", "mkv", "mmv",
                               "mod", "mov", "mp4", "mpg", "mpeg", "mts", "tod", "wmv", "ts"]
        let supportedExtensions = Set(photoExtensions + videoExtensions)
        
        for url in urls {
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            
            if isDirectory.boolValue {
                if recursive {
                    if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) {
                        for case let fileURL as URL in enumerator {
                            if supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                                result.append(fileURL)
                            }
                        }
                    }
                } else {
                    if let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
                        for fileURL in contents {
                            if supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                                result.append(fileURL)
                            }
                        }
                    }
                }
            } else {
                if supportedExtensions.contains(url.pathExtension.lowercased()) {
                    result.append(url)
                }
            }
        }
        
        return result
    }
    
    @MainActor
    private func sendCompletionNotification(playSounds: Bool) {
        let completed = uploads.filter { $0.status == .completed }.count
        let failed = uploads.filter { $0.status == .error }.count
        
        NotificationService.shared.sendUploadCompleteNotification(
            completed: completed,
            failed: failed,
            playSound: playSounds
        )
    }
}
