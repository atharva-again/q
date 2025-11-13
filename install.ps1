# Install script for q CLI tool (Windows/Powershell version)
# Fetches the appropriate binary for Windows and installs it.

# ASCII Art for q (use single-quoted here-string to avoid variable interpolation)
$logo = @'    
  ______
 / ____/
< <_|  |
 \__   |
    |__|
'@
Write-Host $logo

$RepoOwner = "atharva-again"
$RepoName = "q"
$Version = "v1.2.1-beta"

$installDir = "$env:LOCALAPPDATA\Programs\q"
$tmpDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.Guid]::NewGuid().ToString())
[System.IO.Directory]::CreateDirectory($tmpDir) | Out-Null

# Dependency check (atomic install)
$missingDeps = @()
if (-not (Get-Command Invoke-WebRequest -ErrorAction SilentlyContinue)) {
    $missingDeps += 'Invoke-WebRequest'
}
if (-not (Get-Command Expand-Archive -ErrorAction SilentlyContinue)) {
    $missingDeps += 'Expand-Archive'
}
if (-not (Get-Command Get-FileHash -ErrorAction SilentlyContinue)) {
    $missingDeps += 'Get-FileHash'
}
if ($missingDeps.Count -gt 0) {
    Write-Host "Missing dependencies: $($missingDeps -join ', ')" -ForegroundColor Red
    Write-Host "Please install the required tools before running this script." -ForegroundColor Red
    Write-Host "Helpful links:" -ForegroundColor Cyan
    Write-Host "- Invoke-WebRequest: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/invoke-webrequest" -ForegroundColor Cyan
    Write-Host "- Expand-Archive: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.archive/expand-archive" -ForegroundColor Cyan
    Write-Host "- Get-FileHash: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-filehash" -ForegroundColor Cyan
    return
}

if (Test-Path $installDir) {
    # Existing installation, show menu
    
    Write-Host ""
    Write-Host "q ($Version) already exists. The binary is at $installDir and the docs are at $installDir" -ForegroundColor Red
    Write-Host ""
    Write-Host "Choose an option:"
    Write-Host "1. Update (overwrite existing)"
    Write-Host "2. Uninstall"
    Write-Host "3. Cancel"
    $continueMenu = $true
    while ($continueMenu) {
        $choice = Read-Host "Enter choice (1-3)"
        switch ($choice) {
            1 {
                if (Test-Path $installDir) {
                    try {
                        Remove-Item -Path $installDir -Recurse -Force -ErrorAction Stop
                        Write-Host "Removed existing installation at $installDir" -ForegroundColor Yellow
                    } catch {
                        Write-Host "Warning: failed to remove ${installDir}: $_" -ForegroundColor Yellow
                        # continue anyway to attempt overwrite
                    }
                } else {
                    Write-Host "Note: install directory $installDir not found, proceeding with fresh install." -ForegroundColor Yellow
                }
                # exit menu and continue with installation
                $continueMenu = $false
                break
            }
            2 {
                if (Test-Path $installDir) {
                    try {
                        Remove-Item -Path $installDir -Recurse -Force -ErrorAction Stop
                        Write-Host "Uninstalled q ($Version) from $installDir" -ForegroundColor Green
                    } catch {
                        Write-Host "Failed to uninstall ${installDir}: $_" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "Install directory $installDir not found; nothing to uninstall." -ForegroundColor Yellow
                }
                return
            }
            3 {
                Write-Host "Installation cancelled." -ForegroundColor Red
                return
            }
            default {
                Write-Host "Invalid choice. Please enter 1, 2, or 3." -ForegroundColor Red
            }
        }
    }
}

# Check if version exists
$versionUrl = "https://github.com/$RepoOwner/$RepoName/releases/tag/$Version"
try {
    $resp = Invoke-WebRequest -Uri $versionUrl -Method Head -ErrorAction Stop
} catch {
    Write-Host "Version $Version does not exist on GitHub. Aborting." -ForegroundColor Red
    # Return instead of exiting the user's shell
    return
}

New-Item -ItemType Directory -Path $installDir -Force | Out-Null

# Detect architecture
$arch = $env:PROCESSOR_ARCHITECTURE.ToLower()
switch ($arch) {
    "amd64" { $arch = "amd64" }
    "arm64" { $arch = "arm64" }
    default {
        Write-Host "Unsupported architecture: $arch"
        # Return instead of exiting the user's shell
        return
    }
}

Write-Host ""

# Binary details
$binaryName = "q.exe"
$zipName = "q-windows-$arch.zip"
$downloadUrl = "https://github.com/$RepoOwner/$RepoName/releases/download/$Version/$zipName"

Write-Host "Detected Arch: $arch"
Write-Host ""
Write-Host "Downloading $zipName from $downloadUrl..."


# Download the zip to temp dir
$zipPath = Join-Path $tmpDir $zipName
try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -ErrorAction Stop
} catch {
    Write-Host "Failed to download ${zipName}: $_" -ForegroundColor Red
    Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    return
}

