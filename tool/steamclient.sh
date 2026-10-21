#!/bin/bash
# Makes ~/Library/Application Support/Passport/steam match the Steam running on this Mac: Valve's Windows
# steamclient libraries from the Voile runtime, and the Linux steamclient.so of the same Steam build. The guest's
# steamclient talks to the Mac's Steam over its local port, and a Steam newer or older than it answers with
# "Unknown IPC call" and crashes the game. Does nothing when the folder is already current.
set -euo pipefail

support="$HOME/Library/Application Support/Passport"
package="$HOME/Library/Application Support/Steam/Steam.AppBundle/Steam/Contents/MacOS/package"
cdn=https://client-update.steamstatic.com

# The newest build among the manifests of the installed Steam.
mac=$(cat "$package"/steam_client*osx.manifest 2>/dev/null |
    awk -F'"' '$2 == "version" && $4 > v { v = $4 } END { print v }')
[ -n "$mac" ] || { echo "passport: cannot read the installed Steam's version" >&2; exit 1; }
[ "$(cat "$support/steam/version" 2>/dev/null)" = "$mac" ] && exit 0

tmp=$(mktemp -d "$support/steamclient.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

# The Linux client is published on the stable and the beta channel; Steam for Mac follows one of them.
for channel in steam_client_ubuntu12 steam_client_publicbeta_ubuntu12; do
    curl -fsSL "$cdn/$channel" -o "$tmp/manifest"
    version=$(awk -F'"' '$2 == "version" { print $4; exit }' "$tmp/manifest")
    [ "$version" = "$mac" ] && break
    version=
done
if [ -z "$version" ]; then
    echo "passport: no Linux Steam client has been published for Steam build $mac" >&2
    exit 1
fi

read -r file sha < <(awk -F'"' '$2 == "bins_sdk_ubuntu12" { b = 1 } b && $2 == "file" { f = $4 } b && $2 == "sha2" { s = $4 } b && /}/ { print f, s; exit }' "$tmp/manifest")
curl -fSL --progress-bar "$cdn/$file" -o "$tmp/bins_sdk.zip"
[ "$(shasum -a 256 "$tmp/bins_sdk.zip" | cut -d' ' -f1)" = "$sha" ] || { echo "passport: steamclient download is corrupt" >&2; exit 1; }

mkdir -p "$tmp/steam/linux64"
unzip -qj "$tmp/bins_sdk.zip" linux64/steamclient.so linux64/crashhandler.so -d "$tmp/steam/linux64"
cp "$support/runtime/steam/steamclient.dll" "$support/runtime/steam/steamclient64.dll" "$tmp/steam/"
echo "$mac" > "$tmp/steam/version"
rm -rf "$support/steam"
mv "$tmp/steam" "$support/steam"
echo "passport: Linux steamclient for Steam build $mac installed"
