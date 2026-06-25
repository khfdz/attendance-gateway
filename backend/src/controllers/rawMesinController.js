const { pool } = require('../config/database');
const { getIO } = require('../config/socket');
const { parseAbsensiData } = require('../utils/parser');
const dayjs = require('dayjs');

// Helper: Format tanggal untuk database MySQL (YYYY-MM-DD HH:mm:ss)
function formatDbDate(date) {
  return dayjs(date).format('YYYY-MM-DD HH:mm:ss');
}

/**
 * POST/GET /iclock/cdata atau /
 * Endpoint penerima data otomatis dari mesin X100C Solution / ZKTeco dengan ADMS aktif
 */
async function receivePushMesin(req, res) {
  const ip          = req.ip || req.headers['x-forwarded-for'] || 'unknown';
  const method      = req.method;
  const contentType = req.headers['content-type'] || '';
  const rawBody     = req.rawBody || '';
  const parsedBody  = req.body || {};
  const queryParams = req.query || {};

  let rawLogId = null;

  try {
    // 1. Simpan raw log mentah (audit log / backup)
    const [rawInsert] = await pool.execute(
      `INSERT INTO raw_mesin_log
         (ip_source, http_method, content_type, query_string,
          body_json, raw_body, receive_at)
       VALUES (?, ?, ?, ?, ?, ?, NOW())`,
      [
        ip, method, contentType,
        JSON.stringify(queryParams),
        typeof parsedBody === 'object' ? JSON.stringify(parsedBody) : null,
        rawBody || null,
      ]
    );
    rawLogId = rawInsert.insertId;

    const sn   = queryParams.SN || queryParams.sn || queryParams.device_id || 'unknown';
    const path = req.path;

    // A. Handle 'getrequest' (Mesin meminta perintah dari server)
    if (path.includes('/getrequest')) {
      console.log(`📡 [ADMS] Polling GetRequest dari SN: ${sn} -> Respon OK (No Command)`);
      return res.status(200).send('OK');
    }

    // B. Handle 'devicecmd' (Mesin melaporkan hasil perintah server)
    if (path.includes('/devicecmd')) {
      console.log(`📡 [ADMS] DeviceCmd receipt dari SN: ${sn} -> Respon OK`);
      return res.status(200).send('OK');
    }

    // C. Handle Sinkronisasi Opsi (Pertama kali koneksi / Handshake)
    if (queryParams.options === 'all') {
      const serverTime = dayjs().format('YYYY-MM-DD HH:mm:ss');
      console.log(`📡 [ADMS] Sinkronisasi opsi untuk SN: ${sn} | Time: ${serverTime}`);
      
      return res.status(200).send(
        `GET OPTION FROM: ${sn}\r\n` +
        `Stamp=9999\r\n` +
        `OpStamp=9999\r\n` +
        `ErrorDelay=60\r\n` +
        `Delay=30\r\n` +
        `TransTimes=00:00;14:00\r\n` +
        `TransInterval=1\r\n` +
        `TransFlag=1111111111\r\n` +
        `TimeZone=7\r\n` +
        `Realtime=1\r\n` +
        `ServerTime=${serverTime}\r\n`
      );
    }

    // 2. Parse data menggunakan utilitas parser
    const records = parseAbsensiData(req);

    if (!records || records.length === 0) {
      await pool.execute(
        `UPDATE raw_mesin_log SET parse_status = 'no_pin' WHERE id = ?`,
        [rawLogId]
      );
      return res.status(200).send('OK');
    }

    let savedCount     = 0;
    let duplicateCount = 0;
    let lastAbsensiId  = null;

    // 3. Proses penyimpanan record log absensi
    for (const record of records) {
      try {
        const pin = String(record.pin).trim();
        const waktu = record.waktu || new Date();
        const status = record.status || 'masuk';
        const formattedWaktu = formatDbDate(waktu);

        // Validasi data kosong
        if (!pin || pin === '0') continue;

        // Cek duplikasi di DB lokal (toleransi 30 detik untuk pin & waktu yang berdekatan)
        const [dup] = await pool.execute(
          `SELECT id FROM absensi
            WHERE pin = ?
              AND waktu >= DATE_SUB(?, INTERVAL 30 SECOND)
              AND waktu <= DATE_ADD(?, INTERVAL 30 SECOND)
            LIMIT 1`,
          [pin, formattedWaktu, formattedWaktu]
        );

        if (dup.length > 0) {
          duplicateCount++;
          lastAbsensiId = dup[0].id;
          console.log(`ℹ️ [ADMS SKIP] Duplikat terdeteksi - PIN: ${pin} | Waktu: ${formattedWaktu}`);
          continue;
        }

        // Simpan ke tabel absensi
        const [insertResult] = await pool.execute(
          `INSERT INTO absensi (pin, waktu, status, device_id, ip_source, raw_data, created_at)
           VALUES (?, ?, ?, ?, ?, ?, NOW())`,
          [
            pin,
            formattedWaktu,
            status,
            record.device_id || sn || null,
            ip,
            JSON.stringify({ raw_log_id: rawLogId, ...record.raw }),
          ]
        );

        savedCount++;
        lastAbsensiId = insertResult.insertId;

        // Broadcast data ke Client (Socket.io) secara real-time
        const io = getIO();
        if (io) {
          io.emit('absensi:baru', {
            id: lastAbsensiId,
            pin,
            waktu: formattedWaktu,
            status,
            device_id: record.device_id || sn || null,
            ip_source: ip,
            created_at: formatDbDate(new Date())
          });
        }

      } catch (innerErr) {
        console.error(`❌ Gagal menyimpan data absensi [Raw #${rawLogId}]:`, innerErr.message);
      }
    }

    // 4. Update status pemrosesan pada raw log
    await pool.execute(
      `UPDATE raw_mesin_log
          SET pin_extracted    = ?,
              waktu_extracted  = ?,
              status_extracted = ?,
              parse_status     = 'parsed',
              process_status   = ?,
              absensi_id       = ?
        WHERE id = ?`,
      [
        records[0].pin,
        formatDbDate(records[0].waktu || new Date()),
        records[0].status,
        savedCount > 0 ? 'done' : (duplicateCount > 0 ? 'duplicate' : 'pending'),
        lastAbsensiId,
        rawLogId,
      ]
    );

    console.log(`✅ [ADMS Raw-Log #${rawLogId}] Batch: ${savedCount} saved, ${duplicateCount} dup dari IP ${ip}`);
    
    // Kembalikan respon sukses standar ADMS agar mesin tahu data sukses diterima
    return res.status(200).send('OK');

  } catch (err) {
    console.error('❌ receivePushMesin error:', err.stack);
    if (rawLogId) {
      try {
        await pool.execute(
          `UPDATE raw_mesin_log
              SET parse_status = 'error',
                  process_status = 'error',
                  error_msg = ?
            WHERE id = ?`,
          [err.message, rawLogId]
        );
      } catch (_) {}
    }
    return res.status(200).send('OK');
  }
}

