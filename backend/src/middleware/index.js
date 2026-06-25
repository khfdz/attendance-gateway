// Middleware untuk menyimpan raw body byte mentah (penting untuk parsing ADMS text)
function rawBodySaver(req, res, buf, encoding) {
  if (buf && buf.length) {
    req.rawBody = buf.toString(encoding || 'utf8');
  }
}

// Logger sederhana untuk melacak incoming request dari mesin / client
function requestLogger(req, res, next) {
  const ip = req.ip || req.connection.remoteAddress;
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.originalUrl} | IP: ${ip} | CT: ${req.headers['content-type'] || '-'}`);
  next();
}

// Global Error Handler
function errorHandler(err, req, res, next) {
  console.error('❌ Server Error:', err.stack);
  // Selalu kembalikan respon OK (200) untuk request mesin agar tidak retry terus menerus
  if (req.path.includes('/iclock') || req.path === '/') {
    return res.status(200).send('OK');
  }
  return res.status(500).json({ success: false, message: 'Internal server error: ' + err.message });
}

module.exports = { rawBodySaver, requestLogger, errorHandler };
