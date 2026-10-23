#!/bin/bash
# Builds Passport.app into OUT_DIR (default ./build). The scripts and a built hook go inside it, so the app
# installs without a checkout or build tools. Needs the Xcode command line tools and cmake.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
out=${1:-$here/build}
app="$out/Passport.app"

swift build -c release --package-path "$here" --arch arm64
bin=$(swift build -c release --package-path "$here" --arch arm64 --show-bin-path)

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/passport"
cp "$bin/Passport" "$app/Contents/MacOS/Passport"
cp "$root/install.sh" "$root/uninstall.sh" "$app/Contents/Resources/passport/"
cp -R "$root/tool" "$app/Contents/Resources/passport/"
mkdir -p "$app/Contents/Resources/passport/hook"
cp -R "$root/hook/signatures" "$app/Contents/Resources/passport/hook/"
"$root/hook/build.sh" "$out/hook"
cp "$out/hook/passport.dylib" "$app/Contents/Resources/passport/"
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Passport</string>
<key>CFBundleIdentifier</key><string>com.laganyt.passport</string>
<key>CFBundleExecutable</key><string>Passport</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign -f -s - "$app"
echo "Built $app"
