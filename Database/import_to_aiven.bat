@echo off
title DriveMate - Import Database to Aiven Cloud MySQL
cd /d "%~dp0"

echo ========================================================
echo DriveMate: Import SQL Schema to Aiven Cloud MySQL
echo ========================================================
echo.

set MYSQL_BIN=C:\xampp\mysql\bin\mysql.exe

if not exist "%MYSQL_BIN%" (
    echo [ERROR] MySQL CLI not found at %MYSQL_BIN%
    pause
    exit /b 1
)

echo Please enter your Aiven MySQL connection details
echo (Found in your Aiven Service Overview tab):
echo.

set /p AIVEN_HOST="Host (e.g. mysql-xxxx.aivencloud.com): "
set /p AIVEN_PORT="Port (e.g. 12345): "
set /p AIVEN_USER="User (default: avnadmin): "
if "%AIVEN_USER%"=="" set AIVEN_USER=avnadmin

set /p AIVEN_DB="Database name (default: defaultdb): "
if "%AIVEN_DB%"=="" set AIVEN_DB=defaultdb

set /p AIVEN_PASS="Password: "

echo.
echo Connecting to Aiven and importing drivemate_database.sql...
echo Please wait...
echo.

"%MYSQL_BIN%" -h %AIVEN_HOST% -P %AIVEN_PORT% -u %AIVEN_USER% -p%AIVEN_PASS% --ssl-mode=REQUIRED %AIVEN_DB% < "%~dp0drivemate_database.sql"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================================
    echo [SUCCESS] Database imported successfully into Aiven!
    echo All tables (users, vehicles, drivers, bookings, wallets) are ready!
    echo ========================================================
) else (
    echo.
    echo ========================================================
    echo [ERROR] Failed to import database. Check host, port, credentials.
    echo ========================================================
)

pause
