#!/bin/bash
# setup_cross_compile.sh - Install cacheable cross-compilation tools (Zig, macOS SDK)
# apt packages are installed separately (not cacheable in CI containers)

set -e

ZIG_VERSION="0.13.0"
MACOS_SDK_VERSION="12.3"
ZIG_URL="https://ziglang.org/download/${ZIG_VERSION}/zig-linux-x86_64-${ZIG_VERSION}.tar.xz"
MACOS_SDK_URL="https://github.com/joseluisq/macosx-sdks/releases/download/${MACOS_SDK_VERSION}/MacOSX${MACOS_SDK_VERSION}.sdk.tar.xz"

# Robust download: retry on any error, save to disk so a transient
# connection reset doesn't corrupt a streaming `curl | tar` pipeline.
fetch() {
    local url="$1"
    local dest="$2"
    curl -fL --retry 5 --retry-delay 5 --retry-all-errors \
        --connect-timeout 30 -o "$dest" "$url"
}

# Install Zig
echo "Installing Zig ${ZIG_VERSION}..."
mkdir -p /opt/zig
fetch "$ZIG_URL" /tmp/zig.tar.xz
tar -xJ -C /opt/zig --strip-components=1 -f /tmp/zig.tar.xz
rm -f /tmp/zig.tar.xz

# Download macOS SDK (provides Frameworks/* and usr/lib/libiconv.tbd, libSystem.tbd, ...)
echo "Downloading macOS SDK ${MACOS_SDK_VERSION}..."
mkdir -p /opt/macos-sdk
fetch "$MACOS_SDK_URL" /tmp/macos-sdk.tar.xz
tar -xJ -C /opt/macos-sdk -f /tmp/macos-sdk.tar.xz
rm -f /tmp/macos-sdk.tar.xz

# The tarball extracts to MacOSX${VERSION}.sdk/. Symlink to a stable name.
ln -sfn "/opt/macos-sdk/MacOSX${MACOS_SDK_VERSION}.sdk" /opt/macos-sdk/MacOSX.sdk

echo "Cross-compilation setup complete!"
echo "  Zig:       /opt/zig"
echo "  macOS SDK: /opt/macos-sdk/MacOSX.sdk"
