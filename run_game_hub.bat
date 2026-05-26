@echo off
title Game Hub Server Launcher
echo ==================================================
echo         GAME HUB SERVER LAUNCHER
echo ==================================================
echo.

:: Check if Node.js is installed
where node >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Node.js is not installed or not in your PATH!
    echo Please install Node.js from https://nodejs.org/ to run the server.
    echo.
    pause
    exit /b
)

echo Starting local web server...
:: Automatically launch your browser at http://localhost:8000
start "" "http://localhost:8000"

:: Launch Node.js server
node server.js

pause
