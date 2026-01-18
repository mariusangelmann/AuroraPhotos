#!/bin/bash
set -euo pipefail

APP_NAME="AuroraPhotos"
BUILD_DIR=".build/release"
BUNDLE_DIR="${APP_NAME}.app"

log() {
  printf '%s\n' "$*"
}

log "Building ${APP_NAME} (release)..."
swift build -c release

log "Packaging into ${BUNDLE_DIR}..."

# Create bundle structure
rm -rf "${BUNDLE_DIR}"
mkdir -p "${BUNDLE_DIR}/Contents/MacOS"
mkdir -p "${BUNDLE_DIR}/Contents/Resources"

# Copy binary
if [ ! -f "${BUILD_DIR}/${APP_NAME}" ]; then
  log "Build output not found: ${BUILD_DIR}/${APP_NAME}"
  exit 1
fi
cp "${BUILD_DIR}/${APP_NAME}" "${BUNDLE_DIR}/Contents/MacOS/"

# Create Info.plist
cat > "${BUNDLE_DIR}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.aurora.photos</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF

# Compile icons into .icns
ICON_DIR="AuroraPhotos/Resources/Assets.xcassets/AppIcon.appiconset"
if [ -d "$ICON_DIR" ]; then
  log "Compiling app icon..."
  ICONSET_DIR="${BUNDLE_DIR}/Contents/Resources/AppIcon.iconset"
  mkdir -p "$ICONSET_DIR"

  # Copy icons with correct naming for iconutil
  cp "${ICON_DIR}/AppIcon-16.png" "${ICONSET_DIR}/icon_16x16.png"
  cp "${ICON_DIR}/AppIcon-32.png" "${ICONSET_DIR}/icon_16x16@2x.png"
  cp "${ICON_DIR}/AppIcon-32.png" "${ICONSET_DIR}/icon_32x32.png"
  cp "${ICON_DIR}/AppIcon-64.png" "${ICONSET_DIR}/icon_32x32@2x.png"
  cp "${ICON_DIR}/AppIcon-128.png" "${ICONSET_DIR}/icon_128x128.png"
  cp "${ICON_DIR}/AppIcon-256.png" "${ICONSET_DIR}/icon_128x128@2x.png"
  cp "${ICON_DIR}/AppIcon-256.png" "${ICONSET_DIR}/icon_256x256.png"
  cp "${ICON_DIR}/AppIcon-512.png" "${ICONSET_DIR}/icon_256x256@2x.png"
  cp "${ICON_DIR}/AppIcon-512.png" "${ICONSET_DIR}/icon_512x512.png"
  cp "${ICON_DIR}/AppIcon-1024.png" "${ICONSET_DIR}/icon_512x512@2x.png"

  # Generate .icns file
  iconutil -c icns "$ICONSET_DIR" -o "${BUNDLE_DIR}/Contents/Resources/AppIcon.icns"
  rm -rf "$ICONSET_DIR"
fi

log "Done: $(pwd)/${BUNDLE_DIR}"
