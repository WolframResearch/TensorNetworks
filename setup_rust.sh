#!/bin/bash
# setup_rust.sh - Install Rust and configure for cross-compilation
# Used by both Dockerfile (local) and GitHub Actions (CI)

set -e

CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
MACOS_SDK="${MACOS_SDK:-/opt/macos-sdk/MacOSX.sdk}"

# Install Rust if not present (minimal profile to save space)
if ! command -v rustup &> /dev/null; then
    curl -fsSL https://sh.rustup.rs -o /tmp/rustup.sh
    sh /tmp/rustup.sh -y --default-toolchain stable --profile minimal
    rm /tmp/rustup.sh
fi

# Ensure cargo is in PATH
export PATH="$CARGO_HOME/bin:$PATH"

# Add targets
rustup target add \
    x86_64-unknown-linux-gnu \
    aarch64-unknown-linux-gnu \
    x86_64-pc-windows-gnu \
    x86_64-apple-darwin \
    aarch64-apple-darwin

# Install rustfmt
rustup component add rustfmt

# Install cargo-wl (WolframResearch/wolfram-rust-library): builds LibraryLink
# crates and generates their WL loader packages; used by build_all_targets.sh.
if ! command -v cargo-wl &> /dev/null; then
    cargo install cargo-wl --locked
fi

# Configure Cargo linkers. For macOS targets, point zig cc at the macOS SDK
# via -isysroot so the linker can resolve frameworks (CoreFoundation etc.) and
# libiconv/libSystem stubs from the SDK.
mkdir -p "$CARGO_HOME"
cat > "$CARGO_HOME/config.toml" << EOF
[target.x86_64-apple-darwin]
linker = "zcc"
rustflags = [
    "-C", "link-arg=-target", "-C", "link-arg=x86_64-macos",
    "-C", "link-arg=-isysroot", "-C", "link-arg=${MACOS_SDK}",
    "-C", "link-arg=-L${MACOS_SDK}/usr/lib",
    "-C", "link-arg=-F${MACOS_SDK}/System/Library/Frameworks",
]

[target.aarch64-apple-darwin]
linker = "zcc"
rustflags = [
    "-C", "link-arg=-target", "-C", "link-arg=aarch64-macos",
    "-C", "link-arg=-isysroot", "-C", "link-arg=${MACOS_SDK}",
    "-C", "link-arg=-L${MACOS_SDK}/usr/lib",
    "-C", "link-arg=-F${MACOS_SDK}/System/Library/Frameworks",
]

[target.x86_64-pc-windows-gnu]
linker = "x86_64-w64-mingw32-gcc"

[target.aarch64-unknown-linux-gnu]
linker = "aarch64-linux-gnu-gcc"

[target.x86_64-unknown-linux-gnu]
linker = "x86_64-linux-gnu-gcc"
EOF

echo "Rust setup complete!"
