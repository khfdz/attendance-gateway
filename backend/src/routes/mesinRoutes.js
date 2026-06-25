const express = require('express');
const router  = express.Router();

const {
  receivePushMesin,
  getAbsensiList,
  getRawLogs,
} = require('../controllers/rawMesinController');

const {
  startSync,
  getSyncStatus,
} = require('../controllers/syncController');

const {
  getDevices,
  createDevice,
  updateDevice,
  deleteDevice,
} = require('../controllers/deviceController');

// ============================================================
// 1. ENDPOINT ADMS PUSH (Dihit langsung oleh mesin absensi)
// ============================================================

// ADMS Basic (Firmware lama — biasanya ke root '/')
router.get('/', receivePushMesin);
router.post('/', receivePushMesin);

// ADMS Standard (Protokol IClock)
router.get('/iclock/cdata', receivePushMesin);
router.post('/iclock/cdata', receivePushMesin);
router.get('/iclock/getrequest', receivePushMesin);
router.post('/iclock/devicecmd', receivePushMesin);

// ADMS Custom Path (Jika diatur custom)
router.get('/mesin/push', receivePushMesin);
router.post('/mesin/push', receivePushMesin);

// ============================================================
// 2. ENDPOINT API UNTUK CONSUMER (FRONTEND / DASHBOARD)
// ============================================================

// List data absensi ter-parse
router.get('/api/absensi', getAbsensiList);

// List raw logs untuk debug audit
router.get('/api/raw-logs', getRawLogs);

// CRUD data mesin absensi
router.get('/api/devices', getDevices);
router.post('/api/devices', createDevice);
router.put('/api/devices/:id', updateDevice);
router.delete('/api/devices/:id', deleteDevice);

// TCP Pull Sync (Manual Trigger via Web)
router.post('/api/mesin/sync', startSync);
router.get('/api/mesin/sync/status', getSyncStatus);

module.exports = router;
