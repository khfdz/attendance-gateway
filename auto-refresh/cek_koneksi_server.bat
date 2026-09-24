@echo off
setlocal
cd /d "%~dp0"

echo =================================================================
echo        PENGECEKAN KONEKSI DAN CONNECTION ID MEKARI SERVER
echo =================================================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$logPath = Join-Path $env:APPDATA 'mekari-rta\backend\internal.log';" ^
    "if (-not (Test-Path $logPath)) {" ^
    "    $logPath = 'C:\Users\Administrator\AppData\Roaming\mekari-rta\backend\internal.log';" ^
    "}" ^
    "if (Test-Path $logPath) {" ^
    "    Write-Host '[1] File Log Ditemukan di:' $logPath -ForegroundColor Green;" ^
    "    $ids = Select-String -Path $logPath -Pattern '(?i)connection\s*id\s*[:\s]+(\d+)' | ForEach-Object { $_.Matches[0].Groups[1].Value } | Select-Object -Unique;" ^
    "    if ($ids) {" ^
    "        Write-Host '[2] Connection ID yang Terdaftar di Server ini adalah: ' -NoNewline -ForegroundColor Cyan;" ^
    "        Write-Host ($ids -join ', ') -ForegroundColor Yellow -BackgroundColor Black;" ^
    "    } else {" ^
    "        Write-Host '[2] Connection ID belum tercatat di log.' -ForegroundColor Yellow;" ^
    "    }" ^
    "    Write-Host '';" ^
    "    Write-Host '[3] 10 Baris Log Terakhir dari Mekari Backend:' -ForegroundColor Cyan;" ^
    "    Get-Content $logPath -Tail 10 | ForEach-Object { Write-Host '  ' $_ };" ^
    "} else {" ^
    "    Write-Host '[!] File log internal.log belum ditemukan di AppData!' -ForegroundColor Red;" ^
    "}"

echo.
echo =================================================================
pause
