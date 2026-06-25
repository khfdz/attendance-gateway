const { pool } = require('../config/database');

// GET /api/devices
async function getDevices(req, res) {
  try {
    const [rows] = await pool.query('SELECT * FROM device_mesin ORDER BY id DESC');
    return res.json({ success: true, data: rows });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
}

// POST /api/devices
async function createDevice(req, res) {
  try {
    const { device_id, nama, ip_address, lokasi, aktif = 1 } = req.body;
    if (!device_id || !nama || !ip_address) {
      return res.status(400).json({ success: false, message: 'device_id, nama, and ip_address are required' });
    }
    
    await pool.execute(
      `INSERT INTO device_mesin (device_id, nama, ip_address, lokasi, aktif) 
       VALUES (?, ?, ?, ?, ?)`,
      [device_id, nama, ip_address, lokasi || null, aktif]
    );

    return res.json({ success: true, message: 'Device added successfully' });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
}

// PUT /api/devices/:id
async function updateDevice(req, res) {
  try {
    const { id } = req.params;
    const { device_id, nama, ip_address, lokasi, aktif } = req.body;
    
    await pool.execute(
      `UPDATE device_mesin 
       SET device_id = ?, nama = ?, ip_address = ?, lokasi = ?, aktif = ? 
       WHERE id = ?`,
      [device_id, nama, ip_address, lokasi || null, aktif, id]
    );

    return res.json({ success: true, message: 'Device updated successfully' });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
}

// DELETE /api/devices/:id
async function deleteDevice(req, res) {
  try {
    const { id } = req.params;
    await pool.execute('DELETE FROM device_mesin WHERE id = ?', [id]);
    return res.json({ success: true, message: 'Device deleted successfully' });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
}

module.exports = {
  getDevices,
  createDevice,
  updateDevice,
  deleteDevice
};
