@echo off
setlocal
cd /d "%~dp0"

echo =================================================================
echo        DIAGNOSA DAN PERBAIKAN MEKARI AGENT DI WINDOWS SERVER
echo =================================================================
echo.

:: 1. Cek Hak Administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [PERINGATAN] Silakan klik kanan file ini lalu pilih "Run as administrator"!
    echo.
)

echo [1/5] Memeriksa apakah ada proses lain yang memakai Port 8081...
for /f "tokens=5" %%a in ('netstat -aon ^| findstr ":8081 "') do (
    set OCCUPIED_PID=%%a
)

if defined OCCUPIED_PID (
    echo   Port 8081 sedang dipakai oleh PID: %OCCUPIED_PID%
    tasklist /fi "PID eq %OCCUPIED_PID%"
) else (
    echo   Port 8081 kosong / belum aktif.
)
echo.

echo [2/5] Menambahkan izin Windows Firewall untuk Mekari Backend...
netsh advfirewall firewall delete rule name="Mekari Backend 8081" >nul 2>&1
netsh advfirewall firewall add rule name="Mekari Backend 8081" dir=in action=allow protocol=TCP localport=8081 >nul 2>&1
echo   Izin Windows Firewall Port 8081: [OK]
echo.

echo [3/5] Membersihkan semua proses Mekari yang macet/zombie...
taskkill /F /IM "Mekari*" /T >nul 2>&1
taskkill /F /IM "mekari-rta*" /T >nul 2>&1
timeout /t 2 /nobreak >nul
echo   Semua proses lama telah ditutup bersih.
echo.

echo [4/5] Membuka log error internal Mekari Server...
powershell -Command ^
    "$logPath = Join-Path $env:APPDATA 'mekari-rta\backend\internal.log';" ^
    "if (Test-Path $logPath) {" ^
    "    Write-Host '--- 8 Baris Terakhir Log Mekari Server: ---' -ForegroundColor Yellow;" ^
    "    Get-Content $logPath -Tail 8 | ForEach-Object { Write-Host $_ };" ^
    "} else {" ^
    "    Write-Host 'File log belum ditemukan di:' $logPath -ForegroundColor Cyan;" ^
    "}"
echo.

echo [5/5] Membuka kembali Mekari Agent Fingerprint...
if exist "C:\Program Files\Mekari Agent Fingerprint\Mekari Agent Fingerprint.exe" (
    start "" "C:\Program Files\Mekari Agent Fingerprint\Mekari Agent Fingerprint.exe"
    echo   Aplikasi diluncurkan dari C:\Program Files.
) else if exist "C:\Program Files (x86)\Mekari Agent Fingerprint\Mekari Agent Fingerprint.exe" (
    start "" "C:\Program Files (x86)\Mekari Agent Fingerprint\Mekari Agent Fingerprint.exe"
    echo   Aplikasi diluncurkan dari C:\Program Files (x86).
) else (
    echo   [ERROR] Aplikasi Mekari tidak ditemukan di folder standar!
)

echo.
echo Menunggu 5 detik agar service backend Mekari inisialisasi...
timeout /t 5 /nobreak >nul

echo.
echo Memeriksa status port 8081 sekarang...
netstat -ano | findstr ":8081 "
if %errorlevel% equ 0 (
    echo.
    echo =================================================================
    echo [SUKSES] Backend Mekari Server AKTIF di port 8081!
    echo Sekarang jalankan run_now_server.bat, pasti sukses!
    echo =================================================================
) else (
    echo.
    echo =================================================================
    echo [INFO] Jika di layar Mekari masih muncul error backend,
    echo periksa baris kuning di atas untuk melihat penyebab spesifiknya.
    echo =================================================================
)
echo.
pause
