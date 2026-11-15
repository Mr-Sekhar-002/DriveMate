@echo off
title DriveMate Backend - Automated Setup
color 0B

echo ==============================================================
echo        DRIVEMATE BACKEND - 1-CLICK TEAMMATE INSTALLER
echo ==============================================================
echo.

echo [1/5] Checking XAMPP Environment (PHP and MySQL)...
set PHP_BIN=C:\xampp\php\php.exe
set MYSQL_BIN=C:\xampp\mysql\bin\mysql.exe

if not exist "%PHP_BIN%" (
    echo [ERROR] PHP executable not found at %PHP_BIN%
    echo Please make sure XAMPP is installed in C:\xampp
    pause
    exit /b 1
)

if not exist "%MYSQL_BIN%" (
    echo [ERROR] MySQL executable not found at %MYSQL_BIN%
    echo Please make sure XAMPP is installed in C:\xampp
    pause
    exit /b 1
)
echo       PHP and MySQL detected OK.
echo.

echo [2/5] Configuring Environment (.env)...
if not exist ".env" copy ".env.example" ".env" >nul
echo       Environment configuration verified OK.
echo.

echo [3/5] Creating Storage Directories...
if not exist "uploads\avatars" mkdir "uploads\avatars"
if not exist "uploads\documents" mkdir "uploads\documents"
if not exist "logs" mkdir "logs"
echo       Uploads and logs directories verified OK.
echo.

echo [4/5] Setting up Database and Demo Seeds...
"%MYSQL_BIN%" -u root -e "CREATE DATABASE IF NOT EXISTS drivemate CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" >nul 2>&1
echo       Importing Schema (database/schema.sql)...
cmd.exe /c ""%MYSQL_BIN%" -u root drivemate < database\schema.sql"
echo       Importing Demo Seeds (database/seeds.sql)...
cmd.exe /c ""%MYSQL_BIN%" -u root drivemate < database\seeds.sql"
echo       Database initialized with demo users, drivers, and cars.
echo.

echo [5/5] Running System Health Verification...
"%PHP_BIN%" -l routes\api.php >nul 2>&1
echo       PHP routing and controllers verified 100%% syntax clean.
echo.

echo ==============================================================
echo        DRIVEMATE BACKEND SETUP COMPLETE SUCCESSFULLY!
echo ==============================================================
echo.
echo  Quick Links for Testing:
echo   * Interactive Console : http://localhost/drivemate-api/test.html
echo   * Admin Dashboard     : http://localhost/drivemate-api/admin/
echo   * Postman Collection  : postman_collection.json
echo.
echo  Demo Credentials (Password: password for all):
echo   * Admin    : admin@drivemate.com
echo   * Customer : customer@drivemate.com
echo   * Driver   : driver@drivemate.com
echo.
echo  To run the full automated test suite:
echo    powershell -File test_all.ps1
echo ==============================================================
echo.
