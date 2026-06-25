require('dotenv').config();

const express    = require('express');
const http       = require('http');
const { Server } = require('socket.io');
const bodyParser = require('body-parser');
const cors       = require('cors');
const morgan     = require('morgan');
const cron       = require('node-cron');

const { testConnection }    = require('./src/config/database');
const { setIO }             = require('./src/config/socket');
const routes                = require('./src/routes/mesinRoutes');
const { rawBodySaver, requestLogger, errorHandler } = require('./src/middleware');
const { runSyncBackground } = require('./src/controllers/syncController');

const app        = express();
const httpServer = http.createServer(app);

// ============================================================
// SOCKET.IO & CORS INITIALIZATION
// ============================================================
const allowedOrigins = (process.env.ALLOWED_ORIGINS || 'http://localhost:3000,http://localhost:5173')
  .split(',').map(o => o.trim());

const io = new Server(httpServer, {
  cors: { 
    origin: allowedOrigins, 
    methods: ['GET', 'POST'], 
    credentials: true 
  },
  transports: ['websocket', 'polling'],
});
setIO(io);

// ============================================================
// GLOBAL MIDDLEWARES
// ============================================================
app.use(cors({
  origin: (origin, cb) => {
    if (!origin) return cb(null, true);
    const normalized = origin.replace(/\/$/, "");
    if (allowedOrigins.includes(normalized) || normalized.includes('localhost') || normalized.includes('127.0.0.1')) {
      return cb(null, true);
    }
    return cb(null, true); // Toleran untuk dev lokal subnet
  },
  credentials: true
}));

app.use(morgan('dev'));
app.use(requestLogger);

// Body Parser dengan rawBodySaver (urutan sangat penting!)
app.use(bodyParser.json({ limit: '10mb', verify: rawBodySaver }));
app.use(bodyParser.urlencoded({ extended: true, limit: '10mb', verify: rawBodySaver }));
app.use(bodyParser.text({ type: '*/*', limit: '10mb', verify: rawBodySaver }));

// ============================================================
// SYSTEM ROUTES
// ============================================================

// Sajikan dashboard frontend dari folder public/
app.use(express.static('public'));

// Arahkan semua endpoint (root, iclock, dll) ke router mesin
app.use('/', routes);

// Simple Health check
app.get('/health', (req, res) => {
  res.json({ status: 'OK', uptime: process.uptime(), time: new Date().toISOString() });
});

// Handling 404 Route
app.use((req, res) => {
  res.status(404).json({ success: false, message: `Rute ${req.method} ${req.path} tidak ditemukan` });
});

app.use(errorHandler);

// ============================================================
// SOCKET.IO EVENT HANDLER
// ============================================================
io.on('connection', (socket) => {
  console.log(`🔌 Client Socket Terhubung: ${socket.id}`);
  
  socket.on('disconnect', () => {
    console.log(`🔌 Client Socket Terputus: ${socket.id}`);
  });
});

// ============================================================
// AUTO-SYNC SCHEDULER (node-cron)
// Jalankan sinkronisasi pull TCP otomatis setiap 5 menit
// ============================================================
cron.schedule('*/5 * * * *', async () => {
  const now = new Date().toISOString();
  console.log(`\n⏰ [Cron Auto-Sync] Memulai sinkronisasi TCP otomatis... (${now})`);
  try {
    await runSyncBackground();
    console.log('✅ [Cron Auto-Sync] Sinkronisasi selesai.');
  } catch (err) {
    console.error('❌ [Cron Auto-Sync] Gagal:', err.message);
  }
});

// ============================================================
// SERVER STARTUP
// ============================================================
const HOST = process.env.HOST || '0.0.0.0';
const PORT = parseInt(process.env.PORT) || 6032;

async function startServer() {
  const dbOk = await testConnection();
  if (!dbOk) {
    console.warn('⚠️ Server tetap berjalan tetapi koneksi MySQL GAGAL. Harap buat database sesuai schema.sql dan cek file .env');
  }

  httpServer.listen(PORT, HOST, () => {
    console.log('\n🚀 ======================================================');
    console.log(`   ABSENSI CORE SERVICE IS RUNNING!`);
    console.log(`   Host Server   : ${HOST}`);
    console.log(`   Port Server   : ${PORT}`);
    console.log(`   API Endpoint  : http://${HOST}:${PORT}/api/absensi`);
    console.log(`   ADMS Push URL : Arahkan ADMS mesin ke IP PC ini port ${PORT}`);
    console.log(`   ======================================================\n`);
  });
}

startServer();
