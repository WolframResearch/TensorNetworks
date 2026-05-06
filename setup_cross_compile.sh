#!/bin/bash
# setup_cross_compile.sh - Install cacheable cross-compilation tools (Zig, macOS SDK)
# apt packages are installed separately (not cacheable in CI containers)

set -e

ZIG_VERSION="0.13.0"
MACOS_SDK_VERSION="12.3"
MACOS_SDK_URL="https://github.com/joseluisq/macosx-sdks/releases/download/${MACOS_SDK_VERSION}/MacOSX${MACOS_SDK_VERSION}.sdk.tar.xz"

# Install Zig
echo "Installing Zig ${ZIG_VERSION}..."
mkdir -p /opt/zig
curl -fsSL "https://ziglang.org/download/${ZIG_VERSION}/zig-linux-x86_64-${ZIG_VERSION}.tar.xz" \
  | tar -xJ -C /opt/zig --strip-components=1
export PATH="/opt/zig:$PATH"

# Download macOS SDK (provides Frameworks/* and usr/lib/libiconv.tbd, libSystem.tbd, ...)
echo "Downloading macOS SDK ${MACOS_SDK_VERSION}..."
mkdir -p /opt/macos-sdk
curl -fsSL "$MACOS_SDK_URL" | tar -xJ -C /opt/macos-sdk

# The tarball extracts to MacOSX${VERSION}.sdk/. Symlink to a stable name.
ln -sfn "/opt/macos-sdk/MacOSX${MACOS_SDK_VERSION}.sdk" /opt/macos-sdk/MacOSX.sdk

echo "Cross-compilation setup complete!"
echo "  Zig:       /opt/zig"
echo "  macOS SDK: /opt/macos-sdk/MacOSX.sdk"
