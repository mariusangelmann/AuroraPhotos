import SwiftUI

struct UploadQueueView: View {
    @EnvironmentObject var uploadManager: UploadManager
    @EnvironmentObject var appState: AppState
    
    private var hasFailedUploads: Bool {
        uploadManager.uploads.contains { $0.status == .error }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Uploads")
                    .font(.subheadline.weight(.medium))
                
                if !uploadManager.uploads.isEmpty {
                    Text("(\(uploadManager.uploads.count))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if uploadManager.isUploading || uploadManager.isPaused {
                    Button {
                        if uploadManager.isPaused {
                            uploadManager.resumeAll(appState: appState)
                        } else {
                            uploadManager.pauseAll()
                        }
                    } label: {
                        Image(systemName: uploadManager.isPaused ? "play.fill" : "pause.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(uploadManager.isPaused ? .blue : .secondary)
                }
                
                if hasFailedUploads {
                    Button {
                        uploadManager.retryAllFailed(appState: appState)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                    .help("Retry all failed uploads")
                }
                
                Button {
                    uploadManager.cancelAll()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(uploadManager.uploads) { upload in
                        UploadItemRow(upload: upload)
                    }
                }
            }
            .frame(maxHeight: 200)
        }
    }
}

struct UploadItemRow: View {
    let upload: UploadItem
    @EnvironmentObject var uploadManager: UploadManager
    @EnvironmentObject var appState: AppState
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 10) {
            statusIcon
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(upload.fileName)
                    .font(.subheadline)
                    .lineLimit(1)
                
                Text(upload.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if upload.status == .uploading {
                ProgressView(value: upload.progress)
                    .progressViewStyle(.linear)
                    .frame(width: 60)
            } else if upload.status == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if upload.status == .duplicate {
                Button {
                    uploadManager.forceUploadDuplicate(id: upload.id, appState: appState)
                } label: {
                    Text("Upload Anyway")
                        .font(.caption2)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                
                Image(systemName: "doc.on.doc.fill")
                    .foregroundStyle(.orange)
            } else if upload.status == .error {
                Button {
                    uploadManager.retryUpload(id: upload.id, appState: appState)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch upload.status {
        case .queued:
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
        case .hashing:
            ProgressView()
                .scaleEffect(0.6)
        case .checking:
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.blue)
                .symbolEffect(.pulse)
        case .uploading:
            Image(systemName: "arrow.up.circle.fill")
                .foregroundStyle(.blue)
                .symbolEffect(.pulse)
        case .finalizing:
            Image(systemName: "checkmark.circle")
                .foregroundStyle(.orange)
                .symbolEffect(.pulse)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .duplicate:
            Image(systemName: "doc.on.doc.fill")
                .foregroundStyle(.orange)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        case .cancelled:
            Image(systemName: "xmark.circle")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    UploadQueueView()
        .environmentObject(UploadManager())
        .environmentObject(AppState())
        .frame(width: 340)
}
