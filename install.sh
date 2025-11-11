#!/bin/bash

# Install script for q CLI tool
# Fetches the appropriate binary for the current OS/arch and installs it.

set -e

REPO_OWNER="atharva-again"  
REPO_NAME="q"                     
RELEASE_TAG="v1.0.1"              


OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case $OS in
    linux)
        ;;
    darwin)
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
esac

case $ARCH in
    x86_64|amd64)
        ARCH="amd64"
        ;;
    aarch64|arm64)
        ARCH="arm64"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Binary name
BINARY_NAME="q"

ZIP_NAME="q-${OS}-${ARCH}.zip"
DOWNLOAD_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/${RELEASE_TAG}/${ZIP_NAME}"

echo "Detected OS: $OS, Arch: $ARCH"
echo "Downloading $ZIP_NAME from $DOWNLOAD_URL..."

# Download the zip
if command -v curl >/dev/null 2>&1; then
    curl -L -o "$ZIP_NAME" "$DOWNLOAD_URL"
elif command -v wget >/dev/null 2>&1; then
    wget -O "$ZIP_NAME" "$DOWNLOAD_URL"
else
    echo "Neither curl nor wget found. Please install one and try again."
    exit 1
fi

# Download checksums
CHECKSUM_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/${RELEASE_TAG}/SHA256SUMS"
CHECKSUM_FILE="SHA256SUMS"
echo "Downloading checksums from $CHECKSUM_URL..."
if command -v curl >/dev/null 2>&1; then
    curl -L -o "$CHECKSUM_FILE" "$CHECKSUM_URL"
elif command -v wget >/dev/null 2>&1; then
    wget -O "$CHECKSUM_FILE" "$CHECKSUM_URL"
else
    echo "Neither curl nor wget found. Please install one and try again."
    exit 1
fi

# Verify checksum
echo "Verifying checksum for $ZIP_NAME..."
expected_hash=$(grep " $ZIP_NAME$" "$CHECKSUM_FILE" | awk '{print $1}')
actual_hash=$(sha256sum "$ZIP_NAME" | awk '{print $1}')
if [ "$actual_hash" != "$expected_hash" ]; then
    echo "Checksum verification failed! Expected: $expected_hash, Got: $actual_hash"
    exit 1
else
    echo "Checksum verification passed."
fi

# Cleanup checksum file
rm "$CHECKSUM_FILE"

# Unzip
echo "Extracting $ZIP_NAME..."
if command -v unzip >/dev/null 2>&1; then
    unzip -q "$ZIP_NAME"
else
    echo "unzip not found. Please install unzip and try again."
    exit 1
fi

# Make executable and move to a bin directory
chmod +x "$BINARY_NAME"

# Determine install location
if [[ -w "/usr/local/bin" ]]; then
    INSTALL_DIR="/usr/local/bin"
elif [[ -w "/usr/bin" ]]; then
    INSTALL_DIR="/usr/bin"
else
    INSTALL_DIR="$HOME/.local/bin"
    mkdir -p "$INSTALL_DIR"
    # Add to PATH if not already
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$HOME/.bashrc"
        echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$HOME/.zshrc" 2>/dev/null || true
        echo "Added $INSTALL_DIR to PATH. Restart your shell or run 'source ~/.bashrc'."
    fi
fi

mv "$BINARY_NAME" "$INSTALL_DIR/q"
echo "Installed q to $INSTALL_DIR/q"

# Cleanup
rm "$ZIP_NAME"

echo "For any issues, suggestions, or feature requests, please check https://github.com/${REPO_OWNER}/${REPO_NAME}"
echo "Installation complete! Starting setup..."
"$INSTALL_DIR/q" -S