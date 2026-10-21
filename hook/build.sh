#!/bin/bash
# Builds passport.dylib, the hook that turns on Steam Play in the macOS Steam client.
# Usage: build.sh OUT_DIR   (needs Xcode command line tools and cmake)
set -euo pipefail

min_macos=15.0

here="$(cd "$(dirname "$0")" && pwd)"
out="$(mkdir -p "$1" && cd "$1" && pwd)"
dobby="$here/vendor/dobby"
built="$out/dobby-build"

for need in clang cmake lipo codesign; do
    command -v "$need" >/dev/null || { echo "build.sh: $need is required" >&2; exit 1; }
done

if [ ! -f "$built/libdobby.a" ]; then
    cmake -S "$dobby" -B "$built" -G "Unix Makefiles" \
        -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=$min_macos \
        -DDOBBY_DEBUG=OFF >/dev/null 2>&1
    cmake --build "$built" -j "$(sysctl -n hw.ncpu)" >/dev/null 2>&1
fi
b="$built"
dobby_libs=("$b/libdobby.a"
    "$b/builtin-plugin/SymbolResolver/libdobby_symbol_resolver.a"
    "$b/builtin-plugin/SymbolResolver/libmacho_ctx_kit.a"
    "$b/builtin-plugin/SymbolResolver/libshared_cache_ctx_kit.a"
    "$b/external/osbase/libosbase.a"
    "$b/external/logging/liblogging.a")

sources=$(find "$here" -name '*.c' -not -name 'stub_x86_64.c' -not -path '*/vendor/*')
clang -arch arm64 -mmacosx-version-min=$min_macos -std=c17 -O2 -fPIC \
    -Wall -Wextra -Wno-unused-parameter -Werror=unguarded-availability-new \
    -I"$here/vendor" -I"$dobby/include" \
    -dynamiclib -install_name @rpath/passport.dylib \
    -o "$out/passport.arm64.dylib" $sources "$here/vendor/cJSON.c" \
    "${dobby_libs[@]}" -framework CoreFoundation -framework CoreGraphics -lc++

# Intel Steam's launcher maps the dylib too and finds nothing to run in the empty half.
clang -arch x86_64 -mmacosx-version-min=$min_macos -dynamiclib -install_name @rpath/passport.dylib \
    -o "$out/passport.x86_64.dylib" "$here/stub_x86_64.c"
lipo -create "$out/passport.arm64.dylib" "$out/passport.x86_64.dylib" -output "$out/passport.dylib"
codesign -f -s - "$out/passport.dylib"
echo "Built $out/passport.dylib"
