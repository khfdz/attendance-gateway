@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo =================================================================
echo             DETEKSI PENYEBAB ERROR MEKARI SERVER
echo =================================================================
echo.

:: 1. Cek port 8081
echo [1] Memeriksa apakah Port 8081 sedang dipakai proses lain:
netstat -ano | findstr ":8081 "
if %errorlevel% equ 0 (
    echo [!] PERHATIAN: Port 8081 sedang dipakai oleh proses di atas!
) else (
    echo [OK] Port 8081 kosong.
)
echo.

:: 2. Cek lokasi backend exe
set "BACKEND_EXE="
if exist "%APPDATA%\mekari-rta\backend\mekari-rta-1.8.0-x64.exe" (
    set "BACKEND_EXE=%APPDATA%\mekari-rta\backend\mekari-rta-1.8.0-x64.exe"
    set "BACKEND_DIR=%APPDATA%\mekari-rta\backend"
) else if exist "C:\Users\Administrator\AppData\Roaming\mekari-rta\backend\mekari-rta-1.8.0-x64.exe" (
    set "BACKEND_EXE=C:\Users\Administrator\AppData\Roaming\mekari-rta\backend\mekari-rta-1.8.0-x64.exe"
    set "BACKEND_DIR=C:\Users\Administrator\AppData\Roaming\mekari-rta\backend"
)

if not defined BACKEND_EXE (
    echo [ERROR] File mekari-rta-1.8.0-x64.exe tidak ditemukan di AppData!
    goto SHOW_LOG
)

echo [2] Menjalankan engine mekari-rta server langsung untuk melihat pesan error:
echo     Lokasi: %BACKEND_EXE%
echo -----------------------------------------------------------------
cd /d "%BACKEND_DIR%"
"%BACKEND_EXE%" server
echo -----------------------------------------------------------------
echo.

:SHOW_LOG
echo [3] 15 Baris Terakhir dari File Log Mekari (internal.log):
echo -----------------------------------------------------------------
if exist "%APPDATA%\mekari-rta\backend\internal.log" (
    powershell -Command "Get-Content '%APPDATA%\mekari-rta\backend\internal.log' -Tail 15"
) else if exist "C:\Users\Administrator\AppData\Roaming\mekari-rta\backend\internal.log" (
    powershell -Command "Get-Content 'C:\Users\Administrator\AppData\Roaming\mekari-rta\backend\internal.log' -Tail 15"
) else (
    echo File internal.log tidak ditemukan.
)
echo -----------------------------------------------------------------

echo.
echo =================================================================
echo Silakan copy-paste semua teks di atas ke chat!
echo =================================================================
pause
