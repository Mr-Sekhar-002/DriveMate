@echo off
title DriveMate - Push to GitHub
cd /d "%~dp0"
echo ========================================================
echo Pushing DriveMate to https://github.com/Mr-Sekhar-002/DriveMate.git
echo ========================================================
echo.

set GIT_EXE=C:\Users\s1788\Downloads\flutter_windows_3.47.6-stable\flutter\bin\mingit\cmd\git.exe

echo Current Git Status:
"%GIT_EXE%" status
echo.

echo Attempting push to origin main...
echo (If prompted, sign in via your browser or paste your GitHub Personal Access Token)
echo.

"%GIT_EXE%" push -u origin main

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================================
    echo [SUCCESS] Project successfully pushed to GitHub!
    echo URL: https://github.com/Mr-Sekhar-002/DriveMate
    echo ========================================================
) else (
    echo.
    echo ========================================================
    echo [FAILED] Push encountered an authentication error.
    echo To push using a Personal Access Token:
    echo "%GIT_EXE%" push https://<YOUR_GITHUB_TOKEN>@github.com/Mr-Sekhar-002/DriveMate.git main
    echo ========================================================
)

pause
