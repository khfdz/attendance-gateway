let _io = null;

function setIO(io) { 
  _io = io; 
}

function getIO() {
  return _io; // Kembalikan null jika belum terhubung
}

module.exports = { setIO, getIO };