/**
 * GET /api/absensi
 * Mengambil daftar data absensi ter-parse untuk ditampilkan di frontend
 */
async function getAbsensiList(req, res) {
  try {
    const { startDate, endDate, pin, status, limit = 50, page = 1 } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);
    
    const params = [];
    let where = 'WHERE 1=1';

    if (startDate) { where += ' AND DATE(waktu) >= ?'; params.push(startDate); }
    if (endDate)   { where += ' AND DATE(waktu) <= ?'; params.push(endDate); }
    if (pin)       { where += ' AND pin LIKE ?'; params.push(`%${pin}%`); }
    if (status && status !== 'all') { where += ' AND status = ?'; params.push(status); }

    const [rows] = await pool.query(
      `SELECT id, pin, waktu, status, device_id, ip_source, created_at 
       FROM absensi 
       ${where} 
       ORDER BY waktu DESC 
       LIMIT ${parseInt(limit)} OFFSET ${offset}`,
      params
    );

    const [[{ total }]] = await pool.query(
      `SELECT COUNT(*) as total FROM absensi ${where}`,
      params
    );

    return res.json({
      success: true,
      data: rows.map(r => ({
        ...r,
        waktu: dayjs(r.waktu).format('YYYY-MM-DD HH:mm:ss'),
        created_at: dayjs(r.created_at).format('YYYY-MM-DD HH:mm:ss'),
      })),
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        total_pages: Math.ceil(total / parseInt(limit))
      }
    });
  } catch (err) {
    console.error('❌ getAbsensiList error:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
}

/**
 * GET /api/raw-logs
 * Mengambil log mentah untuk audit debug
 */
async function getRawLogs(req, res) {
  try {
    const [rows] = await pool.query(
      `SELECT id, ip_source, http_method, parse_status, process_status, error_msg, receive_at 
       FROM raw_mesin_log 
       ORDER BY id DESC 
       LIMIT 100`
    );
    return res.json({ success: true, data: rows });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
}

module.exports = {
  receivePushMesin,
  getAbsensiList,
  getRawLogs
};
