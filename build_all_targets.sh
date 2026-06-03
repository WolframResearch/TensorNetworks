#!/bin/bash
set -e

# Cross-compilation build script
# Builds release binaries for all supported platforms

# Define targets: WolframSystemID Rust_target
TARGETS=(
    "MacOSX-x86-64:x86_64-apple-darwin"
    "MacOSX-ARM64:aarch64-apple-darwin"
    "Linux-x86-64:x86_64-unknown-linux-gnu"
    "Linux-ARM64:aarch64-unknown-linux-gnu"
    "Windows-x86-64:x86_64-pc-windows-gnu"
)

MACOS_SDK="${MACOS_SDK:-/opt/macos-sdk/MacOSX.sdk}"

# Put cargo's target dir where ExtensionCargo`CargoCollect looks for it.
# CargoCollect scans <SourceDirectory>/target/<triple>/... where
# SourceDirectory is the paclet's "Root" -> "Cotengra" from PacletInfo.wl.
# In a Cargo workspace artifacts default to <workspace-root>/target/, which
# CargoCollect can't see — so only the host build would get manifested
# (Manifest_<host-SystemID>.wxf), and every other cross-built binary would
# be silently dropped from the paclet.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$SCRIPT_DIR/TensorNetworks/Cotengra/target}"

echo "Building for all targets..."
echo "  CARGO_TARGET_DIR=$CARGO_TARGET_DIR"
echo

for entry in "${TARGETS[@]}"; do
    system_id="${entry%%:*}"
    target="${entry##*:}"
    echo "=== Building for $system_id ($target) ==="

    case "$target" in
        *-apple-darwin)
            # Override SDKROOT only when the CI cross-compile SDK is present
            # (Linux container). On a macOS host, leave it unset so xcrun
            # resolves the installed Xcode SDK — pointing it at a stale path
            # makes clang exit with status 72.
            if [ -d "$MACOS_SDK" ]; then
                export SDKROOT="$MACOS_SDK"
            else
                unset SDKROOT
            fi
            ;;
        *)
            unset SDKROOT
            ;;
    esac

    if cargo build --release --target "$target"; then
        echo "✓ $system_id build succeeded"
    else
        echo "✗ $system_id build failed"
        exit 1
    fi
    echo
done

unset SDKROOT

echo "=== All builds completed successfully ==="

# Show output locations
echo
echo "Built libraries:"
for entry in "${TARGETS[@]}"; do
    system_id="${entry%%:*}"
    target="${entry##*:}"
    case "$target" in
        *-windows-*)
            ext="dll.a"
            ;;
        *-apple-*)
            ext="dylib"
            ;;
        *)
            ext="so"
            ;;
    esac
    echo "  $system_id: ${CARGO_TARGET_DIR#$SCRIPT_DIR/}/$target/release/libcotengrust.$ext"
done
