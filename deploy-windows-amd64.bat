@echo off
REM MCSManager Windows AMD64 Auto Deployment Script Launcher
REM This script will launch the PowerShell deployment script

echo ==========================================
echo MCSManager Windows AMD64 Auto Deployment Script
echo ==========================================
echo.

REM Check if PowerShell is available
powershell -Command "exit 0" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] PowerShell is not available. Please ensure PowerShell 5.1 or higher is installed.
    pause
    exit /b 1
)

REM Check script execution policy
powershell -Command "Get-ExecutionPolicy" | findstr /i "Restricted" >nul
if errorlevel 1 (
    REM Execution policy allows, run directly
    powershell -ExecutionPolicy Bypass -File "%~dp0deploy-windows-amd64.ps1"
) else (
    echo [WARN] PowerShell execution policy is restricted
    echo Attempting to run with bypass policy...
    powershell -ExecutionPolicy Bypass -File "%~dp0deploy-windows-amd64.ps1"
)

if errorlevel 1 (
    echo.
    echo [ERROR] Deployment script execution failed
    pause
    exit /b 1
)

pause
