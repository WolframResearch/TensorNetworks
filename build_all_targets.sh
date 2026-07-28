#!/bin/bash
set -e

# Cross-compilation build script.
#
# `cargo wl build` (cargo-wl, from WolframResearch/wolfram-rust-library)
# compiles the Cotengra cdylib, reads the exported-function manifest embedded
# in the host binary, and writes each platform's library together with its
# generated Functions.wl loader into
# TensorNetworks/Binaries/Cotengra-<SystemID>/ (see
# [package.metadata.wl.pacletinfo] in TensorNetworks/Cotengra/Cargo.toml).
#
# The host platform is built by the first invocation; each cross target gets
# its own invocation so SDKROOT can be set per target. Re-running for the
# host inside the loop is a cached no-op, so the host appearing in TARGETS is
# harmless on any machine.

TARGETS=(
    "MacOSX-x86-64:x86_64-apple-darwin"
    "MacOSX-ARM64:aarch64-apple-darwin"
    "Linux-x86-64:x86_64-unknown-linux-gnu"
    "Linux-ARM64:aarch64-unknown-linux-gnu"
    "Windows-x86-64:x86_64-pc-windows-gnu"
)

MACOS_SDK="${MACOS_SDK:-/opt/macos-sdk/MacOSX.sdk}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
CRATE_DIR="$SCRIPT_DIR/TensorNetworks/Cotengra"

if ! command -v cargo-wl &> /dev/null; then
    echo "=== Installing cargo-wl ==="
    cargo install cargo-wl --locked
fi

cd "$CRATE_DIR"

echo "=== Building host platform ==="
cargo wl build --release
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

    if cargo wl build --release --system-id "$system_id"; then
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
echo "Built library packages:"
for entry in "${TARGETS[@]}"; do
    system_id="${entry%%:*}"
    echo "  $system_id: TensorNetworks/Binaries/Cotengra-$system_id/"
done
