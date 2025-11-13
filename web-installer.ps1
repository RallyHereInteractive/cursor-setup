# Cursor Development Environment Web Installer
# Run with: iex (irm 'https://raw.githubusercontent.com/RallyHereInteractive/cursor-setup/main/web-installer.ps1')

# Set execution policy for the current process
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force

# Navigate to Documents folder
$documentsPath = [Environment]::GetFolderPath("MyDocuments")
Set-Location $documentsPath

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Cursor Setup - Installing..." -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Yellow
Write-Host ""

# Create temporary directory
$tempDir = Join-Path $env:TEMP "cursor-setup-$(Get-Date -Format 'yyyyMMddHHmmss')"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    Write-Host "Downloading setup files..." -ForegroundColor Yellow
    
    # Download the main setup script
    $setupScriptUrl = "https://raw.githubusercontent.com/RallyHereInteractive/cursor-setup/main/setup-cursor-environment.ps1"
    $setupScriptPath = Join-Path $tempDir "setup-cursor-environment.ps1"
    Invoke-WebRequest -Uri $setupScriptUrl -OutFile $setupScriptPath -UseBasicParsing
    
    Write-Host "Starting installation..." -ForegroundColor Green
    Write-Host ""
    
    # Execute the setup script with the repository URL
    $clonePath = Join-Path $documentsPath "cursor-setup"
    & $setupScriptPath -RepositoryUrl "https://github.com/RallyHereInteractive/cursor-setup.git" -CloneDirectory $clonePath
    
} catch {
    Write-Host "Error during installation: $_" -ForegroundColor Red
    exit 1
} finally {
    # Clean up
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
