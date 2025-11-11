# Install script for q CLI tool (Windows/Powershell version)
# Fetches the appropriate binary for Windows and installs it.


param(
    [string]$RepoOwner = "atharva-again",
    [string]$RepoName = "q",
    [string]$Version = "v1.0.1",
    [string]$Action = "install" # install|update|uninstall
)

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
    exit 1
}

# Uninstall logic
if ($Action -eq "uninstall") {
    if (Test-Path $installDir) {
        Remove-Item -Path $installDir -Recurse -Force
        Write-Host "Uninstalled q from $installDir" -ForegroundColor Green
    } else {
        Write-Host "No installation found at $installDir" -ForegroundColor Yellow
    }
    exit 0
}


# Check if version exists
$versionUrl = "https://github.com/$RepoOwner/$RepoName/releases/tag/$Version"
try {
    $resp = Invoke-WebRequest -Uri $versionUrl -Method Head -ErrorAction Stop
} catch {
    Write-Host "Version $Version does not exist on GitHub. Aborting." -ForegroundColor Red
    exit 1
}

# Notify if install exists
if (Test-Path $installDir) {
    $existingFiles = Get-ChildItem $installDir
    Write-Host "An installation already exists at $installDir:" -ForegroundColor Red
    $existingFiles | ForEach-Object { Write-Host $_.Name }
    while ($true) {
        $response = Read-Host "Do you want to overwrite it? (y/n)"
        if ([string]::IsNullOrWhiteSpace($response)) {
            $response = "y"
        }
        if ($response -eq "y" -or $response -eq "Y") {
            break
        } elseif ($response -eq "n" -or $response -eq "N") {
            Write-Host "Aborting installation." -ForegroundColor Red
            exit 1
        } else {
            Write-Host "Invalid input. Please enter y or n." -ForegroundColor Red
        }
    }
    Remove-Item -Path $installDir -Recurse -Force
}
New-Item -ItemType Directory -Path $installDir -Force | Out-Null

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
    Write-Host "Failed to download $zipName: $_" -ForegroundColor Red
    Remove-Item -Path $tmpDir -Recurse -Force
    exit 1
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
    Remove-Item -Path $tmpDir -Recurse -Force
    exit 1
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
    Remove-Item -Path $tmpDir -Recurse -Force
    exit 1
}
$actualHash = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash
if ($actualHash -ne $expectedHash) {
    Write-Host "Checksum verification failed! Expected: $expectedHash, Got: $actualHash" -ForegroundColor Red
    Remove-Item -Path $tmpDir -Recurse -Force
    exit 1
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
    Remove-Item -Path $tmpDir -Recurse -Force
    exit 1
}

Write-Host ""

# Atomic move: binary to bin, docs to docs
$binaryPath = Join-Path $extractDir $binaryName
if (Test-Path $binaryPath) {
    Move-Item -Path $binaryPath -Destination (Join-Path $installDir $binaryName) -Force
} else {
    Write-Host "Binary $binaryName not found after extraction. Aborting." -ForegroundColor Red
    Remove-Item -Path $tmpDir -Recurse -Force
    exit 1
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
Write-Host "Installed q. Restart Powershell or Command Prompt and then run q -s to start setup" -ForegroundColor Green

Write-Host ""
Write-Host "For any issues, suggestions, or feature requests, please check https://github.com/$RepoOwner/$RepoName"
