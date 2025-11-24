# Cursor Setup Script - Installs Git, Cursor, and development tools
# Run with: iex (irm 'https://raw.githubusercontent.com/RallyHereInteractive/cursor-setup/main/install.ps1')

param(
    [Parameter(Mandatory=$false)]
    [string]$RepositoryUrl = "https://github.com/RallyHereInteractive/cursor-setup.git",
    
    [Parameter(Mandatory=$false)]
    [string]$CloneDirectory = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Branch = "main",
    
    [Parameter(Mandatory=$false)]
    [switch]$NoWait
)

# Set execution policy for the current process
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force

# Navigate to Documents folder and set default clone directory if not provided
$documentsPath = [Environment]::GetFolderPath("MyDocuments")
Set-Location $documentsPath

if ([string]::IsNullOrEmpty($CloneDirectory)) {
    $CloneDirectory = "$documentsPath\gamedev-tools\cursor-setup"
}

# Check if running as Administrator and request elevation if needed
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Requesting administrator privileges..." -ForegroundColor Yellow
    try {
        $scriptPath = $MyInvocation.MyCommand.Path
        
        # Build argument list with all parameters
        $argList = @("-ExecutionPolicy", "Bypass", "-File")
        
        if (-not $scriptPath) {
            # If running from web, download to temp and run elevated
            # Extract repository path from RepositoryUrl to construct the raw GitHub URL
            $tempScript = "$env:TEMP\cursor-install.ps1"
            if ($RepositoryUrl -match 'github\.com[:/]([^/]+/[^/]+?)(?:\.git)?$') {
                $repoPath = $matches[1]
                $downloadUrl = "https://raw.githubusercontent.com/$repoPath/$Branch/install.ps1"
            } else {
                # Fallback to default if URL format is unexpected
                $downloadUrl = "https://raw.githubusercontent.com/RallyHereInteractive/cursor-setup/$Branch/install.ps1"
            }
            Invoke-WebRequest -Uri $downloadUrl -OutFile $tempScript -UseBasicParsing
            $argList += "`"$tempScript`""
        } else {
            $argList += "`"$scriptPath`""
        }
        
        # Always pass all parameters to ensure they're preserved during elevation
        # Escape quotes in parameter values
        $escapedRepoUrl = $RepositoryUrl -replace '"', '`"'
        $escapedCloneDir = $CloneDirectory -replace '"', '`"'
        $escapedBranch = $Branch -replace '"', '`"'
        
        $argList += "-RepositoryUrl", "`"$escapedRepoUrl`""
        if (-not [string]::IsNullOrEmpty($CloneDirectory)) {
            $argList += "-CloneDirectory", "`"$escapedCloneDir`""
        }
        $argList += "-Branch", "`"$escapedBranch`""
        if ($NoWait) {
            $argList += "-NoWait"
        }
        
        $argString = $argList -join " "
        Start-Process powershell.exe -Verb RunAs -ArgumentList $argString
        exit
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
        try {
            # Fetch all branches from remote
            $fetchOutput = git fetch origin 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-ColorOutput "Warning: Failed to fetch from origin: $fetchOutput" "Yellow"
            }
            
            # Clean working directory completely before checkout
            # Reset any uncommitted changes to tracked files
            git reset --hard HEAD 2>&1 | Out-Null
            # Remove untracked files and directories
            git clean -fd 2>&1 | Out-Null
            Write-ColorOutput "Cleaned working directory" "Gray"
            
            # Check if branch exists locally (more reliable check)
            $localBranchOutput = git branch --list $Branch 2>&1
            $localBranchExists = ($localBranchOutput -match "^\s*\*?\s*$Branch\s*$" -or ($localBranchOutput -and $localBranchOutput.Trim() -ne ""))
            
            # Check if branch exists on remote (more reliable check)
            $remoteBranchOutput = git ls-remote --heads origin $Branch 2>&1
            $remoteBranchExists = ($LASTEXITCODE -eq 0 -and $remoteBranchOutput -and $remoteBranchOutput.Trim() -ne "")
            
            if ($remoteBranchExists) {
                # Remote branch exists
                if ($localBranchExists) {
                    # Local branch exists, checkout and update
                    $checkoutOutput = git checkout $Branch 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        $resetOutput = git reset --hard origin/$Branch 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            Write-ColorOutput "Checked out branch '$Branch' and updated to latest" "Green"
                        } else {
                            Write-ColorOutput "Warning: Checked out branch '$Branch' but failed to reset to origin/$Branch" "Yellow"
                            Write-ColorOutput "  Error: $resetOutput" "Gray"
                        }
                    } else {
                        Write-ColorOutput "Failed to checkout branch '$Branch': $checkoutOutput" "Red"
                    }
                } else {
                    # Local branch doesn't exist, create tracking branch
                    $checkoutOutput = git checkout -b $Branch origin/$Branch 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-ColorOutput "Created local branch '$Branch' tracking origin/$Branch" "Green"
                    } else {
                        Write-ColorOutput "Failed to create branch '$Branch'" "Red"
                        Write-ColorOutput "  Error: $checkoutOutput" "Gray"
                        # Try alternative: fetch and checkout directly
                        Write-ColorOutput "  Attempting alternative checkout method..." "Yellow"
                        $altFetchOutput = git fetch origin $Branch 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            $altCheckout = git checkout $Branch 2>&1
                            if ($LASTEXITCODE -eq 0) {
                                Write-ColorOutput "Successfully checked out branch '$Branch' using alternative method" "Green"
                            } else {
                                Write-ColorOutput "  Alternative method also failed: $altCheckout" "Red"
                            }
                        } else {
                            Write-ColorOutput "  Alternative fetch failed: $altFetchOutput" "Red"
                        }
                    }
                }
            } elseif ($localBranchExists) {
                # Local branch exists but no remote, just checkout
                $checkoutOutput = git checkout $Branch 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-ColorOutput "Checked out local branch '$Branch' (no remote tracking)" "Yellow"
                } else {
                    Write-ColorOutput "Failed to checkout local branch '$Branch': $checkoutOutput" "Red"
                }
            } else {
                # Branch doesn't exist, stay on current branch and pull
                Write-ColorOutput "Branch '$Branch' not found on remote or locally, staying on current branch" "Yellow"
                $currentBranch = git rev-parse --abbrev-ref HEAD 2>&1
                if ($currentBranch) {
                    Write-ColorOutput "Current branch: $currentBranch" "Gray"
                }
                $pullOutput = git pull 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-ColorOutput "Updated current branch" "Green"
                } else {
                    Write-ColorOutput "Warning: Failed to pull updates: $pullOutput" "Yellow"
                }
            }
        } catch {
            Write-ColorOutput "Error updating repository: $_" "Red"
        }
        Pop-Location
    }
    
    if (-not (Test-Path $CloneDirectory)) {
        try {
            Write-ColorOutput "Cloning from $RepositoryUrl (branch: $Branch)..." "Yellow"
            # Try cloning with the specific branch
            git clone -b $Branch $RepositoryUrl $CloneDirectory 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                # If branch doesn't exist, try cloning default branch and then checking out
                Write-ColorOutput "Branch '$Branch' not found, cloning default branch..." "Yellow"
                git clone $RepositoryUrl $CloneDirectory 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Push-Location $CloneDirectory
                    # Fetch all branches
                    git fetch origin 2>$null
                    # Check if the requested branch exists on remote
                    $remoteBranch = git branch -r --list "origin/$Branch" 2>$null
                    if ($remoteBranch) {
                        # Branch exists on remote, checkout and track it
                        git checkout -b $Branch origin/$Branch 2>$null
                        if ($LASTEXITCODE -eq 0) {
                            Write-ColorOutput "Checked out branch '$Branch'" "Green"
                        } else {
                            Write-ColorOutput "Failed to checkout branch '$Branch'" "Red"
                        }
                    } else {
                        Write-ColorOutput "Branch '$Branch' does not exist on remote, staying on default branch" "Yellow"
                    }
                    Pop-Location
                } else {
                    Write-ColorOutput "Failed to clone repository" "Red"
                }
            } else {
                # Verify we're on the correct branch
                Push-Location $CloneDirectory
                $currentBranch = git rev-parse --abbrev-ref HEAD 2>$null
                if ($currentBranch -ne $Branch) {
                    Write-ColorOutput "Verifying branch checkout..." "Yellow"
                    git checkout $Branch 2>$null
                }
                Pop-Location
                Write-ColorOutput "Repository cloned successfully on branch '$Branch'!" "Green"
            }
        } catch {
            Write-ColorOutput "Failed to clone repository: $_" "Red"
        }
    }
} else {
    Write-ColorOutput "Git is not available. Cannot clone repository." "Red"
}
Write-Host ""

# Step 5.5: Install yq for YAML processing
Write-ColorOutput "Step 5.5: Installing yq (YAML processor)..." "Cyan"
$yqInstalled = $false
if (Test-CommandExists "yq") {
    Write-ColorOutput "yq is already installed." "Green"
    $yqVersion = yq --version 2>&1
    Write-ColorOutput "Current version: $yqVersion" "Gray"
    $yqInstalled = $true
} else {
    # Try installing via winget first
    Write-ColorOutput "Installing yq via winget..." "Yellow"
    $yqInstalled = Install-WithWinget "mikefarah.yq" "yq"
    
    if (-not $yqInstalled) {
        # Fallback: Try direct download for Windows
        Write-ColorOutput "Winget installation failed, trying direct download..." "Yellow"
        try {
            $yqVersion = "v4.44.3"  # Latest stable version as of writing
            $yqUrl = "https://github.com/mikefarah/yq/releases/download/$yqVersion/yq_windows_amd64.exe"
            $yqPath = "$env:ProgramFiles\yq\yq.exe"
            $yqDir = "$env:ProgramFiles\yq"
            
            if (-not (Test-Path $yqDir)) {
                New-Item -ItemType Directory -Path $yqDir -Force | Out-Null
            }
            
            Write-ColorOutput "Downloading yq from GitHub..." "Yellow"
            Invoke-WebRequest -Uri $yqUrl -OutFile $yqPath -UseBasicParsing
            
            # Add to PATH for current session
            $env:Path = "$yqDir;$env:Path"
            
            # Verify installation
            Start-Sleep -Seconds 1
            if (Test-CommandExists "yq") {
                Write-ColorOutput "yq installed successfully!" "Green"
                $yqInstalled = $true
            } else {
                Write-ColorOutput "Warning: yq installed but not available in PATH. You may need to add $yqDir to your PATH manually." "Yellow"
                Write-ColorOutput "Continuing with installation..." "Yellow"
                $yqInstalled = $true  # Assume it's installed
            }
        } catch {
            Write-ColorOutput "Error installing yq: $_" "Red"
            Write-ColorOutput "You may need to install yq manually from https://github.com/mikefarah/yq" "Yellow"
        }
    } else {
        # Refresh PATH after winget installation
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        Start-Sleep -Seconds 2
    }
}
Write-Host ""

# Function to clone custom MCPs from YAML configuration
function Clone-CustomMCPs {
    param(
        [string]$ConfigPath,
        [string]$BaseMcpDirectory
    )
    
    if (-not (Test-Path $ConfigPath)) {
        Write-ColorOutput "MCPs configuration file not found at: $ConfigPath" "Gray"
        return @()
    }
    
    if (-not (Test-CommandExists "yq")) {
        Write-ColorOutput "yq is not available. Cannot process YAML configuration." "Red"
        return @()
    }
    
    # Ensure base MCP directory exists
    if (-not (Test-Path $BaseMcpDirectory)) {
        New-Item -ItemType Directory -Path $BaseMcpDirectory -Force | Out-Null
        Write-ColorOutput "Created MCP directory: $BaseMcpDirectory" "Gray"
    }
    
    $mcpList = @()
    
    try {
        # Use yq to parse YAML and extract MCP entries
        # Check if this is unified format (servers) or legacy format (mcps)
        $yqOutput = yq eval '.servers // .mcps' $ConfigPath -o json 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "Warning: Could not parse MCPs YAML: $yqOutput" "Yellow"
            return @()
        }
        
        # Parse the JSON output
        $mcpEntries = $yqOutput | ConvertFrom-Json
        
        # Handle single entry vs array
        if ($null -eq $mcpEntries) {
            return @()
        }
        if ($mcpEntries -isnot [Array]) {
            $mcpEntries = @($mcpEntries)
        }
        
        foreach ($mcp in $mcpEntries) {
            $mcpName = $mcp.name
            $mcpRepo = $mcp.repository
            $mcpBuildCommands = $mcp.buildCommands
            
            # Skip if no repository (standard MCP servers don't need cloning)
            if ([string]::IsNullOrEmpty($mcpRepo)) {
                continue
            }
            
            if ([string]::IsNullOrEmpty($mcpName)) {
                Write-ColorOutput "Warning: Skipping MCP entry with missing name" "Yellow"
                continue
            }
            
            $mcpDirectory = Join-Path $BaseMcpDirectory $mcpName
            
            Write-ColorOutput "Processing MCP: $mcpName" "Yellow"
            
            # Clone or update repository
            if (Test-Path $mcpDirectory) {
                Write-ColorOutput "  Updating existing repository..." "Gray"
                Push-Location $mcpDirectory
                git reset --hard 2>$null
                git pull origin main 2>$null
                if ($LASTEXITCODE -ne 0) {
                    # Try master branch if main fails
                    git pull origin master 2>$null
                }
                Pop-Location
            } else {
                Write-ColorOutput "  Cloning from $mcpRepo..." "Gray"
                try {
                    git clone $mcpRepo $mcpDirectory 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Write-ColorOutput "  Cloned successfully!" "Green"
                    } else {
                        Write-ColorOutput "  Failed to clone repository" "Red"
                        continue
                    }
                } catch {
                    Write-ColorOutput "  Error cloning repository: $_" "Red"
                    continue
                }
            }
            
            $mcpList += @{
                Name = $mcpName
                Directory = $mcpDirectory
                BuildCommands = $mcpBuildCommands
            }
        }
    } catch {
        Write-ColorOutput "Error processing custom MCPs configuration: $_" "Red"
    }
    
    return $mcpList
}

# Step 6: Clone custom MCPs
Write-ColorOutput "Step 6: Cloning custom MCP servers..." "Cyan"
$documentsPath = [Environment]::GetFolderPath("MyDocuments")
$mcpBaseDirectory = "$documentsPath\gamedev-tools\mcp"
# Try unified config first, fall back to legacy mcps.yaml
$customMcpsConfigPath = "$CloneDirectory\mcps-config.yaml"
if (-not (Test-Path $customMcpsConfigPath)) {
    $customMcpsConfigPath = "$CloneDirectory\mcps.yaml"
}

$customMcps = @()
if (Test-Path $CloneDirectory) {
    $customMcps = Clone-CustomMCPs -ConfigPath $customMcpsConfigPath -BaseMcpDirectory $mcpBaseDirectory
    if ($customMcps.Count -gt 0) {
        Write-ColorOutput "Cloned $($customMcps.Count) custom MCP server(s)" "Green"
    } else {
        Write-ColorOutput "No custom MCPs configured or found in repository" "Gray"
    }
} else {
    Write-ColorOutput "Repository directory not found. Skipping custom MCP cloning." "Yellow"
}
Write-Host ""

# Function to build custom MCPs
function Build-CustomMCPs {
    param(
        [array]$McpList
    )
    
    if ($McpList.Count -eq 0) {
        return
    }
    
    foreach ($mcp in $McpList) {
        $mcpName = $mcp.Name
        $mcpDirectory = $mcp.Directory
        $buildCommands = $mcp.BuildCommands
        
        # Skip if no build commands specified
        if ($null -eq $buildCommands -or $buildCommands.Count -eq 0) {
            Write-ColorOutput "Skipping build for $mcpName (no build commands specified)" "Gray"
            continue
        }
        
        Write-ColorOutput "Building MCP: $mcpName" "Yellow"
        
        if (-not (Test-Path $mcpDirectory)) {
            Write-ColorOutput "  Error: MCP directory not found at $mcpDirectory" "Red"
            continue
        }
        
        Push-Location $mcpDirectory
        
        $buildSuccess = $true
        foreach ($command in $buildCommands) {
            Write-ColorOutput "  Running: $command" "Gray"
            try {
                # Execute the build command
                Invoke-Expression $command 2>&1 | Out-String | ForEach-Object {
                    if ($_ -match "error|Error|ERROR|failed|Failed|FAILED") {
                        Write-ColorOutput "    $_" "Red"
                    } else {
                        Write-ColorOutput "    $_" "Gray"
                    }
                }
                
                if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
                    Write-ColorOutput "  Build command failed with exit code: $LASTEXITCODE" "Red"
                    $buildSuccess = $false
                    break
                }
            } catch {
                Write-ColorOutput "  Error executing build command: $_" "Red"
                $buildSuccess = $false
                break
            }
        }
        
        Pop-Location
        
        if ($buildSuccess) {
            Write-ColorOutput "  Build completed successfully!" "Green"
        } else {
            Write-ColorOutput "  Build failed for $mcpName" "Red"
        }
    }
}

# Step 7: Build custom MCPs
Write-ColorOutput "Step 7: Building custom MCP servers..." "Cyan"
if ($customMcps.Count -gt 0) {
    Build-CustomMCPs -McpList $customMcps
    Write-ColorOutput "Build process completed for custom MCPs" "Green"
} else {
    Write-ColorOutput "No custom MCPs to build (none configured)" "Gray"
}
Write-Host ""

# Function to normalize paths in MCP configuration
function Normalize-MCPPaths {
    param(
        [PSCustomObject]$McpServerConfig
    )
    
    # Skip normalization for URL-based MCPs
    if ($McpServerConfig.PSObject.Properties.Name -contains "url") {
        return $McpServerConfig
    }
    
    $homePath = $env:USERPROFILE
    
    # Helper function to normalize a single path string
    function Normalize-PathString {
        param([string]$Path)
        
        if ([string]::IsNullOrEmpty($Path)) {
            return $Path
        }
        
        # Replace ~/ or ~\ at the start with home directory path
        # Need to ensure proper path separator after home directory
        if ($Path -match '^~[/\\]') {
            # Remove ~/ or ~\ and join with home path
            $relativePath = $Path -replace '^~[/\\]', ''
            $normalizedPath = Join-Path $homePath $relativePath
            # Normalize path separators for Windows
            return $normalizedPath -replace '/', '\'
        } elseif ($Path -match '^~') {
            # Handle just ~ at the start (shouldn't happen, but be safe)
            $relativePath = $Path -replace '^~', ''
            $normalizedPath = Join-Path $homePath $relativePath
            return $normalizedPath -replace '/', '\'
        }
        
        return $Path
    }
    
    # Normalize command if it exists
    if ($McpServerConfig.PSObject.Properties.Name -contains "command") {
        $command = $McpServerConfig.command
        if ($command -is [string]) {
            $McpServerConfig.command = Normalize-PathString -Path $command
        }
    }
    
    # Normalize args array if it exists
    if ($McpServerConfig.PSObject.Properties.Name -contains "args") {
        $mcpArgs = $McpServerConfig.args
        if ($mcpArgs -is [Array]) {
            for ($i = 0; $i -lt $mcpArgs.Length; $i++) {
                if ($mcpArgs[$i] -is [string]) {
                    $mcpArgs[$i] = Normalize-PathString -Path $mcpArgs[$i]
                }
            }
            $McpServerConfig.args = $mcpArgs
        }
    }
    
    return $McpServerConfig
}

# Function to convert unified YAML MCP config to Cursor JSON format
function Convert-MCPToCursorJson {
    param(
        [string]$YamlConfigPath
    )
    
    if (-not (Test-Path $YamlConfigPath)) {
        Write-ColorOutput "Unified MCP config not found at: $YamlConfigPath" "Yellow"
        return $null
    }
    
    if (-not (Test-CommandExists "yq")) {
        Write-ColorOutput "yq is not available. Cannot convert MCP configuration." "Red"
        return $null
    }
    
    try {
        # Read servers from YAML
        $yqOutput = yq eval '.servers' $YamlConfigPath -o json 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "Warning: Could not parse unified MCP config: $yqOutput" "Yellow"
            return $null
        }
        
        $servers = $yqOutput | ConvertFrom-Json
        
        if ($null -eq $servers) {
            return $null
        }
        
        if ($servers -isnot [Array]) {
            $servers = @($servers)
        }
        
        # Build Cursor JSON structure
        $mcpServers = @{}
        
        foreach ($server in $servers) {
            # Skip disabled servers
            if ($server.enabled -eq $false) {
                continue
            }
            
            $serverName = $server.name
            if ([string]::IsNullOrEmpty($serverName)) {
                continue
            }
            
            $serverConfig = @{}
            
            # Handle URL-based MCPs
            if ($server.url) {
                $serverConfig.url = $server.url
                # URL-based configs don't need path normalization
                $normalizedConfig = [PSCustomObject]$serverConfig
            }
            # Handle command-based MCPs
            elseif ($server.command) {
                $serverConfig.command = $server.command
                
                if ($server.args) {
                    $serverConfig.args = $server.args
                }
                
                if ($server.env) {
                    $serverConfig.env = $server.env
                }
                
                # Normalize paths in the config (only for command-based configs)
                $serverConfigObj = [PSCustomObject]$serverConfig
                $normalizedConfig = Normalize-MCPPaths -McpServerConfig $serverConfigObj
            } else {
                # No command or url, skip this server
                Write-ColorOutput "  Warning: Server '$serverName' has neither 'command' nor 'url', skipping" "Yellow"
                continue
            }
            
            # Convert back to hashtable for JSON serialization
            $finalConfig = @{}
            foreach ($prop in $normalizedConfig.PSObject.Properties) {
                # If the property is env (PSCustomObject), convert it to hashtable for proper JSON serialization
                if ($prop.Name -eq "env" -and $prop.Value -is [PSCustomObject]) {
                    $envHashtable = @{}
                    foreach ($envKey in $prop.Value.PSObject.Properties.Name) {
                        $envHashtable[$envKey] = $prop.Value.$envKey
                    }
                    $finalConfig[$prop.Name] = $envHashtable
                } else {
                    $finalConfig[$prop.Name] = $prop.Value
                }
            }
            
            $mcpServers[$serverName] = $finalConfig
        }
        
        # Create the JSON structure
        $result = @{
            mcpServers = $mcpServers
        }
        
        return $result
    } catch {
        Write-ColorOutput "Error converting MCP config to Cursor JSON: $_" "Red"
        return $null
    }
}

# Function to convert unified YAML MCP config to Codex TOML format
function Convert-MCPToCodexToml {
    param(
        [string]$YamlConfigPath
    )
    
    if (-not (Test-Path $YamlConfigPath)) {
        Write-ColorOutput "Unified MCP config not found at: $YamlConfigPath" "Yellow"
        return $null
    }
    
    if (-not (Test-CommandExists "yq")) {
        Write-ColorOutput "yq is not available. Cannot convert MCP configuration." "Red"
        return $null
    }
    
    try {
        # Read servers from YAML
        $yqOutput = yq eval '.servers' $YamlConfigPath -o json 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "Warning: Could not parse unified MCP config: $yqOutput" "Yellow"
            return $null
        }
        
        $servers = $yqOutput | ConvertFrom-Json
        
        if ($null -eq $servers) {
            return $null
        }
        
        if ($servers -isnot [Array]) {
            $servers = @($servers)
        }
        
        # Build TOML structure using yq
        # We'll create a temporary YAML structure that yq can convert to TOML
        $tomlSections = @()
        
        foreach ($server in $servers) {
            # Skip disabled servers
            if ($server.enabled -eq $false) {
                continue
            }
            
            $serverName = $server.name
            if ([string]::IsNullOrEmpty($serverName)) {
                continue
            }
            
            # Build TOML section for this server
            $section = "[mcp_servers.$serverName]`n"
            
            # Handle URL-based MCPs
            if ($server.url) {
                $section += "url = `"$($server.url)`"`n"
            }
            # Handle command-based MCPs
            elseif ($server.command) {
                $section += "command = `"$($server.command)`"`n"
                
                if ($server.args) {
                    # Convert args array to TOML format
                    $argsList = @()
                    foreach ($arg in $server.args) {
                        # Escape quotes in arguments
                        $escapedArg = $arg -replace '"', '\"'
                        $argsList += "`"$escapedArg`""
                    }
                    $argsStr = $argsList -join ", "
                    $section += "args = [$argsStr]`n"
                }
                
                if ($server.env) {
                    $section += "`n[mcp_servers.$serverName.env]`n"
                    # Handle both PSCustomObject and hashtable/dictionary types
                    if ($server.env -is [PSCustomObject]) {
                        foreach ($key in $server.env.PSObject.Properties.Name) {
                            $value = $server.env.$key
                            # Escape quotes in values
                            $escapedValue = $value -replace '"', '\"'
                            $section += "$key = `"$escapedValue`"`n"
                        }
                    } elseif ($server.env -is [Hashtable] -or $server.env -is [System.Collections.IDictionary]) {
                        foreach ($key in $server.env.Keys) {
                            $value = $server.env[$key]
                            # Escape quotes in values
                            $escapedValue = $value -replace '"', '\"'
                            $section += "$key = `"$escapedValue`"`n"
                        }
                    }
                }
            } else {
                # No command or url, skip this server
                Write-ColorOutput "  Warning: Server '$serverName' has neither 'command' nor 'url', skipping" "Yellow"
                continue
            }
            
            # Add optional Codex-specific fields
            if ($server.startup_timeout_sec) {
                $section += "startup_timeout_sec = $($server.startup_timeout_sec)`n"
            }
            
            if ($server.tool_timeout_sec) {
                $section += "tool_timeout_sec = $($server.tool_timeout_sec)`n"
            }
            
            if ($server.enabled_tools) {
                $toolsStr = $server.enabled_tools -join '", "'
                $section += "enabled_tools = [`"$toolsStr`"]`n"
            }
            
            if ($server.disabled_tools) {
                $toolsStr = $server.disabled_tools -join '", "'
                $section += "disabled_tools = [`"$toolsStr`"]`n"
            }
            
            if ($null -ne $server.enabled) {
                $section += "enabled = $($server.enabled.ToString().ToLower())`n"
            }
            
            $tomlSections += $section
        }
        
        return $tomlSections -join "`n`n"
    } catch {
        Write-ColorOutput "Error converting MCP config to Codex TOML: $_" "Red"
        return $null
    }
}

