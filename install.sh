#!/bin/bash

# Install script for q CLI tool
# Fetches the appropriate binary for q CLI tool and installs it.

set -e

REPO_OWNER="atharva-again"
REPO_NAME="q"
VERSION="v1.1.0"
ACTION="install" # install|update|uninstall

while [[ $# -gt 0 ]]; do
    case $1 in
        --uninstall)
            ACTION="uninstall"
            shift
            ;;
        --update)
            ACTION="update"
            shift
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

INSTALL_BIN="$HOME/.local/bin/q"
INSTALL_DOCS="$HOME/.local/q"

if [[ "$ACTION" == "uninstall" ]]; then
    rm -rf "$INSTALL_BIN"
    rm -rf "$INSTALL_DOCS"
    printf "\033[1;32mUninstalled q from $INSTALL_BIN and $INSTALL_DOCS\033[0m\n"
    exit 0
fi

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

echo ""

BINARY_NAME="q"
ZIP_NAME="q-${OS}-${ARCH}.zip"
DOWNLOAD_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/${VERSION}/${ZIP_NAME}"

# Dependency check (atomic install)
missing_deps=()
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    missing_deps+=("curl or wget")
fi
if ! command -v unzip >/dev/null 2>&1; then
    missing_deps+=("unzip")
fi
if ! command -v sha256sum >/dev/null 2>&1; then
    missing_deps+=("sha256sum")
fi
if ! command -v awk >/dev/null 2>&1; then
    missing_deps+=("awk")
fi
if [ ${#missing_deps[@]} -gt 0 ]; then
    printf "\033[1;31mMissing dependencies: %s\033[0m\n" "${missing_deps[*]}"
    printf "\033[1;31mPlease install the required tools before running this script.\033[0m\n"
    printf "\033[1;36mHelpful links:\033[0m\n"
    printf "\033[1;36m- curl: https://curl.se/download.html\033[0m\n"
    printf "\033[1;36m- wget: https://www.gnu.org/software/wget/\033[0m\n"
    printf "\033[1;36m- unzip: https://github.com/madler/unzip\033[0m\n"
    printf "\033[1;36m- sha256sum: https://man7.org/linux/man-pages/man1/sha256sum.1.html\033[0m\n"
    printf "\033[1;36m- awk: https://www.gnu.org/software/gawk/manual/\033[0m\n"
    exit 1
fi

if [[ -f "$INSTALL_BIN" || -d "$INSTALL_DOCS" ]]; then
    printf "\033[1;31mAn installation already exists. The binary is at $INSTALL_BIN and the docs are at $INSTALL_DOCS:\033[0m\n"
    while true; do
        read -p "Do you want to overwrite it? (y/n): " response
        if [[ -z "$response" ]]; then
            response="y"
        fi
        if [[ "$response" == "y" || "$response" == "Y" ]]; then
            break
        elif [[ "$response" == "n" || "$response" == "N" ]]; then
            printf "\033[1;31mAborting installation.\033[0m\n"
            exit 1
        else
            printf "\033[1;31mInvalid input. Please enter y or n.\033[0m\n"
        fi
    done
    rm -rf "$INSTALL_BIN"
    rm -rf "$INSTALL_DOCS"
fi

mkdir -p "$INSTALL_DOCS"
mkdir -p "$(dirname $INSTALL_BIN)"

echo "Detected OS: $OS, Arch: $ARCH"
echo ""
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

        TMPDIR=$(mktemp -d)
echo ""

# Download checksums
CHECKSUM_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/${VERSION}/SHA256SUMS"
CHECKSUM_FILE="SHA256SUMS"
echo ""
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
echo ""
echo "Verifying checksum for $ZIP_NAME..."
expected_hash=$(grep " $ZIP_NAME$" "$CHECKSUM_FILE" | awk '{print $1}')
actual_hash=$(sha256sum "$ZIP_NAME" | awk '{print $1}')
if [ "$actual_hash" != "$expected_hash" ]; then
    echo "Checksum verification failed! Expected: $expected_hash, Got: $actual_hash"
    exit 1
else
    echo "Checksum verification passed."
fi

echo ""

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

echo ""

# Move binary to bin, all other files to docs
if [[ -f "$BINARY_NAME" ]]; then
    chmod +x "$BINARY_NAME"
    mv "$BINARY_NAME" "$INSTALL_BIN"
fi
for f in *; do
    if [[ "$f" != "q" && "$f" != "$ZIP_NAME" && "$f" != "install.sh" ]]; then
        mv "$f" "$INSTALL_DOCS/" 2>/dev/null || true
    fi
done

echo ""
rm "$ZIP_NAME"

# Add to PATH if not already
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo "export PATH=\"$HOME/.local/bin:$PATH\"" >> "$HOME/.bashrc"
    echo "export PATH=\"$HOME/.local/bin:$PATH\"" >> "$HOME/.zshrc" 2>/dev/null || true
    echo "Added $HOME/.local/bin to PATH."
fi

# Install summary
printf "\033[1;36mInstall Summary:\033[0m\n"
echo "Binary installed to $INSTALL_BIN"
echo "Documentation and additional files installed to $INSTALL_DOCS"
echo ""

printf "\033[1;32mInstalled q. Restart your shell or run 'source ~/.bashrc' and then run q -s to start setup\033[0m\n"
echo ""
echo "For any issues, suggestions, or feature requests, please check https://github.com/${REPO_OWNER}/${REPO_NAME}"