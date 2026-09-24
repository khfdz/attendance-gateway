@echo off
setlocal
cd /d "%~dp0"

echo =======================================================
echo     RESTART BERSIH MEKARI AGENT FINGERPRINT
echo =======================================================
echo.
echo 1. Menutup proses Mekari yang menggantung di memori...
taskkill /F /IM "Mekari*" /T >nul 2>&1
taskkill /F /IM "mekari-rta*" /T >nul 2>&1
timeout /t 2 /nobreak >nul

echo 2. Membuka kembali Mekari Agent Fingerprint...
if exist "C:\Program Files\Mekari Agent Fingerprint\Mekari Agent Fingerprint.exe" (
    start "" "C:\Program Files\Mekari Agent Fingerprint\Mekari Agent Fingerprint.exe"
) else if exist "C:\Program Files\Mekari Agent Fingerprint\Mekari.exe" (
    start "" "C:\Program Files\Mekari Agent Fingerprint\Mekari.exe"
) else (
    echo [ERROR] File aplikasi Mekari tidak ditemukan di C:\Program Files!
    pause
    exit /b 1
)

echo 3. Menunggu service backend siap (5 detik)...
timeout /t 5 /nobreak >nul

echo.
echo =======================================================
echo [OK] Mekari Agent Fingerprint telah dibuka ulang dengan bersih!
echo Silakan periksa layarnya sekarang, status error backend sudah hilang.
echo =======================================================
echo.
pause
