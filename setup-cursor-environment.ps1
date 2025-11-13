# Cursor Setup Script - Installs Git, Cursor, and development tools

param(
    [Parameter(Mandatory=$false)]
    [string]$RepositoryUrl = "https://github.com/RallyHereInteractive/cursor-setup.git",
    
    [Parameter(Mandatory=$false)]
    [string]$CloneDirectory = "$env:USERPROFILE\cursor-studio-setup"
)

# Set execution policy for the current process
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force

# Color functions for output
function Write-ColorOutput {
    param([string]$Text, [string]$ForegroundColor = 'White')
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    Write-Host $Text
    $host.UI.RawUI.ForegroundColor = $fc
}

Write-ColorOutput "============================================" "Cyan"
Write-ColorOutput "Cursor Setup - Installing Components..." "Cyan"
Write-ColorOutput "============================================" "Cyan"
Write-Host ""

# Check if script is running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-ColorOutput "Note: Running without Administrator privileges. Some features may be limited." "Yellow"
    Write-Host ""
}

# Function to check if a command exists
function Test-CommandExists {
    param([string]$Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

# Function to install using winget
function Install-WithWinget {
    param(
        [string]$PackageId,
        [string]$DisplayName
    )
    
    Write-ColorOutput "Installing $DisplayName..." "Green"
    
    try {
        $result = winget install --id $PackageId --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "$DisplayName installed successfully!" "Green"
            return $true
        } elseif ($LASTEXITCODE -eq -1978335189) {
            Write-ColorOutput "$DisplayName is already installed." "Yellow"
            return $true
        } else {
            Write-ColorOutput "Failed to install $DisplayName. Exit code: $LASTEXITCODE" "Red"
            return $false
        }
    } catch {
        Write-ColorOutput "Error installing ${DisplayName}: $_" "Red"
        return $false
    }
}

# Step 1: Check and install winget if necessary
Write-ColorOutput "Step 1: Checking for Windows Package Manager (winget)..." "Cyan"
if (-not (Test-CommandExists "winget")) {
    Write-ColorOutput "Winget not found. Please install App Installer from the Microsoft Store." "Red"
    Write-ColorOutput "Opening Microsoft Store..." "Yellow"
    Start-Process "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1"
    Write-Host "Press any key once you've installed App Installer..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    if (-not (Test-CommandExists "winget")) {
        Write-ColorOutput "Winget still not found. Cannot continue." "Red"
        exit 1
    }
}
Write-ColorOutput "Winget is available!" "Green"
Write-Host ""

