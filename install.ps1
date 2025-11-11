# Install script for q CLI tool (Windows/Powershell version)
# Fetches the appropriate binary for Windows and installs it.

param(
    [string]$RepoOwner = "atharva-again",  # Replace with your GitHub username
    [string]$RepoName = "q",                     # Replace with your repo name
    [string]$ReleaseTag = "v1.0.0"               # Replace with the release tag
)

# Detect architecture
$arch = $env:PROCESSOR_ARCHITECTURE.ToLower()
switch ($arch) {
    "amd64" { $arch = "amd64" }
    "arm64" { $arch = "arm64" }
    default {
        Write-Host "Unsupported architecture: $arch"
        exit 1
    }
}

# Binary details
$binaryName = "q.exe"
$zipName = "q-windows-$arch.zip"
$downloadUrl = "https://github.com/$RepoOwner/$RepoName/releases/download/$ReleaseTag/$zipName"

Write-Host "Detected Arch: $arch"
Write-Host "Downloading $zipName from $downloadUrl..."

# Download the zip
try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipName
} catch {
    Write-Host "Failed to download: $_"
    exit 1
}

# Download checksums
$checksumUrl = "https://github.com/$RepoOwner/$RepoName/releases/download/$ReleaseTag/SHA256SUMS"
$checksumFile = "SHA256SUMS"
Write-Host "Downloading checksums from $checksumUrl..."
try {
    Invoke-WebRequest -Uri $checksumUrl -OutFile $checksumFile
} catch {
    Write-Host "Failed to download checksums: $_"
    exit 1
}

# Verify checksum
Write-Host "Verifying checksum for $zipName..."
$expectedHash = $null
Get-Content $checksumFile | ForEach-Object {
    if ($_ -match "^(\w+)\s+$zipName$") {
        $expectedHash = $matches[1]
    }
}
if ($expectedHash) {
    $actualHash = (Get-FileHash -Path $zipName -Algorithm SHA256).Hash
    if ($actualHash -ne $expectedHash) {
        Write-Host "Checksum verification failed! Expected: $expectedHash, Got: $actualHash"
        exit 1
    } else {
        Write-Host "Checksum verification passed."
    }
} else {
    Write-Host "Checksum for $zipName not found in $checksumFile. Skipping verification."
}

# Cleanup checksum file
Remove-Item $checksumFile -Force

# Unzip
Write-Host "Extracting $zipName..."
try {
    Expand-Archive -Path $zipName -DestinationPath "." -Force
} catch {
    Write-Host "Failed to extract: $_"
    exit 1
}

# Determine install location
$installDir = "$env:USERPROFILE\bin"
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

# Move binary
$binaryPath = Join-Path $installDir "q.exe"
Move-Item -Path $binaryName -Destination $binaryPath -Force

# Add to PATH if not already
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$installDir*") {
    $newPath = "$userPath;$installDir"
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "Added $installDir to user PATH. Restart PowerShell or Command Prompt to apply."
}

# Cleanup
Remove-Item $zipName -Force

Write-Host "Installed q to $binaryPath"
Write-Host "For any issues, suggestions, or feature requests, please check https://github.com/$RepoOwner/$RepoName"
Write-Host "Installation complete! Starting setup..."

# Run setup
& $binaryPath -S