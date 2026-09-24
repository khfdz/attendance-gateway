<#
================================================================================
 Script   : sync_mekari.ps1
 Tujuan   : Otomatisasi sinkronisasi absensi Mekari Agent Fingerprint (Talenta)
 Keunggulan: Aman, tidak meluncurkan aplikasi ganda (anti-crash), dan mendeteksi
             koneksi absensi secara dinamis.
================================================================================
#>

param(
    [int]$ConnectionId = 3,
    [string[]]$CandidatePaths = @(
        "C:\Program Files\Mekari Agent Fingerprint\Mekari Agent Fingerprint.exe",
        "C:\Program Files\Mekari Agent Fingerprint\Mekari.exe",
        "C:\Program Files (x86)\Mekari Agent Fingerprint\Mekari.exe"
    ),
    [string]$LogFile = "$PSScriptRoot\sync_history.log"
)

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logLine = "[$timestamp] [$Level] $Message"
    Write-Output $logLine
    try {
        Add-Content -Path $LogFile -Value $logLine -ErrorAction SilentlyContinue
    } catch {}
}

Write-Log "Memulai proses sinkronisasi Mekari Agent Fingerprint..."

# 1. Cek apakah service port 8081 sudah aktif terlebih dahulu
$portReady = $false
try {
    $testClient = New-Object System.Net.Sockets.TcpClient
    $testClient.Connect("127.0.0.1", 8081)
    if ($testClient.Connected) {
        $testClient.Close()
        $portReady = $true
        Write-Log "Aplikasi Mekari sudah berjalan dan service port 8081 aktif." "INFO"
    }
} catch {}

# 2. Jika port 8081 belum aktif, cek proses dan luncurkan jika benar-benar belum terbuka
if (-not $portReady) {
    $existingProc = Get-Process | Where-Object { $_.ProcessName -like "*Mekari*" -or $_.ProcessName -like "*mekari-rta*" }
    
    if (-not $existingProc) {
        $foundPath = $null
        foreach ($p in $CandidatePaths) {
            if (Test-Path $p) {
                $foundPath = $p
                break
            }
        }

        if ($foundPath) {
            Write-Log "Aplikasi Mekari belum menyala. Meluncurkan: $foundPath" "WARN"
            Start-Process -FilePath $foundPath -WorkingDirectory "C:\Program Files\Mekari Agent Fingerprint"
            Write-Log "Aplikasi diluncurkan. Menunggu backend siap (10 detik)..."
            Start-Sleep -Seconds 10
        } else {
            Write-Log "Aplikasi Mekari tidak ditemukan di folder standar!" "ERROR"
            exit 1
        }
    } else {
        Write-Log "Proses Mekari terdeteksi ($($existingProc.Count) proses). Menunggu port 8081 siap..." "INFO"
    }

    # Tunggu port 8081 siap
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $maxWait = 25
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
        Start-Sleep -Milliseconds 1000
    }

    if (-not $portReady) {
        Write-Log "Port lokal 8081 belum merespons setelah $maxWait detik." "ERROR"
        exit 1
    }
}

Write-Log "Service Mekari siap (port 8081 aktif)."

# 3. Ambil daftar koneksi yang aktif secara dinamis dari API Mekari
$connListUri = "http://127.0.0.1:8081/connections"
$syncUri = "http://127.0.0.1:8081/sync"

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls

try {
    $connResp = Invoke-RestMethod -Uri $connListUri -Method Get -TimeoutSec 10
    $activeConns = $connResp.data.data
} catch {
    $activeConns = $null
}

if ($activeConns -and $activeConns.Count -gt 0) {
    Write-Log "Ditemukan $($activeConns.Count) koneksi aktif di Mekari." "INFO"
    $successCount = 0

    foreach ($conn in $activeConns) {
        $cId = $conn.id
        $cName = $conn.name
        $body = "{`"id`": $cId}"

        try {
            Write-Log "Menyinkronkan Koneksi '$cName' (ID: $cId)..." "INFO"
            $resp = Invoke-RestMethod -Uri $syncUri -Method Post -ContentType "application/json" -Body $body -TimeoutSec 15

            if ($resp.success -eq $true) {
                Write-Log "BERHASIL: '$cName' (ID $cId) -> $($resp.data.message)" "SUCCESS"
                $successCount++
            } else {
                $err = ($resp.errors | ConvertTo-Json -Compress)
                Write-Log "RESPON: $err" "WARN"
            }
        } catch {
            Write-Log "Kendala saat sync '$cName': $($_.Exception.Message)" "ERROR"
        }
    }

    if ($successCount -gt 0) {
        Write-Log "Siklus sinkronisasi selesai: $successCount koneksi sukses tersinkron." "SUCCESS"
    }
} else {
    # Fallback ke connection ID default
    Write-Log "Menggunakan target Connection ID: $ConnectionId" "WARN"
    try {
        $resp = Invoke-RestMethod -Uri $syncUri -Method Post -ContentType "application/json" -Body "{`"id`": $ConnectionId}" -TimeoutSec 15
        if ($resp.success -eq $true) {
            Write-Log "BERHASIL: $($resp.data.message)" "SUCCESS"
        }
    } catch {
        Write-Log "Kendala koneksi sync: $($_.Exception.Message)" "ERROR"
        exit 1
    }
}

Write-Log "Proses selesai."
