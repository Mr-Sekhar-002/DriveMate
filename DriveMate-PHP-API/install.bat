@echo off
title DriveMate - Install Packages
color 0A

echo ============================================
echo   Installing PHP Packages...
echo ============================================
echo.

cd /d C:\xampp\htdocs\drivemate-api

"C:\xampp\php\php.exe" composer.phar update --no-audit --ignore-platform-reqs

echo.
echo ============================================
IF ERRORLEVEL 1 (
    echo   FAILED - See error above
) ELSE (
    echo   SUCCESS! Packages installed.
    echo.
    echo   Now:
    echo   1. Open XAMPP - Start Apache + MySQL
    echo   2. Go to http://localhost/phpmyadmin
    echo   3. Create DB: drivemate
    echo   4. Import: database\schema.sql
    echo   5. Open: http://localhost/drivemate-api/auth/register
)
echo ============================================
echo.
pause
