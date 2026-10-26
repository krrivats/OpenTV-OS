@echo off
rem OpenTV OS: double-click to run. Uses Windows PowerShell; nothing to install.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\restore.ps1"
if errorlevel 1 (echo. & echo Something went wrong. Read the message above, fix it, and run this again.)
echo.
pause