Write-Host ""

# Download checksums to temp dir
$checksumUrl = "https://github.com/$RepoOwner/$RepoName/releases/download/$Version/SHA256SUMS"
$checksumFile = Join-Path $tmpDir "SHA256SUMS"
Write-Host "Downloading checksums from $checksumUrl..."
try {
    Invoke-WebRequest -Uri $checksumUrl -OutFile $checksumFile -ErrorAction Stop
} catch {
    Write-Host "Failed to download checksums: $_" -ForegroundColor Red
    Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    return
}

# Verify checksum
Write-Host ""
Write-Host "Verifying checksum for $zipName..."
$expectedHash = $null
Get-Content $checksumFile | ForEach-Object {
    if ($_ -match "^(\w+)\s+$zipName$") {
        $expectedHash = $matches[1]
    }
}
if ($null -eq $expectedHash) {
    Write-Host "Checksum for $zipName not found in SHA256SUMS. Aborting." -ForegroundColor Red
    Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    return
}
$actualHash = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash
if ($actualHash -ne $expectedHash) {
    Write-Host "Checksum verification failed! Expected: $expectedHash, Got: $actualHash" -ForegroundColor Red
    Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    return
} else {
    Write-Host "Checksum verification passed."
}

# Cleanup checksum file
Remove-Item $checksumFile -Force

# Unzip all files to temp extract dir
$extractDir = Join-Path $tmpDir "extract"
New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
Write-Host "Extracting $zipName to $extractDir..."
try {
    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
} catch {
    Write-Host "Failed to extract: $_" -ForegroundColor Red
    Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    return
}

Write-Host ""

# Atomic move: binary to bin, docs to docs
$binaryPath = Join-Path $extractDir $binaryName
if (Test-Path $binaryPath) {
    Move-Item -Path $binaryPath -Destination (Join-Path $installDir $binaryName) -Force
} else {
    Write-Host "Binary $binaryName not found after extraction. Aborting." -ForegroundColor Red
    Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    return
}
Get-ChildItem -Path $extractDir | ForEach-Object {
    if ($_.Name -ne $binaryName) {
        try {
            Move-Item -Path $_.FullName -Destination $installDir -Force
        } catch {
            Write-Host "Failed to move $($_.Name) to $installDir." -ForegroundColor Yellow
        }
    }
}

# Cleanup temp dir
Remove-Item -Path $tmpDir -Recurse -Force

# Add to PATH if not already
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$installDir*") {
    $newPath = "$userPath;$installDir"
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "Added $installDir to user PATH."
}

# Install summary
Write-Host ""; Write-Host "Install Summary:" -ForegroundColor Cyan
Write-Host "Installed binary and docs to: $installDir"
Write-Host ""
Write-Host "Installed q ($Version). Restart Powershell or Command Prompt and then run q -s to start setup" -ForegroundColor Green

Write-Host ""
Write-Host "For any issues, suggestions, or feature requests, please check https://github.com/$RepoOwner/$RepoName"
