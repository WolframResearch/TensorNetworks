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

echo "Building for all targets..."
echo

for entry in "${TARGETS[@]}"; do
    system_id="${entry%%:*}"
    target="${entry##*:}"
    echo "=== Building for $system_id ($target) ==="

    case "$target" in
        *-apple-darwin)
            # Provide a real SDK so rustc skips xcrun and the linker finds
            # frameworks (e.g. CoreFoundation pulled in by iana-time-zone).
            export SDKROOT="$MACOS_SDK"
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
    echo "  $system_id: TensorNetworks/target/$target/release/libcotengrust.$ext"
done