# Function to merge Codex TOML configuration
function Merge-CodexTomlConfig {
    param(
        [string]$ExistingConfigPath,
        [string]$NewTomlContent
    )
    
    if ($null -eq $NewTomlContent -or [string]::IsNullOrEmpty($NewTomlContent)) {
        Write-ColorOutput "No new TOML content to merge" "Yellow"
        return $false
    }
    
    if (-not (Test-CommandExists "yq")) {
        Write-ColorOutput "yq is not available. Cannot merge Codex TOML configuration." "Red"
        return $false
    }
    
    try {
        $existingContent = ""
        $existingMcpServers = @{}
        
        # Read existing config if it exists
        if (Test-Path $ExistingConfigPath) {
            $existingContent = Get-Content $ExistingConfigPath -Raw
            Write-ColorOutput "Found existing Codex config at: $ExistingConfigPath" "Gray"
            
            # Extract existing mcp_servers sections using yq
            $yqOutput = yq eval '.mcp_servers // {}' $ExistingConfigPath -o json 2>&1
            if ($LASTEXITCODE -eq 0 -and $yqOutput) {
                $existingMcpServers = $yqOutput | ConvertFrom-Json
            }
        }
        
        # Parse new TOML content to extract server names
        $newServerNames = @()
        $lines = $NewTomlContent -split "`n"
        foreach ($line in $lines) {
            if ($line -match '\[mcp_servers\.([^\]]+)\]') {
                $serverName = $matches[1]
                if (-not $newServerNames.Contains($serverName)) {
                    $newServerNames += $serverName
                }
            }
        }
        
        # Check which servers are new
        $addedCount = 0
        foreach ($serverName in $newServerNames) {
            if (-not $existingMcpServers.PSObject.Properties.Name.Contains($serverName)) {
                $addedCount++
                Write-ColorOutput "  Adding MCP server to Codex: $serverName" "Green"
            } else {
                Write-ColorOutput "  MCP server '$serverName' already exists in Codex config, preserving existing configuration" "Yellow"
            }
        }
        
        if ($addedCount -eq 0) {
            Write-ColorOutput "All required MCP servers are already configured in Codex" "Green"
        }
        
        # Merge TOML content
        # If no existing config, just write the new content
        if ([string]::IsNullOrEmpty($existingContent)) {
            $NewTomlContent | Set-Content $ExistingConfigPath -Encoding UTF8
            Write-ColorOutput "Codex TOML configuration created successfully!" "Green"
            return $true
        }
        
        # For merging, we need to append new mcp_servers sections
        # Remove existing mcp_servers sections and append new ones
        $mergedContent = $existingContent
        
        # Remove existing mcp_servers sections (lines between [mcp_servers.*] and next [section] or end)
        $contentLines = $mergedContent -split "`n"
        $newLines = @()
        $skipUntilNextSection = $false
        
        foreach ($line in $contentLines) {
            if ($line -match '^\s*\[mcp_servers\.') {
                $skipUntilNextSection = $true
                continue
            }
            if ($skipUntilNextSection -and ($line -match '^\s*\[[^\]]+\]' -or [string]::IsNullOrWhiteSpace($line))) {
                $skipUntilNextSection = $false
                if (-not [string]::IsNullOrWhiteSpace($line)) {
                    $newLines += $line
                }
                continue
            }
            if (-not $skipUntilNextSection) {
                $newLines += $line
            }
        }
        
        # Append new mcp_servers sections
        $mergedContent = $newLines -join "`n"
        if (-not $mergedContent.EndsWith("`n")) {
            $mergedContent += "`n"
        }
        $mergedContent += "`n# MCP Servers (managed by cursor-setup)`n"
        $mergedContent += $NewTomlContent
        
        $mergedContent | Set-Content $ExistingConfigPath -Encoding UTF8
        Write-ColorOutput "Codex TOML configuration updated successfully!" "Green"
        return $true
    } catch {
        Write-ColorOutput "Error merging Codex TOML config: $_" "Red"
        return $false
    }
}