# Step 2: Install Git
Write-ColorOutput "Step 2: Installing Git..." "Cyan"
$gitInstalled = $false
if (Test-CommandExists "git") {
    Write-ColorOutput "Git is already installed." "Yellow"
    $gitVersion = git --version
    Write-ColorOutput "Current version: $gitVersion" "Gray"
    $gitInstalled = $true
} else {
    $gitInstalled = Install-WithWinget "Git.Git" "Git"
    if ($gitInstalled) {
        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
}
Write-Host ""

# Step 3: Install Cursor
Write-ColorOutput "Step 3: Installing Cursor..." "Cyan"
$cursorPath = "$env:LOCALAPPDATA\Programs\cursor\Cursor.exe"
if (Test-Path $cursorPath) {
    Write-ColorOutput "Cursor is already installed." "Yellow"
} else {
    # Note: Cursor might not be available via winget yet, so we'll use direct download
    Write-ColorOutput "Downloading Cursor installer..." "Yellow"
    $cursorInstallerUrl = "https://downloader.cursor.sh/windows/nsis/x64"
    $cursorInstallerPath = "$env:TEMP\CursorInstaller.exe"
    
    try {
        Invoke-WebRequest -Uri $cursorInstallerUrl -OutFile $cursorInstallerPath -UseBasicParsing
        Write-ColorOutput "Installing Cursor..." "Yellow"
        Start-Process -FilePath $cursorInstallerPath -ArgumentList "/S" -Wait
        
        if (Test-Path $cursorPath) {
            Write-ColorOutput "Cursor installed successfully!" "Green"
        } else {
            Write-ColorOutput "Cursor installation may have failed. Please install manually from https://cursor.sh" "Red"
        }
    } catch {
        Write-ColorOutput "Failed to download/install Cursor: $_" "Red"
        Write-ColorOutput "Please install Cursor manually from https://cursor.sh" "Yellow"
    }
}
Write-Host ""

# Step 4: Clone the repository
Write-ColorOutput "Step 4: Cloning studio configuration repository..." "Cyan"
if ($gitInstalled -or (Test-CommandExists "git")) {
    if (Test-Path $CloneDirectory) {
        Write-ColorOutput "Updating existing repository..." "Yellow"
        Push-Location $CloneDirectory
        git pull origin main 2>$null
        Pop-Location
    }
    
    if (-not (Test-Path $CloneDirectory)) {
        try {
            Write-ColorOutput "Cloning from $RepositoryUrl..." "Yellow"
            git clone $RepositoryUrl $CloneDirectory
            Write-ColorOutput "Repository cloned successfully!" "Green"
        } catch {
            Write-ColorOutput "Failed to clone repository: $_" "Red"
        }
    }
} else {
    Write-ColorOutput "Git is not available. Cannot clone repository." "Red"
}
Write-Host ""

# Step 5: Set up Cursor configuration
Write-ColorOutput "Step 5: Setting up Cursor configuration..." "Cyan"
$cursorConfigPath = "$env:APPDATA\Cursor\User"

if (-not (Test-Path $cursorConfigPath)) {
    New-Item -ItemType Directory -Path $cursorConfigPath -Force | Out-Null
}

# Copy configuration files from cloned repository if they exist
if (Test-Path $CloneDirectory) {
    # Check for rules file
    $rulesSource = "$CloneDirectory\.cursor\rules"
    $settingsSource = "$CloneDirectory\cursor-settings.json"
    
    if (Test-Path $rulesSource) {
        Write-ColorOutput "Copying rules configuration..." "Yellow"
        # The actual Cursor rules location might vary, this is a placeholder
        # You'll need to verify the correct location for Cursor rules
    }
    
    if (Test-Path $settingsSource) {
        Write-ColorOutput "Copying Cursor settings..." "Yellow"
        $settingsDest = "$cursorConfigPath\settings.json"
        
        if (Test-Path $settingsDest) {
            $backup = "$settingsDest.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Copy-Item $settingsDest $backup
            Write-ColorOutput "Backed up existing settings to: $backup" "Gray"
        }
        
        Copy-Item $settingsSource $settingsDest -Force
        Write-ColorOutput "Settings copied successfully!" "Green"
    }
}
Write-Host ""

# Step 6: Install MCP dependencies (if needed)
Write-ColorOutput "Step 6: Checking for MCP dependencies..." "Cyan"
# Check if Node.js is installed for MCP servers
if (Test-CommandExists "node") {
    $nodeVersion = node --version
    Write-ColorOutput "Node.js is installed: $nodeVersion" "Green"
} else {
    Write-ColorOutput "Node.js is not installed. Installing for MCP support..." "Yellow"
    Install-WithWinget "OpenJS.NodeJS.LTS" "Node.js LTS"
}
Write-Host ""

# Step 7: Final setup instructions
Write-ColorOutput "============================================" "Cyan"
Write-ColorOutput "Setup Complete!" "Green"
Write-ColorOutput "============================================" "Cyan"
Write-Host ""

Write-ColorOutput "Next Steps:" "Yellow"
Write-ColorOutput "1. Open Cursor from the Start Menu or Desktop" "White"
Write-ColorOutput "2. Open the cloned repository folder: $CloneDirectory" "White"
Write-ColorOutput "3. Review the .cursor folder for rules and configuration" "White"
Write-ColorOutput "4. Install any additional MCP servers as needed" "White"
Write-Host ""

# Launch Cursor if installed
if (Test-Path $cursorPath) {
    Write-ColorOutput "Launching Cursor..." "Green"
    Start-Process $cursorPath -ArgumentList $CloneDirectory
}

Write-Host ""
Write-ColorOutput "Setup complete!" "Green"
