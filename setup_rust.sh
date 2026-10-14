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

# Install cargo-wl; its wstp-sys build can't discover the CI container's Wolfram Engine,
# so name the engine's WSTP CompilerAdditions via WSTP_COMPILER_ADDITIONS_DIRECTORY
if ! command -v cargo-wl &> /dev/null; then
    if [ -z "${WSTP_COMPILER_ADDITIONS_DIRECTORY:-}" ]; then
        case "$(uname -m)" in
            x86_64) wstp_system_id="Linux-x86-64" ;;
            aarch64) wstp_system_id="Linux-ARM64" ;;
            *) wstp_system_id="" ;;
        esac
        if [ -n "$wstp_system_id" ]; then
            wstp_dir=$(find /usr/local/Wolfram /opt/Wolfram -maxdepth 10 -type d \
                -path "*/SystemFiles/Links/WSTP/DeveloperKit/$wstp_system_id/CompilerAdditions" \
                -print -quit 2>/dev/null || true)
            if [ -n "$wstp_dir" ] && [ -f "$wstp_dir/libWSTP64i4.a" ]; then
                export WSTP_COMPILER_ADDITIONS_DIRECTORY="$wstp_dir"
                echo "Using WSTP CompilerAdditions: $wstp_dir"
            fi
        fi
    fi
    cargo install cargo-wl --locked
fi

# Configure Cargo linkers; macOS frameworks and stubs come from the SDK
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
