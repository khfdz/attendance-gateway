<#
================================================================================
 Script   : sync_mekari_server.ps1
 Tujuan   : Otomatisasi Sinkronisasi Mekari Agent Fingerprint Khusus Windows Server
 Target   : C:\Program Files\Mekari Agent Fingerprint\Mekari.exe
 Keunggulan:
  - Kompatibel penuh Windows Server (2012 / 2016 / 2019 / 2022).
  - Bisa berjalan walau user Server dalam keadaan LOG OFF / Session Lock.
  - Otomatis mendeteksi Mekari.exe atau Mekari Agent Fingerprint.exe.
  - Ringan, stabil, dan tidak membebani performa server absensi.
================================================================================
#>

param(
    [int]$ConnectionId = 3,
    [string[]]$CandidatePaths = @(
        "C:\Program Files\Mekari Agent Fingerprint\Mekari.exe",
        "C:\Program Files\Mekari Agent Fingerprint\Mekari Agent Fingerprint.exe",
        "C:\Program Files (x86)\Mekari Agent Fingerprint\Mekari.exe"
    ),
    [string]$LogFile = "$PSScriptRoot\sync_server_history.log"
)

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logLine = "[$timestamp] [$Level] $Message"
    Write-Output $logLine
    try {
        if (Test-Path $LogFile) {
            $item = Get-Item $LogFile
            if ($item.Length -gt 3MB) {
                Move-Item -Path $LogFile -Destination "$LogFile.old" -Force -ErrorAction SilentlyContinue
            }
        }
        Add-Content -Path $LogFile -Value $logLine -ErrorAction SilentlyContinue
    } catch {}
}

Write-Log "=== [SERVER] Memulai siklus auto-sync Mekari ==="

# 1. Deteksi file executable yang valid
$selectedPath = $null
foreach ($path in $CandidatePaths) {
    if (Test-Path $path) {
        $selectedPath = $path
        break
    }
}

# 2. Cek apakah port 8081 sudah aktif
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

$justLaunched = $false
if (-not $portReady) {
    # Cek apakah proses Mekari dan RTA sedang aktif
    $mekariProc = Get-Process | Where-Object { $_.ProcessName -like "*Mekari*" -or $_.ProcessName -like "*mekari-rta*" }

    if (-not $mekariProc) {
        if ($selectedPath) {
            Write-Log "Mekari belum berjalan di server. Menjalankan: $selectedPath" "WARN"
            Start-Process -FilePath $selectedPath -WorkingDirectory "C:\Program Files\Mekari Agent Fingerprint"
            $justLaunched = $true
            Write-Log "Aplikasi diluncurkan. Menunggu service port 8081 siap (10 detik)..."
            Start-Sleep -Seconds 10
        } else {
            Write-Log "File executable Mekari.exe tidak ditemukan di lokasi standar!" "ERROR"
            exit 1
        }
    } else {
        Write-Log "Mekari sudah aktif di server (Ditemukan $($mekariProc.Count) proses terkait)."
    }

    # 3. Tunggu hingga service port 8081 siap menerima koneksi
    $maxWaitSeconds = 30
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    while ($stopwatch.Elapsed.TotalSeconds -lt $maxWaitSeconds) {
        try {
            $client = New-Object System.Net.Sockets.TcpClient
            $client.Connect("127.0.0.1", 8081)
            if ($client.Connected) {
                $client.Close()
                $portReady = $true
                break
            }
        } catch {}
        Start-Sleep -Milliseconds 1000
    }

    if (-not $portReady) {
        Write-Log "Timeout: Service port 8081 belum merespons setelah $maxWaitSeconds detik." "ERROR"
        exit 1
    }
}

Write-Log "Service Mekari Server aktif di port 8081."

if ($justLaunched) {
    Write-Log "Mekari baru saja dimulai: Memberikan jeda 10 detik agar migrasi database & jobs inisialisasi tuntas..."
    Start-Sleep -Seconds 10
} else {
    Start-Sleep -Seconds 2
}

# 4. Ambil daftar koneksi resmi yang aktif langsung dari API Mekari
$connListUri = "http://127.0.0.1:8081/connections"
$syncUri = "http://127.0.0.1:8081/sync"

# Set SecurityProtocol untuk kompatibilitas Windows Server
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls

try {
    Write-Log "Membaca daftar koneksi aktif dari Mekari Server..." "INFO"
    $connResp = Invoke-RestMethod -Uri $connListUri -Method Get -TimeoutSec 10
    $activeConnections = $connResp.data.data
} catch {
    Write-Log "Tidak dapat membaca /connections secara dinamis: $($_.Exception.Message)" "WARN"
    $activeConnections = $null
}

if ($activeConnections -and $activeConnections.Count -gt 0) {
    Write-Log "Ditemukan $($activeConnections.Count) koneksi aktif di server." "INFO"
    $syncSuccessCount = 0

    foreach ($conn in $activeConnections) {
        $cId = $conn.id
        $cName = $conn.name
        $jsonBody = "{`"id`": $cId}"

        try {
            Write-Log "Menyinkronkan Koneksi '$cName' (ID: $cId)..." "INFO"
            $response = Invoke-RestMethod -Uri $syncUri -Method Post -ContentType "application/json" -Body $jsonBody -TimeoutSec 15

            if ($response.success -eq $true) {
                Write-Log "BERHASIL DI SERVER - '$cName' (ID $cId): $($response.data.message)" "SUCCESS"
                $syncSuccessCount++
            } else {
                $errMsg = ($response.errors | ConvertTo-Json -Compress)
                Write-Log "RESPON MEKARI (ID $cId): $errMsg" "WARN"
            }
        } catch {
            Write-Log "Kendala saat sync '$cName' (ID $cId): $($_.Exception.Message)" "ERROR"
        }
    }

    if ($syncSuccessCount -gt 0) {
        Write-Log "=== [SERVER] Siklus sinkronisasi selesai: $syncSuccessCount koneksi sukses tersinkron ===" "SUCCESS"
    } else {
        Write-Log "=== [SERVER] Gagal menyinkronkan koneksi di server ===" "ERROR"
        exit 1
    }
} else {
    # Fallback jika list kosong
    Write-Log "Menggunakan fallback Connection ID default: $ConnectionId" "WARN"
    $jsonBody = "{`"id`": $ConnectionId}"
    try {
        $response = Invoke-RestMethod -Uri $syncUri -Method Post -ContentType "application/json" -Body $jsonBody -TimeoutSec 15
        if ($response.success -eq $true) {
            Write-Log "BERHASIL DI SERVER (ID $ConnectionId): $($response.data.message)" "SUCCESS"
            Write-Log "=== [SERVER] Siklus sinkronisasi selesai: SUKSES ===" "SUCCESS"
        }
    } catch {
        Write-Log "Terjadi kendala koneksi sync fallback: $($_.Exception.Message)" "ERROR"
        exit 1
    }
}
