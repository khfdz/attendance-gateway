const ZKLib = require('node-zklib');
const { pool } = require('../config/database');
const dayjs = require('dayjs');
const { getIO } = require('../config/socket');

// State sinkronisasi global di memori backend
let syncStatus = {
  isSyncing: false,
  status: 'idle', // 'idle', 'connecting', 'downloading', 'saving', 'done', 'error'
  currentMachine: null,
  currentMachineIndex: 0,
  totalMachines: 0,
  progress: 0,
  processedCount: 0,
  totalCount: 0,
  inserted: 0,
  skipped: 0,
  errors: 0,
  timeRemaining: null,
  errorMsg: null,
  lastSync: null,
  machineSummaries: [] // detail hasil per mesin
};

// Broadcast progress lewat Socket.io jika terhubung
function broadcastProgress() {
  try {
    const io = getIO();
    if (io) {
      io.emit('sync:progress', syncStatus);
    }
  } catch (err) {
    // Abaikan jika socket error
  }
}

/**
 * Menjalankan proses sinkronisasi di latar belakang (TCP Pull via ZKLib)
 */
async function runSyncBackground() {
  if (syncStatus.isSyncing) return;

  // Reset Status
  syncStatus.isSyncing = true;
  syncStatus.status = 'connecting';
  syncStatus.progress = 0;
  syncStatus.processedCount = 0;
  syncStatus.totalCount = 0;
  syncStatus.inserted = 0;
  syncStatus.skipped = 0;
  syncStatus.errors = 0;
  syncStatus.timeRemaining = null;
  syncStatus.errorMsg = null;
  syncStatus.machineSummaries = [];
  broadcastProgress();

  // 1. Ambil semua mesin yang berstatus aktif dari database
  let machines = [];
  try {
    const [rows] = await pool.execute(
      `SELECT nama, ip_address, device_id FROM device_mesin WHERE aktif = 1`
    );
    machines = rows.map(r => ({
      ip: r.ip_address,
      port: 4370,
      name: r.nama || r.device_id
    }));
  } catch (dbErr) {
    console.error('⚠️ [Sync] Gagal mengambil data mesin dari DB:', dbErr.message);
  }

  // Jika tidak ada mesin terdaftar, kembalikan status
  if (machines.length === 0) {
    syncStatus.isSyncing = false;
    syncStatus.status = 'done';
    syncStatus.errorMsg = 'Tidak ada mesin aktif yang dikonfigurasi untuk TCP Pull.';
    broadcastProgress();
    return;
  }

  syncStatus.totalMachines = machines.length;
  broadcastProgress();

  const CONNECT_TIMEOUT = 10000;  // 10 detik batas timeout koneksi
  const RECV_TIMEOUT    = 180000; // 3 menit batas timeout unduh data

  // Looping untuk menarik data dari setiap mesin
  for (let idx = 0; idx < machines.length; idx++) {
    const machine = machines[idx];
    syncStatus.currentMachine = machine.name;
    syncStatus.currentMachineIndex = idx + 1;
    syncStatus.status = 'connecting';
    syncStatus.progress = 0;
    syncStatus.processedCount = 0;
    syncStatus.totalCount = 0;
    syncStatus.timeRemaining = null;
    broadcastProgress();

    console.log(`🔌 [Sync TCP] Menghubungkan ke ${machine.name} (${machine.ip}:${machine.port})...`);
    const zk = new ZKLib(machine.ip, machine.port, CONNECT_TIMEOUT, RECV_TIMEOUT);
    
    let logs = [];
    let machineSummary = {
      name: machine.name,
      ip: machine.ip,
      status: 'pending',
      downloaded: 0,
      inserted: 0,
      skipped: 0,
      errors: 0,
      errorMsg: null
    };

    try {
      await zk.createSocket();
      
      // Dynamic timeout patch
      if (zk.zklibTcp) {
        zk.zklibTcp.timeout = RECV_TIMEOUT;
        if (zk.zklibTcp.socket) {
          zk.zklibTcp.socket.setTimeout(RECV_TIMEOUT);
        }
      }

      syncStatus.status = 'downloading';
      broadcastProgress();

      const info = await zk.getInfo();
      machineSummary.downloaded = info.logCounts || 0;

      if (info.logCounts > 0) {
        // Nonaktifkan layar mesin sementara agar download aman & cepat
        try { await zk.disableDevice(); } catch (_) {}

        const result = await zk.getAttendances();
        logs = result.data || [];

        // Aktifkan kembali layar mesin
        try { await zk.enableDevice(); } catch (_) {}
      }

      await zk.disconnect();

      if (logs.length === 0) {
        machineSummary.status = 'success';
        machineSummary.note = 'Tidak ada log absensi di mesin';
        syncStatus.machineSummaries.push(machineSummary);
        continue;
      }

      // 2. Simpan logs ke database
      syncStatus.status = 'saving';
      syncStatus.totalCount = logs.length;
      broadcastProgress();

      let machineInserted = 0;
      let machineSkipped = 0;
      let machineErrors = 0;
      const startTime = Date.now();

      for (let i = 0; i < logs.length; i++) {
        const log = logs[i];
        try {
          const pin = log.deviceUserId ? String(log.deviceUserId).trim() : '';
          const rawWaktu = log.recordTime || log.attTime;
          const waktu = rawWaktu ? dayjs(rawWaktu).format('YYYY-MM-DD HH:mm:ss') : '';

          // Filter data sampah / tidak valid
          if (!pin || pin === '0' || !rawWaktu || dayjs(rawWaktu).year() < 2020) {
            machineSkipped++;
            continue;
          }

          // Map status numeric mesin ke text
          const statusMap = { 
            0: 'masuk', 1: 'pulang', 
            2: 'istirahat_keluar', 3: 'istirahat_masuk', 
            4: 'lembur_masuk', 5: 'lembur_pulang' 
          };
          const status = statusMap[log.inOutStatus] || 'masuk';

          // Cek duplikasi (toleransi 30 detik)
          const [dup] = await pool.execute(
            `SELECT id FROM absensi
              WHERE pin = ?
                AND waktu >= DATE_SUB(?, INTERVAL 30 SECOND)
                AND waktu <= DATE_ADD(?, INTERVAL 30 SECOND)
              LIMIT 1`,
            [pin, waktu, waktu]
          );

          if (dup.length > 0) {
            machineSkipped++;
            continue;
          }

          // Simpan ke database absensi
          await pool.execute(
            `INSERT INTO absensi (pin, waktu, status, ip_source, raw_data, created_at) 
             VALUES (?, ?, ?, ?, ?, NOW())`,
            [
              pin, 
              waktu, 
              status, 
              machine.ip, 
              JSON.stringify({ source: 'zk_pull_sync', machine: machine.name, verify: log.verifyMethod })
            ]
          );

          machineInserted++;

        } catch (itemErr) {
          machineErrors++;
          console.error(`❌ [Sync Item Error] PIN: ${log.deviceUserId} | Msg: ${itemErr.message}`);
        }

        // Hitung estimasi sisa waktu pemrosesan (Throttle info per 100 baris)
        if (i % 100 === 0 || i === logs.length - 1) {
          const elapsedMs = Date.now() - startTime;
          const avgTimePerRecord = elapsedMs / (i + 1);
          const remainingRecords = logs.length - (i + 1);
          const remainingMs = avgTimePerRecord * remainingRecords;

          let timeRemainingStr = 'Menghitung...';
          if (i > 10) {
            const remainingSecs = Math.round(remainingMs / 1000);
            timeRemainingStr = remainingSecs < 60 ? `${remainingSecs} detik` : `${Math.floor(remainingSecs / 60)} menit ${remainingSecs % 60} detik`;
          }

          syncStatus.processedCount = i + 1;
          syncStatus.progress = Math.round(((i + 1) / logs.length) * 100);
          syncStatus.timeRemaining = timeRemainingStr;
          broadcastProgress();
        }
      }

      machineSummary.status = 'success';
      machineSummary.inserted = machineInserted;
      machineSummary.skipped = machineSkipped;
      machineSummary.errors = machineErrors;

      syncStatus.inserted += machineInserted;
      syncStatus.skipped += machineSkipped;
      syncStatus.errors += machineErrors;
      syncStatus.machineSummaries.push(machineSummary);

      console.log(`✅ [Sync TCP] ${machine.name} selesai: +${machineInserted} disimpan, ${machineSkipped} dilewati.`);

    } catch (mErr) {
      const errMsg = mErr.err?.message || mErr.message || String(mErr);
      console.error(`❌ [Sync TCP Error] Gagal koneksi ke ${machine.name}:`, errMsg);
      
      machineSummary.status = 'error';
      machineSummary.errorMsg = errMsg;
      syncStatus.machineSummaries.push(machineSummary);
      
      syncStatus.errors += 1;
      broadcastProgress();

      try { await zk.disconnect(); } catch (_) {}
    }
  }

  // Selesai seluruh mesin
  syncStatus.isSyncing = false;
  syncStatus.status = 'done';
  syncStatus.progress = 100;
  syncStatus.timeRemaining = null;
  syncStatus.lastSync = {
    time: new Date(),
    inserted: syncStatus.inserted,
    skipped: syncStatus.skipped,
    errors: syncStatus.errors
  };

  broadcastProgress();
}

/**
 * POST /api/mesin/sync
 * Memicu sinkronisasi manual latar belakang
 */
async function startSync(req, res) {
  if (syncStatus.isSyncing) {
    return res.status(400).json({
      success: false,
      message: 'Proses sinkronisasi sedang berlangsung. Silakan tunggu.',
      data: syncStatus
    });
  }

  // Jalankan asinkronus (background job) agar respon HTTP cepat
  runSyncBackground().catch(err => {
    console.error('Fatal sync controller error:', err);
    syncStatus.isSyncing = false;
    syncStatus.status = 'error';
    syncStatus.errorMsg = err.message;
    broadcastProgress();
  });

  return res.status(200).json({
    success: true,
    message: 'Sinkronisasi mesin berhasil dijalankan di latar belakang.',
    data: syncStatus
  });
}

/**
 * GET /api/mesin/sync/status
 * Mengambil status sinkronisasi saat ini
 */
async function getSyncStatus(req, res) {
  return res.status(200).json({
    success: true,
    data: syncStatus
  });
}

module.exports = {
  startSync,
  getSyncStatus,
  runSyncBackground
};
