# Cursor Setup Script - Installs Git, Cursor, and development tools
# Run with: iex (irm 'https://raw.githubusercontent.com/RallyHereInteractive/cursor-setup/main/install.ps1')

param(
    [Parameter(Mandatory=$false)]
    [string]$RepositoryUrl = "https://github.com/RallyHereInteractive/cursor-setup.git",
    
    [Parameter(Mandatory=$false)]
    [string]$CloneDirectory = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$Wait
)

# Set execution policy for the current process
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force

# Navigate to Documents folder and set default clone directory if not provided
$documentsPath = [Environment]::GetFolderPath("MyDocuments")
Set-Location $documentsPath

if ([string]::IsNullOrEmpty($CloneDirectory)) {
    $CloneDirectory = "$documentsPath\cursor-setup"
}

# Check if running as Administrator and request elevation if needed
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Requesting administrator privileges..." -ForegroundColor Yellow
    try {
        $scriptPath = $MyInvocation.MyCommand.Path
        if (-not $scriptPath) {
            # If running from web, download to temp and run elevated
            $tempScript = "$env:TEMP\cursor-install.ps1"
            Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/RallyHereInteractive/cursor-setup/main/install.ps1' -OutFile $tempScript -UseBasicParsing
            Start-Process powershell.exe -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$tempScript`""
            exit
        } else {
            Start-Process powershell.exe -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`""
            exit
        }
    } catch {
        Write-Host "Could not elevate privileges. Continuing without admin rights (some features may be limited)." -ForegroundColor Yellow
    }
}

# Set error action preference to continue on errors (don't stop script execution)
$ErrorActionPreference = 'Continue'

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

# Note about admin privileges (already checked above)
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
        winget install --id $PackageId --silent --accept-package-agreements --accept-source-agreements | Out-Null
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

