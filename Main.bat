@echo off
setlocal enabledelayedexpansion

echo ========================================
echo Python and PIP Setup Tool
echo ========================================
echo.

:: Check if running as administrator (required for system-wide changes)
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script requires Administrator privileges.
    echo Please right-click and select "Run as Administrator"
    pause
    exit /b 1
)

:: Function to check if pip is accessible
:check_pip
where pip >nul 2>&1
if %errorLevel% equ 0 (
    echo [OK] Pip is already accessible
    set PIP_FOUND=true
    goto :eof
) else (
    echo [WARNING] Pip not found in PATH
    set PIP_FOUND=false
    goto :eof
)

:: Step 1: Check if pip is already set
echo Step 1: Checking current pip availability...
call :check_pip

:: If pip is already found and working, skip to verification
if "%PIP_FOUND%"=="true" (
    echo Pip is already configured. Verifying installation...
    goto :verify
)

:: Step 2: Scan for all Python versions in standard locations
echo.
echo Step 2: Scanning common Python installation locations...

set PYTHON_INSTALLATIONS=
set COUNT=0

:: Check Program Files
for /d %%i in ("C:\Program Files\Python*") do (
    if exist "%%i\python.exe" (
        set /a COUNT+=1
        set PYTHON_!COUNT!=%%i
        echo Found Python: %%i
    )
)

:: Check Program Files (x86)
for /d %%i in ("C:\Program Files (x86)\Python*") do (
    if exist "%%i\python.exe" (
        set /a COUNT+=1
        set PYTHON_!COUNT!=%%i
        echo Found Python: %%i
    )
)

:: Check LocalAppData
for /d %%i in ("%LOCALAPPDATA%\Programs\Python\Python*") do (
    if exist "%%i\python.exe" (
        set /a COUNT+=1
        set PYTHON_!COUNT!=%%i
        echo Found Python: %%i
    )
)

echo.
echo Total Python installations found: !COUNT!

:: Step 3: Handle multiple installations
if !COUNT! gtr 1 (
    echo.
    echo Step 3: Multiple Python versions found. Deleting all...
    for /l %%i in (1,1,!COUNT!) do (
        echo Deleting: !PYTHON_%%i!
        rmdir /s /q "!PYTHON_%%i!" 2>nul
        if exist "!PYTHON_%%i!\python.exe" (
            echo Failed to delete: !PYTHON_%%i! (might be in use)
        ) else (
            echo Successfully deleted: !PYTHON_%%i!
        )
    )
)

:: Step 4: Install Python if needed
if !COUNT! equ 0 (
    echo.
    echo Step 4: No Python found. Installing Python 3.12.4...
    goto :install_python
) else if !COUNT! equ 1 (
    echo.
    echo Step 4: Single Python found. Fixing pip...
    
    :: Get the Python path
    for /l %%i in (1,1,!COUNT!) do (
        if defined PYTHON_!COUNT! (
            set "PYTHON_PATH=!PYTHON_%%i!\python.exe"
        )
    )
    
    goto :fix_pip
)

:install_python
set PYTHON_INSTALLER=python_installer.exe
set PYTHON_VERSION=3.12.4

echo Downloading Python %PYTHON_VERSION%...
powershell -Command "Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/%PYTHON_VERSION%/python-%PYTHON_VERSION%-amd64.exe' -OutFile '%TEMP%\%PYTHON_INSTALLER%' -ErrorAction Stop"

if not exist "%TEMP%\%PYTHON_INSTALLER%" (
    echo Failed to download Python installer. Please check your internet connection.
    pause
    exit /b 1
)

echo Installing Python (silent installation)...
"%TEMP%\%PYTHON_INSTALLER%" /quiet InstallAllUsers=1 PrependPath=1 Include_test=0

:: Wait for installation to complete
timeout /t 15 /nobreak >nul

echo Cleaning up installer...
del "%TEMP%\%PYTHON_INSTALLER%" 2>nul

echo Python installation completed.

:: Find newly installed Python
for /d %%i in ("C:\Program Files\Python*") do (
    if exist "%%i\python.exe" (
        set "PYTHON_PATH=%%i\python.exe"
        goto :fix_pip
    )
)

:fix_pip
if defined PYTHON_PATH (
    echo.
    echo Step 5: Configuring pip...
    
    :: Ensure pip is installed/upgraded
    echo Ensuring pip is installed...
    "!PYTHON_PATH!" -m ensurepip --upgrade >nul 2>&1
    
    :: Upgrade pip to latest version
    echo Upgrading pip to latest version...
    "!PYTHON_PATH!" -m pip install --upgrade pip >nul 2>&1
    
    :: Get Python directory
    for %%i in ("!PYTHON_PATH!") do set "PYTHON_DIR=%%~dpi"
    set "SCRIPTS_DIR=!PYTHON_DIR!Scripts"
    
    :: Add Scripts directory to system PATH
    echo Adding pip/Scripts directory to system PATH...
    
    :: Check if already in PATH
    for /f "tokens=2*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH 2^>nul') do (
        set "CURRENT_SYS_PATH=%%b"
    )
    
    if "!CURRENT_SYS_PATH!"=="" (
        echo Failed to read current PATH. Adding to PATH using setx...
        setx /M PATH "!SCRIPTS_DIR!"
    ) else (
        echo !CURRENT_SYS_PATH! | find /i "!SCRIPTS_DIR!" >nul
        if errorlevel 1 (
            setx /M PATH "!SCRIPTS_DIR!;!CURRENT_SYS_PATH!"
            echo Added !SCRIPTS_DIR! to system PATH
        ) else (
            echo Scripts directory already in PATH
        )
    )
    
    echo [OK] Pip has been configured
) else (
    echo [ERROR] Could not find Python installation
    pause
    exit /b 1
)

:verify
:: Final verification
echo.
echo ========================================
echo Verification:
call :check_pip

:: Display pip version and location
if "%PIP_FOUND%"=="true" (
    echo.
    echo Pip information:
    pip --version
    echo Pip location:
    where pip
) else (
    echo.
    echo [WARNING] Pip could not be found in PATH
    echo Please restart your computer for PATH changes to take effect
)

echo.
echo ========================================
echo Setup completed!
pause
exit /b 0
