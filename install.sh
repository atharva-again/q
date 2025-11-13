#!/bin/bash

# Install script for q CLI tool
# Fetches the appropriate binary for q CLI tool and installs it.

# ASCII Art for q
cat << 'EOF'  
          
  /$$$$$$ 
 /$$__  $$
| $$  \ $$
| $$  | $$
|  $$$$$$$
 \____  $$
      | $$
      | $$
      |__/
EOF

set -e

REPO_OWNER="atharva-again"
REPO_NAME="q"
VERSION="v1.2.1-beta"

INSTALL_BIN="$HOME/.local/bin/q"
INSTALL_DOCS="$HOME/.local/q"

OS=$(uname | tr '[:upper:]' '[:lower:]')
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
    # Existing installation, show menu
    printf "\033[1;31mq ($VERSION) already exists. The binary is at $INSTALL_BIN and the docs are at $INSTALL_DOCS:\033[0m\n"
    echo ""
    echo "Choose an option:"
    echo "1. Update (overwrite existing)"
    echo "2. Uninstall"
    echo "3. Cancel"
    while true; do
        read -r -p "Enter choice (1-3): " choice < /dev/tty
        case $choice in
            1)
                rm -rf "$INSTALL_BIN"
                rm -rf "$INSTALL_DOCS"
                break
                ;;
            2)
                rm -rf "$INSTALL_BIN"
                rm -rf "$INSTALL_DOCS"
                printf "\033[1;32mUninstalled q ($VERSION) from $INSTALL_BIN and $INSTALL_DOCS\033[0m\n"
                exit 0
                ;;
            3)
                printf "\033[1;31mInstallation cancelled.\033[0m\n"
                exit 1
                ;;
            *)
                printf "\033[1;31mInvalid choice. Please enter 1, 2, or 3.\033[0m\n"
                ;;
        esac
    done
fi

mkdir -p "$INSTALL_DOCS"
mkdir -p "$(dirname $INSTALL_BIN)"

echo "Detected OS: $OS, Arch: $ARCH"
echo ""

TMPDIR=$(mktemp -d)
cd "$TMPDIR"

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

cd /
rmdir "$TMPDIR"

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

printf "\033[1;32mInstalled q ($VERSION). Restart your shell or run 'source ~/.bashrc' and then run q -s to start setup\033[0m\n"
echo ""
echo "For any issues, suggestions, or feature requests, please check https://github.com/${REPO_OWNER}/${REPO_NAME}"