@echo off
cd /d "%~dp0"
echo Membuka Mekari Auto-Sync (Mode Visual)...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync_mekari_gui.ps1"
echo.
pause
