-- ============================================================
-- DATABASE: db_attendance_gateway
-- Charset : utf8mb4
-- Timezone: +07:00 (WIB)
-- ============================================================

CREATE DATABASE IF NOT EXISTS db_attendance_gateway
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE db_attendance_gateway;

-- ============================================================
-- TABEL: device_mesin
-- Menyimpan daftar IP dan informasi mesin absensi
-- ============================================================
CREATE TABLE IF NOT EXISTS device_mesin (
  id         INT UNSIGNED    AUTO_INCREMENT PRIMARY KEY,
  device_id  VARCHAR(50)     NOT NULL UNIQUE COMMENT 'Serial number atau ID unik mesin',
  nama       VARCHAR(100)    NOT NULL COMMENT 'Nama alias lokasi mesin',
  ip_address VARCHAR(45)     NOT NULL COMMENT 'IP Address mesin (untuk TCP Pull)',
  lokasi     VARCHAR(100)    NULL,
  aktif      TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '1 = Aktif, 0 = Nonaktif',
  last_seen  TIMESTAMP       NULL,
  created_at TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABEL: absensi (Tabel log kehadiran yang ter-parse rapi)
-- ============================================================
CREATE TABLE IF NOT EXISTS absensi (
  id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  pin        VARCHAR(50)     NOT NULL COMMENT 'ID Karyawan / PIN dari mesin',
  waktu      DATETIME        NOT NULL COMMENT 'Waktu scan tap',
  status     VARCHAR(30)     NOT NULL DEFAULT 'masuk' COMMENT 'masuk, pulang, dll',
  device_id  VARCHAR(50)     NULL COMMENT 'Serial Number mesin pengirim',
  ip_source  VARCHAR(45)     NULL COMMENT 'IP Source pengirim request',
  raw_data   JSON            NULL COMMENT 'Data mentah JSON untuk audit trail',
  created_at TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

  INDEX idx_pin       (pin),
  INDEX idx_waktu     (waktu),
  INDEX idx_status    (status),
  INDEX idx_device    (device_id),
  INDEX idx_created   (created_at),
  INDEX idx_date_pin  (pin, waktu)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABEL: raw_mesin_log
-- Menyimpan record audit mentah dari setiap HTTP request ADMS.
-- Berguna untuk debugging jika terjadi kegagalan parsing.
-- ============================================================
CREATE TABLE IF NOT EXISTS raw_mesin_log (
  id               BIGINT UNSIGNED  AUTO_INCREMENT PRIMARY KEY,
  ip_source        VARCHAR(45)      NULL COMMENT 'IP mesin pengirim',
  http_method      VARCHAR(10)      NULL COMMENT 'GET / POST',
  content_type     VARCHAR(150)     NULL COMMENT 'Content-Type header',
  query_string     TEXT             NULL COMMENT 'URL query params (JSON)',
  body_json        JSON             NULL COMMENT 'Body jika sudah terparsing',
  raw_body         TEXT             NULL COMMENT 'Raw body bytes asli dari mesin',
  pin_extracted    VARCHAR(50)      NULL COMMENT 'PIN hasil parse',
  waktu_extracted  DATETIME         NULL COMMENT 'Waktu scan hasil parse',
  status_extracted VARCHAR(30)      NULL COMMENT 'Status hasil parse',
  device_sn        VARCHAR(50)      NULL COMMENT 'Serial number mesin',
  parse_status     ENUM('parsed', 'no_pin', 'error') NOT NULL DEFAULT 'parsed',
  process_status   ENUM('pending', 'done', 'duplicate', 'error') NOT NULL DEFAULT 'pending',
  error_msg        TEXT             NULL,
  absensi_id       BIGINT UNSIGNED  NULL COMMENT 'FK ke tabel absensi jika sukses simpan',
  receive_at       DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,

  INDEX idx_rml_pin        (pin_extracted),
  INDEX idx_rml_device     (device_sn),
  INDEX idx_rml_receive    (receive_at),
  INDEX idx_rml_parse      (parse_status),
  INDEX idx_rml_process    (process_status),
  INDEX idx_rml_absensi    (absensi_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Raw log ADMS push request dari mesin absensi';

-- ============================================================
-- SEED DATA: Contoh 1 Mesin Absensi
-- ============================================================
INSERT IGNORE INTO device_mesin (device_id, nama, ip_address, lokasi)
VALUES ('X100C-BOILERPLATE', 'Mesin Demo Utama', '192.168.1.201', 'Lobby Kantor');