# Step 3: Install GitHub CLI
Write-ColorOutput "Step 3: Installing GitHub CLI..." "Cyan"
$ghInstalled = $false
if (Test-CommandExists "gh") {
    Write-ColorOutput "GitHub CLI is already installed." "Yellow"
    $ghVersion = gh --version
    Write-ColorOutput "Current version: $ghVersion" "Gray"
    $ghInstalled = $true
} else {
    $ghInstalled = Install-WithWinget "GitHub.cli" "GitHub CLI"
    if ($ghInstalled) {
        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
}
Write-Host ""

# Step 4: Install Cursor
Write-ColorOutput "Step 4: Installing Cursor..." "Cyan"
$cursorPath = "$env:LOCALAPPDATA\Programs\cursor\Cursor.exe"
$cursorInstalled = $false
if (Test-Path $cursorPath) {
    Write-ColorOutput "Cursor is already installed." "Yellow"
    $cursorInstalled = $true
} else {
    $cursorInstalled = Install-WithWinget "Anysphere.Cursor" "Cursor"
    if ($cursorInstalled) {
        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        # Wait a moment for installation to complete
        Start-Sleep -Seconds 2
        # Verify installation
        if (Test-Path $cursorPath) {
            Write-ColorOutput "Cursor installation verified!" "Green"
        } else {
            Write-ColorOutput "Note: Cursor may be installed but path verification failed. Try launching from Start Menu." "Yellow"
        }
    }
}
Write-Host ""

# Step 5: Clone the repository
Write-ColorOutput "Step 5: Cloning studio configuration repository..." "Cyan"
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

# Function to merge MCP configurations
function Merge-MCPConfig {
    param(
        [string]$ExistingConfigPath,
        [string]$NewConfigPath
    )
    
    $mergedServers = @{}
    
    # Load existing config if it exists
    if (Test-Path $ExistingConfigPath) {
        try {
            $existingContent = Get-Content $ExistingConfigPath -Raw | ConvertFrom-Json
            if ($existingContent.mcpServers) {
                foreach ($serverName in $existingContent.mcpServers.PSObject.Properties.Name) {
                    $mergedServers[$serverName] = $existingContent.mcpServers.$serverName
                }
                Write-ColorOutput "Found existing MCP configuration with $($mergedServers.Count) server(s)" "Gray"
            }
        } catch {
            Write-ColorOutput "Warning: Could not parse existing MCP config: $_" "Yellow"
        }
    }
    
    # Load new config from repository and merge
    if (Test-Path $NewConfigPath) {
        try {
            $newContent = Get-Content $NewConfigPath -Raw | ConvertFrom-Json
            if ($newContent.mcpServers) {
                $addedCount = 0
                foreach ($serverName in $newContent.mcpServers.PSObject.Properties.Name) {
                    if (-not $mergedServers.ContainsKey($serverName)) {
                        $mergedServers[$serverName] = $newContent.mcpServers.$serverName
                        $addedCount++
                        Write-ColorOutput "  Added MCP server: $serverName" "Green"
                    } else {
                        Write-ColorOutput "  MCP server '$serverName' already exists, preserving existing configuration" "Yellow"
                    }
                }
                if ($addedCount -eq 0) {
                    Write-ColorOutput "All required MCP servers are already configured" "Green"
                }
            }
        } catch {
            Write-ColorOutput "Warning: Could not parse new MCP config: $_" "Yellow"
        }
    }
    
    # Save merged config
    try {
        # Convert hashtable to PSCustomObject for proper JSON serialization
        $mcpServersObj = New-Object PSObject
        foreach ($key in $mergedServers.Keys) {
            $mcpServersObj | Add-Member -MemberType NoteProperty -Name $key -Value $mergedServers[$key]
        }
        
        $mergedConfigObj = [PSCustomObject]@{
            mcpServers = $mcpServersObj
        }
        
        $jsonContent = $mergedConfigObj | ConvertTo-Json -Depth 10
        $jsonContent | Set-Content $ExistingConfigPath -Encoding UTF8
        Write-ColorOutput "MCP configuration updated successfully!" "Green"
        return $true
    } catch {
        Write-ColorOutput "Error saving MCP config: $_" "Red"
        return $false
    }
}

# Step 6: Set up Cursor configuration
Write-ColorOutput "Step 6: Setting up Cursor configuration..." "Cyan"
try {
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
        
        # Only copy settings.json if it doesn't already exist
        if (Test-Path $settingsSource) {
            $settingsDest = "$cursorConfigPath\settings.json"
            
            if (Test-Path $settingsDest) {
                Write-ColorOutput "Cursor settings.json already exists, skipping to preserve your configuration" "Yellow"
            } else {
                Write-ColorOutput "Creating Cursor settings.json..." "Yellow"
                Copy-Item $settingsSource $settingsDest -Force -ErrorAction Stop
                Write-ColorOutput "Settings created successfully!" "Green"
            }
        }
        
        # Set up MCP configuration (merge, don't overwrite)
        # Cursor stores MCP config in ~\.cursor\mcp.json
        Write-ColorOutput "Configuring MCP servers..." "Yellow"
        
        # Default MCP config location for Cursor
        $cursorMcpConfigDir = "$env:USERPROFILE\.cursor"
        $mcpConfigPath = "$cursorMcpConfigDir\mcp.json"
        
        # Ensure .cursor directory exists
        if (-not (Test-Path $cursorMcpConfigDir)) {
            New-Item -ItemType Directory -Path $cursorMcpConfigDir -Force | Out-Null
            Write-ColorOutput "Created .cursor directory at: $cursorMcpConfigDir" "Gray"
        }
        
        # Check if MCP config already exists
        if (Test-Path $mcpConfigPath) {
            Write-ColorOutput "Found existing MCP config at: $mcpConfigPath" "Gray"
        }
        $mcpConfigSource = "$CloneDirectory\sample-mcp-config.json"
        
        if (Test-Path $mcpConfigSource) {
            try {
                Merge-MCPConfig -ExistingConfigPath $mcpConfigPath -NewConfigPath $mcpConfigSource
            } catch {
                Write-ColorOutput "Warning: Could not merge MCP configuration: $_" "Yellow"
                Write-ColorOutput "Continuing with installation..." "Yellow"
            }
        } else {
            Write-ColorOutput "Sample MCP config not found at: $mcpConfigSource" "Yellow"
        }
    } else {
        Write-ColorOutput "Repository directory not found at: $CloneDirectory" "Yellow"
        Write-ColorOutput "Skipping Cursor configuration setup. Repository may not have been cloned successfully." "Yellow"
    }
} catch {
    Write-ColorOutput "Error during Cursor configuration setup: $_" "Red"
    Write-ColorOutput "Continuing with installation..." "Yellow"
}
Write-Host ""

