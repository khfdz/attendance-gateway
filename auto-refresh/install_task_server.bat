@echo off
setlocal
cd /d "%~dp0"

echo =================================================================
echo   Pemasangan Jadwal Auto Sync Mekari Fingerprint (WINDOWS SERVER)
echo =================================================================
echo Target Eksekusi : Mekari.exe / Mekari Agent Fingerprint.exe
echo Akun Eksekusi   : NT AUTHORITY\SYSTEM (Berjalan 24/7 Non-Stop)
echo =================================================================
echo.

:: Cek apakah dijalankan sebagai Administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [PERHATIAN] File ini harus dijalankan dengan hak Administrator!
    echo Silakan klik kanan file ini lalu pilih "Run as administrator".
    echo.
    pause
    exit /b 1
)

:: Hapus jadwal lama jika ada
schtasks /delete /tn "Mekari_Server_AutoSync" /f >nul 2>&1
schtasks /delete /tn "Mekari_Server_AutoSync_00" /f >nul 2>&1
schtasks /delete /tn "Mekari_Server_AutoSync_06" /f >nul 2>&1

echo Pilih opsi jadwal sinkronisasi untuk Server:
echo [1] Setiap 1 Menit (Realtime Auto-Sync, Paling Akurat) [DEFAULT]
echo [2] Setiap 5 Menit
echo [3] Setiap 1 Jam
echo [4] Hanya Jam 12 Malam (00:00) dan Jam 6 Pagi (06:00)
echo.
set /p choice="Masukkan pilihan [1, 2, 3, atau 4, default: 1]: "

if "%choice%"=="4" (
    echo.
    echo Menjadwalkan Sync pada jam 00:00 dan 06:00 di Windows Server...
    schtasks /create /tn "Mekari_Server_AutoSync_00" /tr "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File \"%~dp0sync_mekari_server.ps1\"" /sc DAILY /st 00:00 /f /rl HIGHEST /ru "SYSTEM"
    schtasks /create /tn "Mekari_Server_AutoSync_06" /tr "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File \"%~dp0sync_mekari_server.ps1\"" /sc DAILY /st 06:00 /f /rl HIGHEST /ru "SYSTEM"
    echo.
    echo [OK] Jadwal Windows Server berhasil dibuat untuk jam 00:00 dan 06:00!
) else if "%choice%"=="3" (
    echo.
    echo Menjadwalkan Sync Setiap 1 Jam di Windows Server...
    schtasks /create /tn "Mekari_Server_AutoSync" /tr "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File \"%~dp0sync_mekari_server.ps1\"" /sc HOURLY /mo 1 /f /rl HIGHEST /ru "SYSTEM"
    echo.
    echo [OK] Jadwal Windows Server berhasil dibuat untuk berjalan otomatis SETIAP 1 JAM!
) else if "%choice%"=="2" (
    echo.
    echo Menjadwalkan Sync Setiap 5 Menit di Windows Server...
    schtasks /create /tn "Mekari_Server_AutoSync" /tr "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File \"%~dp0sync_mekari_server.ps1\"" /sc MINUTE /mo 5 /f /rl HIGHEST /ru "SYSTEM"
    echo.
    echo [OK] Jadwal Windows Server berhasil dibuat untuk berjalan otomatis SETIAP 5 MENIT!
) else (
    echo.
    echo Menjadwalkan Sync Setiap 1 Menit di Windows Server...
    schtasks /create /tn "Mekari_Server_AutoSync" /tr "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File \"%~dp0sync_mekari_server.ps1\"" /sc MINUTE /mo 1 /f /rl HIGHEST /ru "SYSTEM"
    echo.
    echo [OK] Jadwal Windows Server berhasil dibuat untuk berjalan otomatis SETIAP 1 MENIT!
)

echo [OK] Mode: Berjalan 24 jam non-stop di akun SYSTEM (tetap aktif meski RDP ditutup).
echo.
echo Catatan Log riwayat tersimpan di:
echo %~dp0sync_server_history.log
echo.
pause
