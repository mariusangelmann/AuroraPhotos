# Aurora Photos

Aurora Photos is a high-performance, native macOS client for Google Photos. It provides a seamless desktop experience for managing backups, featuring high-speed concurrent uploads and support for unlimited storage via device spoofing.

## Features

- **Native macOS Experience**: Built with SwiftUI for a lightweight, responsive interface that integrates perfectly with the macOS desktop.
- **High-Speed Uploads**: Multi-threaded concurrent upload engine for maximum throughput.
- **Unlimited Storage Support**: Optionally spoof device identity (e.g., Pixel XL/2) to utilize Google's "Storage Saver" or "Original Quality" unlimited storage benefits where applicable.
- **Drag-and-Drop Workflow**: Quickly upload photos and videos by dragging them directly into the application window.
- **Smart Queue Management**: Automatic duplicate detection and background processing with completion notifications.
- **File Management**: Configurable options to either copy or move local files to Google Photos.
- **Folder Sync**: Recursive scanning support for uploading entire directory structures.

## System Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon or Intel-based Mac
- Google Photos account credentials (extracted from a mobile device/emulator)

## Installation

### Building from Source

Ensure you have the latest version of Xcode or the Swift toolchain installed.

```bash
git clone https://github.com/mariusangelmann/AuroraPhotos.git
cd AuroraPhotos/AuroraPhotos
./build_app.sh
```

This script builds a release binary and packages an `.app` bundle in the project root.

## Credential Configuration

To bypass web-based API limitations, Aurora Photos uses credentials from the Google Photos Android application.

### Obtaining Credentials

1. Install [**GmsCore**](https://github.com/ReVanced/GmsCore/releases) and [**Google Photos ReVanced**](https://github.com/ReVanced/revanced-manager/releases/tag/v1.25.1) on an Android device or emulator. You can use the emulator inside Android Studio.
2. Use ADB to monitor authentication traffic:
   ```bash
   adb logcat | grep "auth%2Fphotos.native"
   ```
3. Authenticate in the Google Photos app and capture the generated auth string.
4. Launch Aurora Photos and use the onboarding sequence to securely store your credentials in the macOS Keychain.

## Configuration

Aurora Photos offers several settings to tune your backup process:

- **Move Mode**: Deletes local files only after a successful, verified upload.
- **Concurrent Uploads**: Adjust the number of parallel tasks (recommended: 3-5).
- **Storage Saver**: Toggle "Storage Saver" mode to optimize storage usage.
- **Recursive Scan**: Enable this to process nested subfolders during drag-and-drop operations.
- **Duplicate Check**: Toggle whether to skip checks for files already present in your Google Photos library.

## Technical Architecture

Aurora Photos is built using modern Swift technologies:
- **UI Framework**: SwiftUI
- **Concurrency**: Swift Concurrency (async/await)
- **Data Serialization**: SwiftProtobuf
- **Security**: KeychainAccess for encrypted credential storage

## License

Distributed under the MIT License. See `LICENSE` for more information.

## Acknowledgments

**Disclaimer: Aurora Photos is an independent project and is not associated with, endorsed by, or affiliated with Google LLC, Aurora Store, or Aurora OSS. "Google Photos" and "Pixel" are trademarks of Google LLC.**

While the core functionality of this application is **based on the [gotohp](https://github.com/xob0t/gotohp) project**, Aurora Photos is designed as a more native, macOS-centric approach to Google Photos management. A massive thank you to **gotohp** and their contributors for their incredible research and the foundational codebase that made this experience possible.

Special thanks also to the **Aurora Store** and **Aurora OSS** teams. Their commitment to excellence in the open-source community served as a primary inspiration for the development of this project.