# Function to migrate legacy MCP configs to unified format
function Migrate-LegacyMCPConfig {
    param(
        [string]$CloneDirectory
    )
    
    $legacyJsonPath = "$CloneDirectory\cursor-mcp-config.json"
    $legacyYamlPath = "$CloneDirectory\mcps.yaml"
    $unifiedPath = "$CloneDirectory\mcps-config.yaml"
    
    # Check if unified config already exists
    if (Test-Path $unifiedPath) {
        Write-ColorOutput "Unified MCP config already exists, skipping migration" "Gray"
        return $false
    }
    
    # Check if we have legacy configs to migrate
    $hasLegacyJson = Test-Path $legacyJsonPath
    $hasLegacyYaml = Test-Path $legacyYamlPath
    
    if (-not $hasLegacyJson -and -not $hasLegacyYaml) {
        return $false
    }
    
    Write-ColorOutput "Migrating legacy MCP configs to unified format..." "Yellow"
    
    try {
        $servers = @()
        
        # Read legacy JSON config
        if ($hasLegacyJson) {
            $jsonContent = Get-Content $legacyJsonPath -Raw | ConvertFrom-Json
            if ($jsonContent.mcpServers) {
                foreach ($serverName in $jsonContent.mcpServers.PSObject.Properties.Name) {
                    $serverConfig = $jsonContent.mcpServers.$serverName
                    $server = @{
                        name = $serverName
                        command = $serverConfig.command
                        args = $serverConfig.args
                        enabled = $true
                    }
                    
                    if ($serverConfig.env) {
                        $server.env = $serverConfig.env
                    }
                    
                    $servers += $server
                }
            }
        }
        
        # Read legacy YAML config for custom MCPs
        if ($hasLegacyYaml -and (Test-CommandExists "yq")) {
            $yqOutput = yq eval '.mcps' $legacyYamlPath -o json 2>&1
            if ($LASTEXITCODE -eq 0 -and $yqOutput) {
                $customMcps = $yqOutput | ConvertFrom-Json
                if ($customMcps -isnot [Array]) {
                    $customMcps = @($customMcps)
                }
                
                foreach ($customMcp in $customMcps) {
                    # Find matching server in servers array and add repository/buildCommands
                    $matchingServer = $servers | Where-Object { $_.name -eq $customMcp.name }
                    if ($matchingServer) {
                        $matchingServer.repository = $customMcp.repository
                        if ($customMcp.buildCommands) {
                            $matchingServer.buildCommands = $customMcp.buildCommands
                        }
                    } else {
                        # Add new server entry
                        $server = @{
                            name = $customMcp.name
                            repository = $customMcp.repository
                            enabled = $true
                        }
                        if ($customMcp.buildCommands) {
                            $server.buildCommands = $customMcp.buildCommands
                        }
                        $servers += $server
                    }
                }
            }
        }
        
        # Create unified YAML
        $unifiedConfig = @{
            servers = $servers
        }
        
        # Convert to YAML using yq
        $yamlContent = $unifiedConfig | ConvertTo-Json -Depth 10
        $tempJson = "$env:TEMP\mcp-migration-temp.json"
        $yamlContent | Set-Content $tempJson -Encoding UTF8
        
        # Use yq to convert JSON to YAML
        yq eval -P '.' $tempJson > $unifiedPath 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "Successfully migrated legacy configs to unified format" "Green"
            Remove-Item $tempJson -ErrorAction SilentlyContinue
            return $true
        } else {
            Write-ColorOutput "Warning: Could not convert to YAML format, creating manual YAML" "Yellow"
            # Fallback: create YAML manually
            $yamlLines = @("# Unified MCP Configuration", "# Migrated from legacy configs", "", "servers:")
            foreach ($server in $servers) {
                $yamlLines += "  - name: $($server.name)"
                if ($server.command) { $yamlLines += "    command: $($server.command)" }
                if ($server.args) {
                    $argsStr = ($server.args | ForEach-Object { "`"$_`"" }) -join ", "
                    $yamlLines += "    args: [$argsStr]"
                }
                if ($server.repository) { $yamlLines += "    repository: $($server.repository)" }
                if ($server.buildCommands) {
                    $yamlLines += "    buildCommands:"
                    foreach ($cmd in $server.buildCommands) {
                        $yamlLines += "      - $cmd"
                    }
                }
                if ($server.env) {
                    $yamlLines += "    env:"
                    foreach ($key in $server.env.PSObject.Properties.Name) {
                        $envValue = $server.env.$key
                        $yamlLines += "      ${key}: `"$envValue`""
                    }
                }
                $yamlLines += "    enabled: true"
                $yamlLines += ""
            }
            $yamlLines -join "`n" | Set-Content $unifiedPath -Encoding UTF8
            Remove-Item $tempJson -ErrorAction SilentlyContinue
            return $true
        }
    } catch {
        Write-ColorOutput "Error during migration: $_" "Red"
        return $false
    }
}

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
                        # Normalize paths before adding
                        $normalizedConfig = Normalize-MCPPaths -McpServerConfig $newContent.mcpServers.$serverName
                        $mergedServers[$serverName] = $normalizedConfig
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

