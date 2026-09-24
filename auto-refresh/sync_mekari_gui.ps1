<#
================================================================================
 Script   : sync_mekari_gui.ps1
 Tujuan   : Sinkronisasi Mekari Agent Fingerprint dengan Tampilan Visual (GUI)
 Fitur    :
  - Membawa jendela / notifikasi Mekari ke layar depan
  - Menampilkan status visual interaktif di layar
  - Menampilkan notifikasi popup balon (Toast/Popup) konfirmasi sukses
  - Aman dan langsung memicu pengiriman data absensi ke server Talenta
================================================================================
#>

param(
    [int]$ConnectionId = 3,
    [string]$LogFile = "$PSScriptRoot\sync_gui_history.log"
)

# Load GUI assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Write-GuiLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logLine = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        "SUCCESS" { Write-Host $logLine -ForegroundColor Green }
        "WARN"    { Write-Host $logLine -ForegroundColor Yellow }
        "ERROR"   { Write-Host $logLine -ForegroundColor Red }
        default   { Write-Host $logLine -ForegroundColor Cyan }
    }

    try {
        Add-Content -Path $LogFile -Value $logLine -ErrorAction SilentlyContinue
    } catch {}
}

Clear-Host
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "       MEKARI AGENT FINGERPRINT - AUTO REFRESH (GUI MODE)       " -ForegroundColor White
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

Write-GuiLog "Memulai proses sinkronisasi Mekari visual..." "INFO"

# 1. Cek apakah Mekari Agent sedang aktif
$mekariProc = Get-Process | Where-Object { $_.ProcessName -like "*Mekari*" -or $_.ProcessName -like "*mekari-rta*" }

if (-not $mekariProc) {
    Write-GuiLog "Aplikasi Mekari belum menyala. Meluncurkan aplikasi..." "WARN"
    $appPath = "C:\Program Files\Mekari Agent Fingerprint\Mekari Agent Fingerprint.exe"
    if (Test-Path $appPath) {
        Start-Process -FilePath $appPath -WorkingDirectory "C:\Program Files\Mekari Agent Fingerprint"
        Write-GuiLog "Mekari diluncurkan. Menunggu service backend siap..." "INFO"
        Start-Sleep -Seconds 8
    } else {
        Write-GuiLog "Aplikasi Mekari tidak ditemukan di folder standar!" "ERROR"
        [System.Windows.Forms.MessageBox]::Show("Aplikasi Mekari Agent Fingerprint tidak ditemukan!", "Error Auto-Sync", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        exit 1
    }
} else {
    Write-GuiLog "Aplikasi Mekari Agent terdeteksi aktif ($($mekariProc.Count) proses)." "INFO"
}

# 2. Cek kesiapan port lokal 8081
$portReady = $false
$maxWait = 15
$sw = [System.Diagnostics.Stopwatch]::StartNew()

while ($sw.Elapsed.TotalSeconds -lt $maxWait) {
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $tcp.Connect("127.0.0.1", 8081)
        if ($tcp.Connected) {
            $tcp.Close()
            $portReady = $true
            break
        }
    } catch {}
    Start-Sleep -Milliseconds 800
}

if (-not $portReady) {
    Write-GuiLog "Service engine Mekari port 8081 belum merespons." "ERROR"
    [System.Windows.Forms.MessageBox]::Show("Service Mekari belum siap di port 8081.`n`nSilakan buka aplikasi Mekari Agent Fingerprint terlebih dahulu sampai layarnya terbuka normal, lalu jalankan kembali file ini.", "Mekari Auto-Sync", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    exit 1
}

Write-GuiLog "Service Mekari siap di port 8081." "INFO"

# 3. Ambil daftar koneksi resmi yang aktif langsung dari API Mekari
$connListUri = "http://127.0.0.1:8081/connections"
$syncUri = "http://127.0.0.1:8081/sync"

try {
    Write-GuiLog "Membaca daftar koneksi yang aktif..." "INFO"
    $connResp = Invoke-RestMethod -Uri $connListUri -Method Get -TimeoutSec 10
    $activeConnections = $connResp.data.data
} catch {
    Write-GuiLog "Gagal membaca /connections: $($_.Exception.Message)" "WARN"
    $activeConnections = $null
}

$successMessages = @()

if ($activeConnections -and $activeConnections.Count -gt 0) {
    Write-GuiLog "Ditemukan $($activeConnections.Count) koneksi aktif di Mekari." "INFO"

    foreach ($conn in $activeConnections) {
        $cId = $conn.id
        $cName = $conn.name
        $body = "{`"id`": $cId}"

        try {
            Write-GuiLog "Mengeklik tombol Sync untuk '$cName' (ID: $cId)..." "INFO"
            $resp = Invoke-RestMethod -Uri $syncUri -Method Post -ContentType "application/json" -Body $body -TimeoutSec 15

            if ($resp.success -eq $true) {
                $msg = $resp.data.message
                Write-GuiLog "SUKSES: Koneksi '$cName' (ID $cId) berhasil direfresh ($msg)" "SUCCESS"
                $successMessages += "$cName (ID $cId): $msg"
            }
        } catch {
            Write-GuiLog "Kendala saat refresh '$cName' (ID $cId): $($_.Exception.Message)" "WARN"
        }
    }
} else {
    # Fallback jika list koneksi tidak terbaca
    try {
        Write-GuiLog "Menggunakan fallback Connection ID: $ConnectionId..." "INFO"
        $resp = Invoke-RestMethod -Uri $syncUri -Method Post -ContentType "application/json" -Body "{`"id`": $ConnectionId}" -TimeoutSec 15
        if ($resp.success -eq $true) {
            $successMessages += "Koneksi ID $ConnectionId: $($resp.data.message)"
        }
    } catch {
        Write-GuiLog "Gagal sync: $($_.Exception.Message)" "ERROR"
    }
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan

if ($successMessages.Count -gt 0) {
    $detail = $successMessages -join "`n"
    Write-GuiLog "SINKRONISASI BERHASIL DILAKUKAN KE CLOUD TALENTA!" "SUCCESS"
    
    # Tampilkan notifikasi balon visual (Toast / BalloonTip)
    $notify = New-Object System.Windows.Forms.NotifyIcon
    $notify.Icon = [System.Drawing.SystemIcons]::Information
    $notify.BalloonTipTitle = "Mekari Auto-Sync: BERHASIL"
    $notify.BalloonTipText = "Data absensi berhasil disinkronkan ke server Talenta!`n$detail"
    $notify.Visible = $true
    $notify.ShowBalloonTip(4000)
    
    Start-Sleep -Seconds 2
    $notify.Dispose()
} else {
    Write-GuiLog "Tidak ada data koneksi yang berhasil disinkronkan." "WARN"
    [System.Windows.Forms.MessageBox]::Show("Gagal melakukan sinkronisasi ke server.", "Mekari Auto-Sync", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
}

Write-GuiLog "Selesai." "INFO"
