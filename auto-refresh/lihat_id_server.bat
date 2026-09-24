@echo off
setlocal
cd /d "%~dp0"

echo =================================================================
echo             CEK DAFTAR KONEKSI AKTIF MEKARI SERVER
echo =================================================================
echo.
echo Menghubungi service Mekari di port 8081 (Read-Only)...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "try {" ^
    "    $resp = Invoke-RestMethod -Uri 'http://127.0.0.1:8081/connections' -Method Get -TimeoutSec 10;" ^
    "    $list = $resp.data.data;" ^
    "    if ($list) {" ^
    "        Write-Host 'STATUS: BERHASIL TERHUBUNG KE BACKEND MEKARI!' -ForegroundColor Green;" ^
    "        Write-Host '';" ^
    "        Write-Host 'Daftar Koneksi Mesin Absensi yang Terdaftar di Server ini:' -ForegroundColor Cyan;" ^
    "        Write-Host '---------------------------------------------------------------' -ForegroundColor DarkGray;" ^
    "        foreach ($c in $list) {" ^
    "            Write-Host (' ID KONEKSI : ' + $c.id) -ForegroundColor Yellow -BackgroundColor Black;" ^
    "            Write-Host (' Nama DB    : ' + $c.name) -ForegroundColor White;" ^
    "            Write-Host (' Status     : ' + $c.status) -ForegroundColor White;" ^
    "            Write-Host (' Terakhir   : ' + $c.datetime) -ForegroundColor DarkGray;" ^
    "            Write-Host '---------------------------------------------------------------' -ForegroundColor DarkGray;" ^
    "        };" ^
    "    } else {" ^
    "        Write-Host 'Terhubung ke Mekari, tapi belum ada database absensi yang terdaftar di Connection List!' -ForegroundColor Yellow;" ^
    "    }" ^
    "} catch {" ^
    "    Write-Host 'GAGAL TERHUBUNG KE MEKARI PORT 8081!' -ForegroundColor Red;" ^
    "    Write-Host ('Pesan Error: ' + $_.Exception.Message) -ForegroundColor Red;" ^
    "    Write-Host '';" ^
    "    Write-Host 'Pastikan aplikasi Mekari Agent Fingerprint sudah dibuka normal di layar server sebelum menjalankan file ini.' -ForegroundColor Yellow;" ^
    "}"

echo.
echo =================================================================
pause
