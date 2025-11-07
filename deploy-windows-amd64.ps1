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
    
    # Step 1: Check repository
    Write-Info "Step 1/6: Checking repository..."
    $currentDir = Get-Location
    $isMCSManagerRepo = $false
    $repoPath = $null
    
    # Check if current directory is MCSManager repository
    if ((Test-Path ".git") -and (Test-Path "package.json") -and (Test-Path "daemon") -and (Test-Path "panel") -and (Test-Path "frontend")) {
        Write-Info "Detected MCSManager repository in current directory: $currentDir"
        $isMCSManagerRepo = $true
        $repoPath = $currentDir
    }
    # Check if MCSManager subdirectory exists in current directory
    elseif (Test-Path "MCSManager\.git") {
        Write-Info "Detected MCSManager repository in subdirectory: $currentDir\MCSManager"
        $isMCSManagerRepo = $true
        $repoPath = Join-Path $currentDir "MCSManager"
    }
    # Check if BUILD_DIR\MCSManager exists
    elseif (Test-Path "$BUILD_DIR\MCSManager\.git") {
        Write-Info "Detected MCSManager repository in: $BUILD_DIR\MCSManager"
        $isMCSManagerRepo = $true
        $repoPath = Join-Path $BUILD_DIR "MCSManager"
    }
    
    if ($isMCSManagerRepo) {
        # Use existing repository
        Set-Location $repoPath
        Write-Info "Updating existing repository..."
        git pull
        Write-Info "Repository location: $(Get-Location)"
    }
    else {
        # Clone new repository
        Write-Info "MCSManager repository not found. Cloning repository..."
        if (-not (Test-Path $BUILD_DIR)) {
            New-Item -ItemType Directory -Path $BUILD_DIR -Force | Out-Null
        }
        Set-Location $BUILD_DIR
        
        if (-not (Test-Path "MCSManager")) {
            Write-Info "Cloning repository to: $BUILD_DIR\MCSManager"
            git clone $REPO_URL
        }
        else {
            Write-Info "Directory exists, updating..."
            Set-Location "MCSManager"
            git pull
            Set-Location ..
        }
        Set-Location "MCSManager"
        Write-Info "Repository location: $(Get-Location)"
    }
    
    # Store repository root path for later use
    $REPO_ROOT = Get-Location
    Write-Host ""
    
    # Step 2: Install npm dependencies
    Write-Info "Step 2/6: Installing npm dependencies..."
    Set-Location $REPO_ROOT
    if (Test-Path "install-dependents.bat") {
        & .\install-dependents.bat
    }
    elseif (Test-Path "install-dependents.sh") {
        Write-Info "Installing dependencies directly with npm..."
        Set-Location "$REPO_ROOT\daemon"
        npm install --no-fund --no-audit
        Set-Location "$REPO_ROOT\panel"
        npm install --no-fund --no-audit
        Set-Location "$REPO_ROOT\frontend"
        npm install --no-fund --no-audit
        Set-Location $REPO_ROOT
    }
    else {
        Write-Info "Installing dependencies directly with npm..."
        Set-Location "$REPO_ROOT\daemon"
        npm install --no-fund --no-audit
        Set-Location "$REPO_ROOT\panel"
        npm install --no-fund --no-audit
        Set-Location "$REPO_ROOT\frontend"
        npm install --no-fund --no-audit
        Set-Location $REPO_ROOT
    }
    Write-Info "npm dependencies installation completed"
    Write-Host ""
    
    # Step 3: Download binary dependencies (if not already downloaded)
    Write-Info "Step 3/6: Checking Windows AMD64 binary dependencies..."
    Set-Location $REPO_ROOT
    $libDir = "$REPO_ROOT\daemon\lib"
    if (-not (Test-Path $libDir)) {
        New-Item -ItemType Directory -Path $libDir -Force | Out-Null
    }
    
    $filesToCheck = @(
        @{Name = "file_zip_win32_x64.exe"; Url = "https://github.com/MCSManager/Zip-Tools/releases/download/latest/file_zip_win32_x64.exe" },
        @{Name = "7z_win32_x64.exe"; Url = "https://github.com/MCSManager/Zip-Tools/releases/download/latest/7z_win32_x64.exe" },
        @{Name = "pty_win32_x64.exe"; Url = "https://github.com/MCSManager/PTY/releases/download/latest/pty_win32_x64.exe" }
    )
    
    $downloadCount = 0
    foreach ($file in $filesToCheck) {
        $filePath = Join-Path $libDir $file.Name
        if (-not (Test-Path $filePath)) {
            if ($downloadCount -eq 0) {
                Write-Info "Downloading missing binary dependencies..."
            }
            Set-Location $libDir
            Download-File -Url $file.Url -OutputPath $file.Name
            $downloadCount++
        }
        else {
            Write-Info "Binary dependency already exists: $($file.Name)"
        }
    }
    
    if ($downloadCount -eq 0) {
        Write-Info "All binary dependencies are already present"
    }
    else {
        Write-Info "Binary dependencies download completed"
    }
    
    Set-Location $REPO_ROOT
    Write-Host ""
    
    # Step 4: Build production version
    Write-Info "Step 4/6: Building production version..."
    Set-Location $REPO_ROOT
    Write-Warn "This may take a few minutes, please wait..."
    if (Test-Path "$REPO_ROOT\build.bat") {
        & "$REPO_ROOT\build.bat"
    }
    else {
        Write-ErrorMsg "build.bat file not found at: $REPO_ROOT\build.bat"
        exit 1
    }
    
    if (-not (Test-Path "$REPO_ROOT\production-code")) {
        Write-ErrorMsg "Build failed, production-code directory does not exist at: $REPO_ROOT\production-code"
        exit 1
    }
    Write-Info "Build completed!"
    Write-Host ""
    
    # Step 5: Deploy to production directory
    Write-Info "Step 5/6: Deploying to production directory..."
    Write-Info "Deployment directory: $DEPLOY_DIR"
    
    # Ensure we're in repository root
    Set-Location $REPO_ROOT
    
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
    Copy-Item -Path "$REPO_ROOT\production-code\*" -Destination $DEPLOY_DIR -Recurse -Force
    
    # Copy startup scripts
    Write-Info "Copying startup scripts..."
    if (Test-Path "$REPO_ROOT\prod-scripts\windows") {
        Copy-Item -Path "$REPO_ROOT\prod-scripts\windows\*" -Destination $DEPLOY_DIR -Recurse -Force
    }
    
    # Copy binary dependencies
    Write-Info "Copying binary dependencies..."
    $targetLibDir = "$DEPLOY_DIR\daemon\lib"
    if (-not (Test-Path $targetLibDir)) {
        New-Item -ItemType Directory -Path $targetLibDir -Force | Out-Null
    }
    if (Test-Path "$REPO_ROOT\daemon\lib") {
        Copy-Item -Path "$REPO_ROOT\daemon\lib\*" -Destination $targetLibDir -Force -ErrorAction SilentlyContinue
    }
    
    # Download and copy node_app.exe
    Write-Info "Downloading node_app.exe..."
    $nodeExeUrl = "https://nodejs.org/download/release/latest-v20.x/win-x64/node.exe"
    $tempNodeExe = "$env:TEMP\node_app.exe"
    
    try {
        Download-File -Url $nodeExeUrl -OutputPath $tempNodeExe
        Write-Info "Copying node_app.exe to daemon and web directories..."
        Copy-Item -Path $tempNodeExe -Destination "$DEPLOY_DIR\daemon\node_app.exe" -Force
        Copy-Item -Path $tempNodeExe -Destination "$DEPLOY_DIR\web\node_app.exe" -Force
        Remove-Item -Path $tempNodeExe -Force -ErrorAction SilentlyContinue
        Write-Info "node_app.exe copied successfully"
    }
    catch {
        Write-Warn "Failed to download node_app.exe: $_"
        Write-Warn "You may need to manually copy node.exe to $DEPLOY_DIR\daemon\node_app.exe and $DEPLOY_DIR\web\node_app.exe"
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
