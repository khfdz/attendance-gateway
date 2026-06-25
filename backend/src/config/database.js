require('dotenv').config();
const mysql = require('mysql2/promise');

// Pool Koneksi MySQL Utama
const pool = mysql.createPool({
  host:             process.env.DB_HOST || '127.0.0.1',
  port:             parseInt(process.env.DB_PORT) || 3306,
  user:             process.env.DB_USER || 'root',
  password:         process.env.DB_PASS || '',
  database:         process.env.DB_NAME || 'db_absensi_core',
  waitForConnections: true,
  connectionLimit:  10,
  queueLimit:       0,
  timezone:         '+07:00',
  charset:          'utf8mb4',
  connectTimeout:   10000,
});

async function testConnection() {
  try {
    const conn = await pool.getConnection();
    console.log(`\n✅ Database MySQL Terhubung: ${process.env.DB_HOST}:${process.env.DB_PORT || 3306} → ${process.env.DB_NAME}`);
    conn.release();
    return true;
  } catch (err) {
    console.error(`\n❌ Gagal Menghubungkan ke MySQL (${process.env.DB_HOST}:${process.env.DB_PORT || 3306}):`, err.message);
    return false;
  }
}

module.exports = { pool, testConnection };
