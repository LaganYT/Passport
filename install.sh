#!/bin/bash
# Installs Passport: Voile's Linux engine (about 2.4 GB), Valve's Linux steamclient for the Steam on this Mac, the
# compatibility tool Steam lists as "Passport (Linux engine)", and the hook that turns on Steam Play in the Mac client.
# Steam has to be closed. The app carries a built hook; from a checkout the hook is built here, which needs the Xcode
# command line tools and cmake. Run again to update the tool or
# after Steam updates itself; the runtime is kept. uninstall.sh puts Steam back.
set -euo pipefail

voile=v26.3.0-16
support="$HOME/Library/Application Support/Passport"
tools="$HOME/Library/Application Support/Steam/compatibilitytools.d"
steam_app=${STEAM_APP:-/Applications/Steam.app}
here=$(cd "$(dirname "$0")" && pwd)
plist="$steam_app/Contents/Info.plist"
dylib="$steam_app/Contents/MacOS/passport.dylib"
plistbuddy=/usr/libexec/PlistBuddy

[ "$(uname -s) $(uname -m)" = "Darwin arm64" ] || { echo "Passport needs a Mac with Apple silicon." >&2; exit 1; }
if [ ! -f "$here/passport.dylib" ]; then
    for need in clang cmake; do
        command -v "$need" >/dev/null || { echo "$need is needed to build the hook. Install Xcode's command line tools and cmake (brew install cmake)." >&2; exit 1; }
    done
fi
[ -f "$plist" ] || { echo "Steam.app is not at $steam_app. Set STEAM_APP to where it is." >&2; exit 1; }
pgrep -x steam_osx >/dev/null && { echo "Quit Steam first." >&2; exit 1; }
inserted=$("$plistbuddy" -c "Print :LSEnvironment:DYLD_INSERT_LIBRARIES" "$plist" 2>/dev/null || true)
if [ -n "$inserted" ] && [ "$inserted" != "$dylib" ]; then
    echo "Steam already loads $inserted. Passport's hook does the same job, so remove that one first." >&2
    exit 1
fi
mkdir -p "$support"

if [ ! -d "$support/voile-$voile" ]; then
    tmp=$(mktemp -d "$support/download.XXXXXX")
    trap 'rm -rf "$tmp"' EXIT
    url=https://github.com/LaganYT/Passport/releases/download/voile-$voile/voile-$voile.tar.xz
    curl -fSL --progress-bar "$url" -o "$tmp/voile-$voile.tar.xz"
    curl -fsSL "$url.sha256" -o "$tmp/voile.sha256"
    (cd "$tmp" && shasum -a 256 -c voile.sha256)
    tar -xJf "$tmp/voile-$voile.tar.xz" -C "$tmp"
    mv "$tmp/voile-$voile" "$support/voile-$voile"
fi
ln -sfn "voile-$voile/linux" "$support/runtime"

"$here/tool/steamclient.sh"

mkdir -p "$tools/passport"
cp -R "$here/tool/." "$tools/passport/"

if [ -f "$here/passport.dylib" ]; then
    built="$here/passport.dylib"
else
    "$here/hook/build.sh" "$support/build"
    built="$support/build/passport.dylib"
fi
mkdir -p "$support/signatures/macos.arm64"
cp "$here"/hook/signatures/*.json "$support/signatures/macos.arm64/"

# Steam loads the hook through its Info.plist; a copy of the original is kept for uninstall.sh.
[ -f "$support/Info.plist.orig" ] || cp "$plist" "$support/Info.plist.orig"
cp "$built" "$dylib"
set_env() {
    "$plistbuddy" -c "Add :LSEnvironment dict" "$plist" 2>/dev/null || true
    "$plistbuddy" -c "Delete :LSEnvironment:$1" "$plist" 2>/dev/null || true
    "$plistbuddy" -c "Add :LSEnvironment:$1 string $2" "$plist"
}
set_env DYLD_INSERT_LIBRARIES "$dylib"
set_env SDL_JOYSTICK_BLACKLIST_DEVICES 0x05ac/0x0004
codesign -f -s - "$dylib"
codesign -f -s - "$steam_app/Contents/MacOS/steam_osx"
codesign -f -s - "$steam_app"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$steam_app"
# Signing again changes Steam's identity, so macOS asks for its input permissions again.
for service in Accessibility PostEvent ListenEvent; do tccutil reset "$service" com.valvesoftware.steam >/dev/null; done

echo "Passport installed. Start Steam, then pick it in a game's Properties > Compatibility."
