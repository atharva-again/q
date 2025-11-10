#!/bin/bash

# Build script for q binaries across common laptop platforms
# Targets: linux/amd64, linux/arm64, darwin/amd64, darwin/arm64, windows/amd64, windows/arm64

set -e  # Exit on any error

echo "Building q binaries for multiple platforms..."

targets=("linux/amd64" "linux/arm64" "darwin/amd64" "darwin/arm64" "windows/amd64" "windows/arm64")

for target in "${targets[@]}"; do
    IFS='/' read -r os arch <<< "$target"
    output="q-${os}-${arch}"
    [[ "$os" == "windows" ]] && output="${output}.exe"
    echo "Building for $os/$arch -> $output"
    GOOS=$os GOARCH=$arch go build -ldflags="-s -w" -o "$output" .
    if [[ "$os" == "linux" || ( "$os" == "windows" && "$arch" == "amd64" ) ]]; then
        echo "Compressing $output with UPX..."
        upx -9 "$output"
    else
        echo "Skipping UPX for $os/$arch binary $output"
    fi
    echo "Cleaning build cache to free space..."
    go clean -cache
done

echo "Build complete. Compressing binaries..."

# Compress each binary
for target in "${targets[@]}"; do
    IFS='/' read -r os arch <<< "$target"
    binary="q-${os}-${arch}"
    [[ "$os" == "windows" ]] && binary="${binary}.exe"
    archive="q-${os}-${arch}.zip"
    echo "Compressing $binary -> $archive"
    zip "$archive" "$binary"
    rm "$binary"  # Remove uncompressed binary to save space
done

echo "All binaries built and compressed successfully!"
echo "Generated archives:"
ls -la *.zip