# Step 7: Install MCP dependencies (if needed)
Write-ColorOutput "Step 7: Checking for nvm and Node.js..." "Cyan"
try {
    # Check if nvm is installed
    $nvmInstalled = $false
    if (Test-CommandExists "nvm") {
        Write-ColorOutput "nvm (Node Version Manager) is already installed." "Green"
        $nvmInstalled = $true
    } else {
        Write-ColorOutput "Installing nvm-windows (Node Version Manager)..." "Yellow"
        $nvmInstalled = Install-WithWinget "CoreyButler.NVMforWindows" "nvm-windows"
        
        if ($nvmInstalled) {
            # Refresh PATH to include nvm
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            
            # Wait a moment for PATH to propagate
            Start-Sleep -Seconds 2
            
            # Verify nvm is now available
            if (Test-CommandExists "nvm") {
                Write-ColorOutput "nvm-windows installed successfully!" "Green"
            } else {
                Write-ColorOutput "Warning: nvm installed but not yet available in PATH. You may need to restart your terminal." "Yellow"
                Write-ColorOutput "Continuing with installation..." "Yellow"
            }
        }
    }

    # Install Node.js LTS using nvm
    if ($nvmInstalled -or (Test-CommandExists "nvm")) {
        # Check if Node.js is already installed via nvm
        if (Test-CommandExists "node") {
            $nodeVersion = node --version
            Write-ColorOutput "Node.js is already installed: $nodeVersion" "Green"
        } else {
            Write-ColorOutput "Installing Node.js LTS via nvm..." "Yellow"
            try {
                # Use nvm to install the latest LTS version
                $nvmOutput = nvm install lts 2>&1 | Out-String
                if ($LASTEXITCODE -eq 0) {
                    # Extract version number from output if available, otherwise try to use 'lts'
                    $versionMatch = [regex]::Match($nvmOutput, 'v(\d+\.\d+\.\d+)')
                    if ($versionMatch.Success) {
                        $installedVersion = $versionMatch.Groups[1].Value
                        nvm use $installedVersion | Out-Null
                        Write-ColorOutput "Node.js LTS installed successfully! (v$installedVersion)" "Green"
                    } else {
                        # Try using 'lts' as alias, or list and use the latest installed version
                        nvm use lts 2>&1 | Out-Null
                        if ($LASTEXITCODE -ne 0) {
                            # List installed versions and use the latest
                            $installedVersions = nvm list | Select-String -Pattern 'v\d+\.\d+\.\d+' | ForEach-Object { $_.Matches.Value }
                            if ($installedVersions.Count -gt 0) {
                                $latestVersion = $installedVersions[0] -replace 'v', ''
                                nvm use $latestVersion | Out-Null
                                Write-ColorOutput "Node.js LTS installed successfully! (v$latestVersion)" "Green"
                            } else {
                                Write-ColorOutput "Node.js LTS installed, but could not determine version" "Yellow"
                            }
                        } else {
                            Write-ColorOutput "Node.js LTS installed successfully!" "Green"
                        }
                    }
                    
                    # Refresh PATH again after nvm install
                    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
                    
                    # Verify installation
                    Start-Sleep -Seconds 2
                    if (Test-CommandExists "node") {
                        $nodeVersion = node --version
                        $npmVersion = npm --version
                        Write-ColorOutput "Node.js version: $nodeVersion" "Gray"
                        Write-ColorOutput "npm version: $npmVersion" "Gray"
                    } else {
                        Write-ColorOutput "Warning: Node.js installed but not yet available in PATH. You may need to restart your terminal." "Yellow"
                    }
                } else {
                    Write-ColorOutput "Failed to install Node.js via nvm. Exit code: $LASTEXITCODE" "Red"
                    Write-ColorOutput "Output: $nvmOutput" "Yellow"
                }
            } catch {
                Write-ColorOutput "Error installing Node.js via nvm: $_" "Red"
            }
        }
    } else {
        Write-ColorOutput "nvm is not available. Falling back to direct Node.js installation..." "Yellow"
        if (-not (Test-CommandExists "node")) {
            Install-WithWinget "OpenJS.NodeJS.LTS" "Node.js LTS"
        } else {
            $nodeVersion = node --version
            Write-ColorOutput "Node.js is already installed: $nodeVersion" "Green"
        }
    }
} catch {
    Write-ColorOutput "Error during MCP dependencies setup: $_" "Red"
    Write-ColorOutput "Continuing with installation..." "Yellow"
}
Write-Host ""

