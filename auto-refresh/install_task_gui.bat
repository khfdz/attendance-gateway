@echo off
setlocal
cd /d "%~dp0"

echo =======================================================
echo    Pemasangan Jadwal Auto Sync Mekari (MODE VISUAL)
echo =======================================================
echo Mode ini akan memunculkan jendela status di layar setiap
echo jadwal berjalan. Cocok untuk PC kerja yang layarnya menyala.
echo =======================================================
echo.
echo Pilih opsi jadwal:
echo [1] Setiap 1 Menit (Realtime Auto-Sync) [DEFAULT]
echo [2] Setiap 5 Menit
echo [3] Setiap 1 Jam
echo [4] Jam 12 Malam (00:00) dan Jam 6 Pagi (06:00)
echo.
set /p choice="Masukkan pilihan [1, 2, 3, atau 4, default: 1]: "

if "%choice%"=="4" (
    echo.
    echo Menjadwalkan Sync Visual pada jam 00:00 dan 06:00...
    schtasks /create /tn "Mekari_GUI_AutoSync_00" /tr "powershell.exe -ExecutionPolicy Bypass -File \"%~dp0sync_mekari_gui.ps1\"" /sc DAILY /st 00:00 /f /rl HIGHEST
    schtasks /create /tn "Mekari_GUI_AutoSync_06" /tr "powershell.exe -ExecutionPolicy Bypass -File \"%~dp0sync_mekari_gui.ps1\"" /sc DAILY /st 06:00 /f /rl HIGHEST
    echo.
    echo [OK] Jadwal berhasil dibuat untuk jam 00:00 dan 06:00!
) else if "%choice%"=="3" (
    echo.
    echo Menjadwalkan Sync Visual Setiap 1 Jam...
    schtasks /create /tn "Mekari_GUI_AutoSync" /tr "powershell.exe -ExecutionPolicy Bypass -File \"%~dp0sync_mekari_gui.ps1\"" /sc HOURLY /mo 1 /f /rl HIGHEST
    echo.
    echo [OK] Jadwal berhasil dibuat untuk berjalan SETIAP 1 JAM!
) else if "%choice%"=="2" (
    echo.
    echo Menjadwalkan Sync Visual Setiap 5 Menit...
    schtasks /create /tn "Mekari_GUI_AutoSync" /tr "powershell.exe -ExecutionPolicy Bypass -File \"%~dp0sync_mekari_gui.ps1\"" /sc MINUTE /mo 5 /f /rl HIGHEST
    echo.
    echo [OK] Jadwal berhasil dibuat untuk berjalan SETIAP 5 MENIT!
) else (
    echo.
    echo Menjadwalkan Sync Visual Setiap 1 Menit...
    schtasks /create /tn "Mekari_GUI_AutoSync" /tr "powershell.exe -ExecutionPolicy Bypass -File \"%~dp0sync_mekari_gui.ps1\"" /sc MINUTE /mo 1 /f /rl HIGHEST
    echo.
    echo [OK] Jadwal berhasil dibuat untuk berjalan otomatis SETIAP 1 MENIT!
)

echo.
echo Log tersimpan di:
echo %~dp0sync_gui_history.log
echo.
pause
