@echo off
title DriveMate API - Development Server
color 0A

echo ==============================================================
echo        🚗 DRIVEMATE PORTABLE PHP DEVELOPMENT SERVER
echo ==============================================================
echo.

set PHP_BIN=C:\xampp\php\php.exe
if not exist "%PHP_BIN%" set PHP_BIN=php

echo Starting PHP built-in web server on http://localhost:8000 ...
echo Press Ctrl+C at any time to stop the server.
echo.
echo Links:
echo   * API Root   : http://localhost:8000
echo   * Test Console: http://localhost:8000/test.html
echo   * Admin Portal: http://localhost:8000/admin/
echo ==============================================================
echo.

"%PHP_BIN%" -S 0.0.0.0:8000 index.php
pause
