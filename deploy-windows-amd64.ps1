#Requires -Version 5.1

###############################################################################
# MCSManager Windows AMD64 Auto Deployment Script
# Repository: https://github.com/Kx501/MCSManager
###############################################################################

$ErrorActionPreference = "Stop"

# Configuration variables
$REPO_URL = "https://github.com/Kx501/MCSManager.git"
$BUILD_DIR = "C:\mcsmanager-source"
$DEPLOY_DIR = "C:\mcsmanager"

# Color output functions
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Check if command exists
function Test-Command {
    param([string]$Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    if (-not $?) {
        Write-ErrorMsg "$Command is not installed. Please install $Command first."
        exit 1
    }
}

# Check Node.js version
function Test-NodeJS {
    try {
        $nodeVersion = (node -v).Substring(1)
        Write-Info "Detected Node.js version: $nodeVersion"
        
        $requiredVersion = [Version]"16.20.2"
        $currentVersion = [Version]$nodeVersion
        
        if ($currentVersion -lt $requiredVersion) {
            Write-ErrorMsg "Node.js version is too low. Requires 16.20.2 or higher."
            Write-Info "Download: https://nodejs.org/"
            exit 1
        }
    }
    catch {
        Write-ErrorMsg "Node.js is not installed."
        Write-Info "Please install Node.js 16.20.2 or higher (recommended 20.x LTS)."
        Write-Info "Download: https://nodejs.org/"
        exit 1
    }
}

# Download file function
function Download-File {
    param(
        [string]$Url,
        [string]$OutputPath,
        [bool]$Required = $true
    )
    
    try {
        Write-Info "Downloading: $Url"
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing
        Write-Info "Download completed: $OutputPath"
    }
    catch {
        if ($Required) {
            Write-ErrorMsg "Download failed: $Url"
            exit 1
        }
        else {
            Write-Warn "Download failed (optional): $Url"
        }
    }
}

# Main function
function Main {
    Write-Info "=========================================="
    Write-Info "MCSManager Windows AMD64 Auto Deployment Script"
    Write-Info "=========================================="
    Write-Host ""
    
    # Check required commands
    Write-Info "Checking required tools..."
    Test-Command "git"
    Test-Command "node"
    Test-NodeJS
    Write-Host ""
    
    # Step 1: Clone repository
    Write-Info "Step 1/6: Cloning repository..."
    if (-not (Test-Path $BUILD_DIR)) {
        New-Item -ItemType Directory -Path $BUILD_DIR -Force | Out-Null
    }
    Set-Location $BUILD_DIR
    
    if (-not (Test-Path "MCSManager")) {
        Write-Info "Cloning repository..."
        git clone $REPO_URL
    }
    else {
        Write-Info "Repository exists, updating..."
        Set-Location "MCSManager"
        git pull
        Set-Location ..
    }
    Set-Location "MCSManager"
    Write-Info "Repository location: $(Get-Location)"
    Write-Host ""
    
    # Step 2: Install npm dependencies
    Write-Info "Step 2/6: Installing npm dependencies..."
    if (Test-Path "install-dependents.bat") {
        & .\install-dependents.bat
    }
    elseif (Test-Path "install-dependents.sh") {
        Write-Info "Installing dependencies directly with npm..."
        Set-Location "daemon"
        npm install --no-fund --no-audit
        Set-Location "..\panel"
        npm install --no-fund --no-audit
        Set-Location "..\frontend"
        npm install --no-fund --no-audit
        Set-Location ".."
    }
    else {
        Write-Info "Installing dependencies directly with npm..."
        Set-Location "daemon"
        npm install --no-fund --no-audit
        Set-Location "..\panel"
        npm install --no-fund --no-audit
        Set-Location "..\frontend"
        npm install --no-fund --no-audit
        Set-Location ".."
    }
    Write-Info "npm dependencies installation completed"
    Write-Host ""
    
    # Step 3: Download binary dependencies
    Write-Info "Step 3/6: Downloading Windows AMD64 binary dependencies..."
    $libDir = "daemon\lib"
    if (-not (Test-Path $libDir)) {
        New-Item -ItemType Directory -Path $libDir -Force | Out-Null
    }
    Set-Location $libDir
    
    Download-File -Url "https://github.com/MCSManager/Zip-Tools/releases/latest/download/file_zip_windows_x64.exe" -OutputPath "file_zip_windows_x64.exe"
    Download-File -Url "https://github.com/MCSManager/Zip-Tools/releases/latest/download/7z_windows_x64.exe" -OutputPath "7z_windows_x64.exe"
    Download-File -Url "https://github.com/MCSManager/Zip-Tools/releases/latest/download/7z-extra-license.txt" -OutputPath "7z-extra-license.txt" -Required $false
    Download-File -Url "https://github.com/MCSManager/Zip-Tools/releases/latest/download/7z-unix-license.txt" -OutputPath "7z-unix-license.txt" -Required $false
    Download-File -Url "https://github.com/MCSManager/PTY/releases/download/latest/pty_windows_x64.exe" -OutputPath "pty_windows_x64.exe"
    
    Set-Location "..\.."
    Write-Info "Binary dependencies download completed"
    Write-Host ""
    
    # Step 4: Build production version
    Write-Info "Step 4/6: Building production version..."
    Write-Warn "This may take a few minutes, please wait..."
    if (Test-Path "build.bat") {
        & .\build.bat
    }
    else {
        Write-ErrorMsg "build.bat file not found"
        exit 1
    }
    
    if (-not (Test-Path "production-code")) {
        Write-ErrorMsg "Build failed, production-code directory does not exist"
        exit 1
    }
    Write-Info "Build completed!"
    Write-Host ""
    
    # Step 5: Deploy to production directory
    Write-Info "Step 5/6: Deploying to production directory..."
    Write-Info "Deployment directory: $DEPLOY_DIR"
    
    # If directory exists, ask if backup is needed
    if (Test-Path $DEPLOY_DIR) {
        $backupDir = "${DEPLOY_DIR}_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        $response = Read-Host "Deployment directory exists. Backup existing deployment? (y/n)"
        if ($response -match "^[Yy]$") {
            Write-Info "Backing up to: $backupDir"
            try {
                Copy-Item -Path $DEPLOY_DIR -Destination $backupDir -Recurse -Force
                Write-Info "Backup completed"
            }
            catch {
                Write-ErrorMsg "Backup failed: $_"
                exit 1
            }
        }
    }
    
    # Create deployment directory
    if (-not (Test-Path $DEPLOY_DIR)) {
        New-Item -ItemType Directory -Path $DEPLOY_DIR -Force | Out-Null
    }
    
    # Copy build artifacts
    Write-Info "Copying build artifacts..."
    Copy-Item -Path "production-code\*" -Destination $DEPLOY_DIR -Recurse -Force
    
    # Copy startup scripts
    Write-Info "Copying startup scripts..."
    if (Test-Path "prod-scripts\windows") {
        Copy-Item -Path "prod-scripts\windows\*" -Destination $DEPLOY_DIR -Recurse -Force
    }
    
    # Copy binary dependencies
    Write-Info "Copying binary dependencies..."
    $targetLibDir = "$DEPLOY_DIR\daemon\lib"
    if (-not (Test-Path $targetLibDir)) {
        New-Item -ItemType Directory -Path $targetLibDir -Force | Out-Null
    }
    if (Test-Path "daemon\lib") {
        Copy-Item -Path "daemon\lib\*" -Destination $targetLibDir -Force -ErrorAction SilentlyContinue
    }
    
    Write-Info "Deployment files copy completed"
    Write-Host ""
    
    # Step 6: Install production dependencies
    Write-Info "Step 6/6: Installing production dependencies..."
    Set-Location $DEPLOY_DIR
    
    if (Test-Path "daemon") {
        Set-Location "daemon"
        npm install --production --no-fund --no-audit
        Set-Location ".."
    }
    
    if (Test-Path "web") {
        Set-Location "web"
        npm install --production --no-fund --no-audit
        Set-Location ".."
    }
    
    Write-Info "Production dependencies installation completed"
    Write-Host ""
    
    # Completion
    Write-Info "=========================================="
    Write-Info "Deployment completed!"
    Write-Info "=========================================="
    Write-Host ""
    Write-Info "Deployment directory: $DEPLOY_DIR"
    Write-Host ""
    Write-Info "Ways to start the service:"
    Write-Host "  Method 1 - Use startup script (recommended):"
    Write-Host "    cd $DEPLOY_DIR"
    Write-Host "    .\start.bat"
    Write-Host ""
    Write-Host "  Method 2 - Start two services manually:"
    Write-Host "    Open two PowerShell or CMD windows"
    Write-Host "    Window 1: cd $DEPLOY_DIR\daemon && node_app.exe --enable-source-maps --max-old-space-size=8192 app.js"
    Write-Host "    Window 2: cd $DEPLOY_DIR\web && node_app.exe --enable-source-maps --max-old-space-size=8192 app.js --open"
    Write-Host ""
    Write-Host "  Method 3 - Use Windows Service (requires administrator privileges):"
    Write-Host "    You can use NSSM (Non-Sucking Service Manager) to install as Windows service"
    Write-Host "    Download: https://nssm.cc/download"
    Write-Host ""
    Write-Info "Access panel: http://localhost:23333"
    Write-Info "Default daemon port: 24444"
    Write-Host ""
}

# Execute main function
Main
