@echo off
setlocal
cd /d "%~dp0"

echo =======================================================
echo    Menghapus Jadwal Auto Sync Mekari Fingerprint
echo =======================================================
echo.

schtasks /delete /tn "Mekari_AutoSync" /f >nul 2>&1
schtasks /delete /tn "Mekari_AutoSync_00" /f >nul 2>&1
schtasks /delete /tn "Mekari_AutoSync_06" /f >nul 2>&1
schtasks /delete /tn "Mekari_Server_AutoSync" /f >nul 2>&1
schtasks /delete /tn "Mekari_Server_AutoSync_00" /f >nul 2>&1
schtasks /delete /tn "Mekari_Server_AutoSync_06" /f >nul 2>&1
schtasks /delete /tn "Mekari_GUI_AutoSync" /f >nul 2>&1
schtasks /delete /tn "Mekari_GUI_AutoSync_00" /f >nul 2>&1
schtasks /delete /tn "Mekari_GUI_AutoSync_06" /f >nul 2>&1

echo [OK] Semua jadwal otomatisasi berhasil dibersihkan/dihapus.
echo.
pause