# Step 8: Install uv and Python 3.11
Write-ColorOutput "Step 8: Installing uv and Python 3.11..." "Cyan"
try {
    # Check if uv is already installed
    $uvInstalled = $false
    if (Test-CommandExists "uv") {
        Write-ColorOutput "uv is already installed." "Green"
        $uvVersion = uv --version 2>&1
        Write-ColorOutput "Current version: $uvVersion" "Gray"
        $uvInstalled = $true
    } else {
        Write-ColorOutput "Installing uv..." "Yellow"
        try {
            # Install uv using the official installer script
            # Using the standard uv installation pattern: Invoke-RestMethod pipes to Invoke-Expression
            Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression
            
            # Refresh PATH to include uv
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            
            # Wait a moment for PATH to propagate
            Start-Sleep -Seconds 2
            
            # Verify uv is now available
            if (Test-CommandExists "uv") {
                Write-ColorOutput "uv installed successfully!" "Green"
                $uvInstalled = $true
            } else {
                Write-ColorOutput "Warning: uv installed but not yet available in PATH. You may need to restart your terminal." "Yellow"
                Write-ColorOutput "Continuing with installation..." "Yellow"
                $uvInstalled = $true  # Assume it's installed, just not in PATH yet
            }
        } catch {
            Write-ColorOutput "Error installing uv: $_" "Red"
            Write-ColorOutput "You may need to install uv manually from https://github.com/astral-sh/uv" "Yellow"
        }
    }

    # Install Python 3.11 using uv
    if ($uvInstalled -or (Test-CommandExists "uv")) {
        # Refresh PATH to ensure uv is available
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        # Wait a moment for PATH to propagate
        Start-Sleep -Seconds 2
        
        # Check if Python 3.11 is already installed via uv
        $python311Installed = $false
        try {
            if (Test-CommandExists "uv") {
                # Check installed Python versions
                $pythonVersions = uv python list 2>&1 | Out-String
                if ($pythonVersions -like "*3.11*") {
                    Write-ColorOutput "Python 3.11 is already installed via uv." "Green"
                    $python311Installed = $true
                }
            }
        } catch {
            # If uv command fails, we'll try to install
        }
        
        if (-not $python311Installed) {
            Write-ColorOutput "Installing Python 3.11 via uv..." "Yellow"
            try {
                if (Test-CommandExists "uv") {
                    # Install Python 3.11 (uv will install the latest 3.11.x version)
                    $installResult = uv python install 3.11 2>&1 | Out-String
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-ColorOutput "Python 3.11 installed successfully via uv!" "Green"
                        
                        # Pin Python 3.11 as the default version
                        uv python pin 3.11 2>&1 | Out-Null
                        Write-ColorOutput "Python 3.11 set as default version." "Green"
                        
                        # Refresh PATH again
                        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
                        
                        # Verify installation
                        Start-Sleep -Seconds 2
                        if (Test-CommandExists "python") {
                            $pythonVersion = python --version 2>&1
                            Write-ColorOutput "Python version: $pythonVersion" "Gray"
                        } else {
                            Write-ColorOutput "Note: Python installed via uv. Use 'uv python pin 3.11' or 'uv run python' to use it." "Yellow"
                        }
                    } else {
                        Write-ColorOutput "Failed to install Python 3.11 via uv. Exit code: $LASTEXITCODE" "Red"
                        Write-ColorOutput "Output: $installResult" "Yellow"
                    }
                } else {
                    Write-ColorOutput "uv is not available in PATH. You may need to restart your terminal." "Yellow"
                }
            } catch {
                Write-ColorOutput "Error installing Python 3.11 via uv: $_" "Red"
                Write-ColorOutput "You may need to install Python manually or restart your terminal and try again." "Yellow"
            }
        } else {
            # Python 3.11 is installed, verify it's pinned
            try {
                if (Test-CommandExists "uv") {
                    $pinnedVersion = uv python pin 2>&1 | Out-String
                    if ($pinnedVersion -notlike "*3.11*") {
                        Write-ColorOutput "Setting Python 3.11 as default version..." "Yellow"
                        uv python pin 3.11 2>&1 | Out-Null
                        Write-ColorOutput "Python 3.11 set as default version." "Green"
                    }
                }
            } catch {
                Write-ColorOutput "Could not verify Python 3.11 default version setting." "Yellow"
            }
        }
    } else {
        Write-ColorOutput "uv is not available. Python 3.11 installation skipped." "Yellow"
        Write-ColorOutput "You can install Python manually or install uv and run this script again." "Yellow"
    }
} catch {
    Write-ColorOutput "Error during uv and Python setup: $_" "Red"
    Write-ColorOutput "Continuing with installation..." "Yellow"
}
Write-Host ""

# Step 9: Final setup instructions
Write-ColorOutput "============================================" "Cyan"
Write-ColorOutput "Setup Complete!" "Green"
Write-ColorOutput "============================================" "Cyan"
Write-Host ""

Write-ColorOutput "Next Steps:" "Yellow"
Write-ColorOutput "1. Open Cursor from the Start Menu or Desktop" "White"
Write-ColorOutput "2. Open the cloned repository folder: $CloneDirectory" "White"
Write-ColorOutput "3. Review the .cursor folder for rules and configuration" "White"
Write-ColorOutput "4. Install any additional MCP servers as needed" "White"
Write-ColorOutput "5. If uv/Python was just installed, restart your terminal for PATH changes to take effect" "White"
Write-Host ""

# Launch Cursor if installed
if (Test-Path $cursorPath) {
    Write-ColorOutput "Launching Cursor..." "Green"
    Start-Process $cursorPath -ArgumentList $CloneDirectory
}

Write-Host ""
Write-ColorOutput "Setup complete!" "Green"

# Wait for user input if -Wait flag is set
if ($Wait) {
    Write-Host ""
    Write-ColorOutput "Press Enter to exit..." "Gray"
    $null = Read-Host
}

