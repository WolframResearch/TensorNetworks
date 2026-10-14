#!/bin/bash
# setup_cross_compile.sh - Install cacheable cross-compilation tools (Zig, macOS SDK)
# apt packages are installed separately (not cacheable in CI containers)

set -e

ZIG_VERSION="0.13.0"
MACOS_SDK_VERSION="12.3"

# ziglang.org can be very slow from CI; fall back to community mirrors
ZIG_TARBALL="zig-linux-x86_64-${ZIG_VERSION}.tar.xz"
ZIG_URLS=(
    "https://ziglang.org/download/${ZIG_VERSION}/${ZIG_TARBALL}"
    "https://pkg.machengine.org/zig/${ZIG_VERSION}/${ZIG_TARBALL}"
    "https://zigmirror.hryx.net/zig/${ZIG_VERSION}/${ZIG_TARBALL}"
)

MACOS_SDK_URLS=(
    "https://github.com/joseluisq/macosx-sdks/releases/download/${MACOS_SDK_VERSION}/MacOSX${MACOS_SDK_VERSION}.sdk.tar.xz"
)

# Try each URL in turn, aborting stalled transfers
fetch() {
    local dest="$1"
    shift
    local url
    for url in "$@"; do
        echo "  -> $url"
        if curl -fL --retry 3 --retry-delay 3 --retry-all-errors \
                --connect-timeout 30 --max-time 240 \
                --speed-limit 102400 --speed-time 30 \
                -o "$dest" "$url"; then
            return 0
        fi
        echo "  !! download failed, trying next mirror"
    done
    return 1
}

# Install Zig
echo "Installing Zig ${ZIG_VERSION}..."
mkdir -p /opt/zig
fetch /tmp/zig.tar.xz "${ZIG_URLS[@]}"
tar -xJ -C /opt/zig --strip-components=1 -f /tmp/zig.tar.xz
rm -f /tmp/zig.tar.xz

# Download macOS SDK (frameworks and libiconv/libSystem stubs)
echo "Downloading macOS SDK ${MACOS_SDK_VERSION}..."
mkdir -p /opt/macos-sdk
fetch /tmp/macos-sdk.tar.xz "${MACOS_SDK_URLS[@]}"
tar -xJ -C /opt/macos-sdk -f /tmp/macos-sdk.tar.xz
rm -f /tmp/macos-sdk.tar.xz

# Stable SDK path for the build scripts
ln -sfn "/opt/macos-sdk/MacOSX${MACOS_SDK_VERSION}.sdk" /opt/macos-sdk/MacOSX.sdk

echo "Cross-compilation setup complete!"
echo "  Zig:       /opt/zig"
echo "  macOS SDK: /opt/macos-sdk/MacOSX.sdk"
