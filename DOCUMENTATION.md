# Dokumentasi Lengkap: Attendance Gateway

**Attendance Gateway** adalah boilerplate integrasi mesin absensi fisik (Solution X100C / ZKTeco) yang ringan, mandiri, dan berfokus sepenuhnya pada komunikasi penarikan data log absensi. Aplikasi ini mendukung pengiriman otomatis real-time (ADMS Push) serta penarikan data manual/penjadwalan berkala via TCP/IP (Pull).

---

## 📋 Persyaratan Sistem & Persiapan

Sebelum memulai instalasi, pastikan sistem Anda sudah menyiapkan komponen berikut:

1. **Node.js**: Versi `16.x` atau lebih baru terinstal di komputer/server Anda ([Unduh Node.js](https://nodejs.org/)).
2. **Database Server**: **MySQL** atau **MariaDB** berjalan (bisa melalui XAMPP, Laragon, Docker, atau instalasi standalone).
3. **Mesin Absensi Fisik**: Solution X100C atau tipe ZKTeco lain yang terhubung ke jaringan lokal (LAN/Wi-Fi) yang sama dengan server.
4. **Jaringan**: Pastikan port TCP **`4370`** (port default ZKTeco) dan port backend **`6032`** tidak diblokir oleh firewall router atau Windows Defender.

---

## 🛠️ Langkah-Langkah Instalasi

### Langkah 1: Setup Database MySQL
1. Buka tool administrasi database Anda (seperti **phpMyAdmin**, **HeidiSQL**, atau **DBeaver**).
2. Buat database baru dengan nama:
   ```sql
   CREATE DATABASE db_attendance_gateway CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   ```
3. Import atau jalankan script SQL yang disediakan di file:
   📄 [backend/database/schema.sql](file:///c:/Users/IT-HP/Documents/GitHub/absensi-rspkrw/absensi-core-template/backend/database/schema.sql)
   *(Script ini akan otomatis membuat tabel `device_mesin`, `absensi`, dan `raw_mesin_log`)*

### Langkah 2: Instalasi Dependensi Backend
1. Buka terminal (CMD / PowerShell / Bash) lalu masuk ke direktori backend project:
   ```bash
   cd absensi-core-template/backend
   ```
2. Instal semua modul Node.js yang diperlukan:
   ```bash
   npm install
   ```

### Langkah 3: Konfigurasi Environment (`.env`)
Buka file `.env` di dalam folder `backend/` dan sesuaikan kredensial database MySQL Anda jika berbeda dari default:
```env
# Port aplikasi server
PORT=6032

# Kredensial Database
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASS=
DB_NAME=db_attendance_gateway

# Log level
LOG_LEVEL=debug
```

---

## 🚀 Cara Menjalankan Aplikasi

### A. Mode Development (Menggunakan Nodemon)
Server otomatis memuat ulang (auto-restart) jika Anda membuat perubahan pada kode program:
```bash
npm run dev
```

### B. Mode Production (Node.js Biasa)
```bash
npm start
```

### C. Mode Service Background (Menggunakan PM2 - Direkomendasikan)
Agar aplikasi tetap berjalan di background secara otomatis meskipun terminal ditutup:
1. Instal PM2 secara global (jika belum):
   ```bash
   npm install -g pm2
   ```
2. Jalankan aplikasi menggunakan PM2:
   ```bash
   pm2 start server.js --name "attendance-gateway"
   ```
3. Simpan konfigurasi PM2 agar otomatis berjalan saat komputer/server restart:
   ```bash
   pm2 save
   pm2 startup
   ```

---

## 💻 Cara Mengakses Dashboard Frontend

Setelah server backend berhasil dijalankan (mempunyai log `ABSENSI CORE SERVICE IS RUNNING!`), buka browser Anda dan akses alamat berikut:

👉 **[http://localhost:6032](http://localhost:6032)**

### 🔑 Kredensial Login Default
* **Username**: `khfdz`
* **Password**: `121212`

*(Anda dapat masuk menggunakan kredensial di atas untuk mengakses dashboard utama).*

---

## 📡 Konfigurasi Koneksi ke Mesin Absensi Fisik

Terdapat dua skenario koneksi yang didukung oleh Attendance Gateway:

### Opsi A: Mode ADMS Push (Otomatis & Real-Time)
Mesin absensi akan mengirimkan data secara otomatis ke server sesaat setelah karyawan melakukan scan jari/kartu/wajah.
1. Masuk ke **Menu Utama Mesin Absensi** (Tekan tombol M/OK).
2. Pilih menu **Comm. (Komunikasi)** $\rightarrow$ **ADMS** / **Cloud Server**.
3. Sesuaikan pengaturan berikut:
   * **Server Address / IP**: IP komputer server tempat aplikasi ini berjalan (misalnya: `192.168.1.100`).
   * **Server Port**: `6032` (port backend aplikasi).
   * **Enable Proxy**: **Off** (Nonaktifkan).
   * **HTTPS**: **Off** (Jika Anda belum mengonfigurasi SSL di backend).
4. Tekan OK untuk menyimpan. Pastikan logo bola dunia di pojok kanan atas layar mesin menyala hijau.

### Opsi B: Mode TCP Pull (Manual & Terjadwal)
Server akan aktif menghubungi IP mesin absensi untuk mendownload log yang tersimpan di memori mesin.
1. Pastikan mesin absensi terhubung ke jaringan lokal dengan IP static (misal: `192.168.1.201`).
2. Masuk ke dashboard **Attendance Gateway** di browser.
3. Buka tab **Mesin Absensi (TCP)** $\rightarrow$ klik **Daftarkan Mesin**.
4. Isi data mesin:
   * **Serial Number/ID**: SN unik mesin (misal: `SN-MAIN-LOBBY`).
   * **Nama Mesin**: Nama lokasi mesin.
   * **IP Address**: IP address mesin (tanpa port).
5. Klik **Daftarkan Mesin**.
6. **Memicu Sinkronisasi**:
   * **Otomatis**: Scheduler backend akan otomatis mendownload log dari mesin setiap **5 menit sekali**.
   * **Manual**: Masuk ke tab **Tarik Data Manual** lalu klik tombol **Mulai Sinkronisasi Sekarang** untuk penarikan langsung di layar dengan indikator progres bar.
