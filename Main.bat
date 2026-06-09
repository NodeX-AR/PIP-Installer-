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

:: Step 2: If pip not found, scan for all Python versions
if "%PIP_FOUND%"=="false" (
    echo.
    echo Step 2: Scanning entire computer for Python installations...
    
    :: Scan common Python installation locations
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
    
    :: Check WindowsApps (if accessible)
    for /d %%i in ("%LOCALAPPDATA%\Microsoft\WindowsApps\Python*") do (
        if exist "%%i\python.exe" (
            set /a COUNT+=1
            set PYTHON_!COUNT!=%%i
            echo Found Python: %%i
        )
    )
    
    :: Additional scan using where command (slower but thorough)
    echo Scanning using where command (this may take a moment)...
    for /f "delims=" %%i in ('where /r C:\ python.exe 2^>nul') do (
        set "PYTHON_PATH=%%i"
        set "PYTHON_DIR=!PYTHON_PATH:\python.exe=!"
        if not defined PYTHON_INST_!PYTHON_DIR! (
            set PYTHON_INST_!PYTHON_DIR!=true
            set /a COUNT+=1
            set PYTHON_!COUNT!=!PYTHON_DIR!
            echo Found Python: !PYTHON_DIR!
        )
    )
    
    echo.
    echo Total Python installations found: !COUNT!
    
    :: Step 3: Delete all if more than one Python version
    if !COUNT! gtr 1 (
        echo.
        echo Step 3: More than one Python version found. Deleting all...
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
    
    :: Step 4: Install new Python version
    echo.
    echo Step 4: Installing latest Python version...
    
    :: Download latest Python installer
    set PYTHON_INSTALLER=python_installer.exe
    set PYTHON_VERSION=3.12.4
    
    echo Downloading Python %PYTHON_VERSION%...
    powershell -Command "Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/%PYTHON_VERSION%/python-%PYTHON_VERSION%-amd64.exe' -OutFile '%TEMP%\%PYTHON_INSTALLER%'"
    
    if not exist "%TEMP%\%PYTHON_INSTALLER%" (
        echo Failed to download Python installer. Please check your internet connection.
        pause
        exit /b 1
    )
    
    echo Installing Python (silent installation)...
    "%TEMP%\%PYTHON_INSTALLER%" /quiet InstallAllUsers=1 PrependPath=1 Include_test=0
    
    :: Wait for installation to complete
    timeout /t 10 /nobreak >nul
    
    echo Cleaning up installer...
    del "%TEMP%\%PYTHON_INSTALLER%" 2>nul
    
    :: Refresh environment variables
    call :refresh_env
    
    echo Python installation completed.
    
    :: Step 5: Set pip for the new Python
    echo.
    echo Step 5: Configuring pip for new Python...
    
    :: Find newly installed Python
    for /f "delims=" %%i in ('where python 2^>nul') do (
        set "NEW_PYTHON=%%i"
        goto :found_python
    )
    
    :found_python
    if defined NEW_PYTHON (
        echo Installing/upgrading pip...
        "!NEW_PYTHON!" -m ensurepip --upgrade
        "!NEW_PYTHON!" -m pip install --upgrade pip
        
        :: Add pip to PATH
        for %%i in ("!NEW_PYTHON!") do set "PYTHON_DIR=%%~dpi"
        set "SCRIPTS_DIR=!PYTHON_DIR!Scripts"
        
        :: Add to system PATH
        setx /M PATH "!SCRIPTS_DIR!;%PATH%" >nul
        echo Added pip to system PATH
        
        echo [OK] Pip has been configured for the new Python installation
    ) else (
        echo [ERROR] Could not find newly installed Python
    )
    
) else (
    :: If pip is already set but only one Python exists
    echo.
    echo Step 2: Checking Python installations...
    
    :: Count Python installations
    set PYTHON_COUNT=0
    where python >nul 2>&1
    if !errorlevel! equ 0 set PYTHON_COUNT=1
    
    :: Additional scan for multiple installations
    for /f "delims=" %%i in ('where /r C:\ python.exe 2^>nul') do (
        set /a PYTHON_COUNT+=1
    )
    
    if !PYTHON_COUNT! equ 1 (
        echo Single Python installation detected.
        echo Step 3: Ensuring pip is properly configured...
        
        :: Get Python path
        for /f "delims=" %%i in ('where python 2^>nul') do (
            set "CURRENT_PYTHON=%%i"
            goto :single_found
        )
        
        :single_found
        echo Installing/upgrading pip...
        "!CURRENT_PYTHON!" -m ensurepip --upgrade
        "!CURRENT_PYTHON!" -m pip install --upgrade pip
        
        echo [OK] Pip has been updated and configured
    )
)

:: Final verification
echo.
echo ========================================
echo Verification:
call :check_pip

:: Display pip version
if "%PIP_FOUND%"=="true" (
    echo.
    echo Pip version information:
    pip --version
) else (
    echo.
    echo [WARNING] Pip may not be fully configured.
    echo Please restart your computer or manually add Python/Scripts to PATH
)

echo.
echo ========================================
echo Setup completed!
pause
exit /b 0

:refresh_env
:: Refresh environment variables without restarting
for /f "tokens=1,* delims==" %%a in ('set') do (
    if /i "%%a"=="PATH" set "CURRENT_PATH=%%b"
)
set "PATH=%CURRENT_PATH%"
goto :eof