# Step 8: Set up Cursor configuration
Write-ColorOutput "Step 8: Setting up Cursor configuration..." "Cyan"
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
        # Try to migrate legacy configs first
        Migrate-LegacyMCPConfig -CloneDirectory $CloneDirectory | Out-Null
        
        # Unified MCP config location
        $unifiedMcpConfigPath = "$CloneDirectory\mcps-config.yaml"
        $legacyMcpConfigPath = "$CloneDirectory\cursor-mcp-config.json"
        
        # Determine which config to use
        $useUnifiedConfig = Test-Path $unifiedMcpConfigPath
        $useLegacyConfig = Test-Path $legacyMcpConfigPath
        
        if (-not $useUnifiedConfig -and -not $useLegacyConfig) {
            Write-ColorOutput "No MCP configuration found, skipping MCP setup" "Yellow"
        } else {
            Write-ColorOutput "Configuring MCP servers..." "Yellow"
            
            # Configure Cursor MCP (JSON format)
            $cursorMcpConfigDir = "$env:USERPROFILE\.cursor"
            $cursorMcpConfigPath = "$cursorMcpConfigDir\mcp.json"
            
            # Ensure .cursor directory exists
            if (-not (Test-Path $cursorMcpConfigDir)) {
                New-Item -ItemType Directory -Path $cursorMcpConfigDir -Force | Out-Null
                Write-ColorOutput "Created .cursor directory at: $cursorMcpConfigDir" "Gray"
            }
            
            if (Test-Path $cursorMcpConfigPath) {
                Write-ColorOutput "Found existing Cursor MCP config at: $cursorMcpConfigPath" "Gray"
            }
            
            if ($useUnifiedConfig) {
                # Use unified config - convert to Cursor JSON
                try {
                    $cursorJsonConfig = Convert-MCPToCursorJson -YamlConfigPath $unifiedMcpConfigPath
                    if ($null -ne $cursorJsonConfig) {
                        # Create temporary JSON file for merging
                        $tempJsonPath = "$env:TEMP\cursor-mcp-temp.json"
                        $cursorJsonConfig | ConvertTo-Json -Depth 10 | Set-Content $tempJsonPath -Encoding UTF8
                        Merge-MCPConfig -ExistingConfigPath $cursorMcpConfigPath -NewConfigPath $tempJsonPath
                        Remove-Item $tempJsonPath -ErrorAction SilentlyContinue
                    }
                } catch {
                    Write-ColorOutput "Warning: Could not convert unified config to Cursor JSON: $_" "Yellow"
                }
            } elseif ($useLegacyConfig) {
                # Fall back to legacy JSON config
                try {
                    Merge-MCPConfig -ExistingConfigPath $cursorMcpConfigPath -NewConfigPath $legacyMcpConfigPath
                } catch {
                    Write-ColorOutput "Warning: Could not merge legacy MCP configuration: $_" "Yellow"
                }
            }
            
            # Configure Codex MCP (TOML format)
            $codexConfigDir = "$env:USERPROFILE\.codex"
            $codexConfigPath = "$codexConfigDir\config.toml"
            
            # Ensure .codex directory exists
            if (-not (Test-Path $codexConfigDir)) {
                New-Item -ItemType Directory -Path $codexConfigDir -Force | Out-Null
                Write-ColorOutput "Created .codex directory at: $codexConfigDir" "Gray"
            }
            
            if (Test-Path $codexConfigPath) {
                Write-ColorOutput "Found existing Codex config at: $codexConfigPath" "Gray"
            }
            
            if ($useUnifiedConfig) {
                # Use unified config - convert to Codex TOML
                try {
                    $codexTomlContent = Convert-MCPToCodexToml -YamlConfigPath $unifiedMcpConfigPath
                    if ($null -ne $codexTomlContent) {
                        Merge-CodexTomlConfig -ExistingConfigPath $codexConfigPath -NewTomlContent $codexTomlContent
                    }
                } catch {
                    Write-ColorOutput "Warning: Could not convert unified config to Codex TOML: $_" "Yellow"
                }
            }
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

# Step 9: Install MCP dependencies (if needed)
Write-ColorOutput "Step 9: Checking for nvm and Node.js..." "Cyan"
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

# Step 10: Install uv and Python 3.11
Write-ColorOutput "Step 10: Installing uv and Python 3.11..." "Cyan"
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

# Step 11: Final setup instructions
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

# Wait for user input unless -NoWait flag is set
if (-not $NoWait) {
    Write-Host ""
    Write-ColorOutput "Press Enter to exit..." "Gray"
    $null = Read-Host
}

