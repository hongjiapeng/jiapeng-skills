@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%Link-Skills.ps1"

if not exist "%PS_SCRIPT%" (
    echo Link-Skills.ps1 was not found next to this command file.
    echo Expected: "%PS_SCRIPT%"
    echo.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %*
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if "%EXIT_CODE%"=="0" (
    echo Done. You can close this window.
) else (
    echo Link-Skills.ps1 failed with exit code %EXIT_CODE%.
)
pause
exit /b %EXIT_CODE%
