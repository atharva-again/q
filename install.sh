#!/bin/bash

# Install script for q CLI tool
# Fetches the appropriate binary for the current OS/arch and installs it.

set -e

REPO_OWNER="atharva-again"  # Replace with your GitHub username
REPO_NAME="q"                     # Replace with your repo name
RELEASE_TAG="v1.0.0"              # Replace with the release tag

# Detect OS and architecture
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
BINARY_NAME="q-${OS}-${ARCH}"

ZIP_NAME="${BINARY_NAME}.zip"
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

echo "Installation complete! Starting setup..."
"$INSTALL_DIR/q" -S