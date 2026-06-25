# Attendance Gateway (ADMS Push & TCP Pull Boilerplate)

Project boilerplate ini dirancang khusus untuk integrasi mesin absensi fisik (Solution X100C / ZKTeco) ke database MySQL dan menampilkannya di dashboard web secara real-time. Project ini berfokus **hanya** pada bagian inti komunikasi mesin absensi dan terpisah dari logika bisnis lainnya.

### 🔑 Kredensial Login Default
* **Username**: `khfdz`
* **Password**: `121212`

## 🚀 Fitur Utama
1. **ADMS Push Mode (Real-Time)**: Menerima data secara otomatis seketika setelah scan dilakukan oleh karyawan di mesin.
2. **TCP Pull Mode (Scheduled/Manual)**: Menarik data log langsung dari memori mesin menggunakan protokol TCP port `4370`.
3. **Real-Time Dashboard**: Antarmuka web modern dengan update data real-time menggunakan **Socket.io** tanpa perlu memuat ulang halaman.
4. **Device Management**: Kelola IP address, nama mesin, dan status sinkronisasi.

---

## 📁 Struktur Direktori
```text
absensi-core-template/
├── backend/
│   ├── database/
│   │   └── schema.sql       # Skema database MySQL (3 tabel utama)
│   ├── public/
│   │   └── index.html       # Single Page Application Dashboard (React/Tailwind)
│   ├── src/
│   │   ├── config/
│   │   │   ├── database.js  # Koneksi MySQL Pool
│   │   │   └── socket.js    # Konfigurasi Socket.io
│   │   ├── controllers/
│   │   │   ├── deviceController.js    # CRUD Data Mesin
│   │   │   ├── rawMesinController.js  # Receiver ADMS & Query API
│   │   │   └── syncController.js      # TCP Pull via node-zklib
│   │   ├── middleware/
│   │   │   └── index.js      # Logger & Raw Body Saver
│   │   ├── routes/
│   │   │   └── mesinRoutes.js # Routing API & ADMS
│   │   └── utils/
│   │       └── parser.js     # Parser data ADMS mentah
│   ├── .env                 # File environment (Konfigurasi Port & DB)
│   ├── package.json         # Dependensi backend
│   └── server.js            # Entrypoint backend & Scheduler Cron
└── README.md                # Dokumentasi ini
```

---

## 🛠️ Cara Instalasi & Penggunaan

### 1. Prasyarat
* Node.js versi 16 ke atas terinstal di komputer.
* MySQL Server (XAMPP / Docker / Standalone) berjalan.

### 2. Setup Database
1. Buat database baru di MySQL dengan nama `db_absensi_core`.
2. Import skema tabel menggunakan file [backend/database/schema.sql](file:///c:/Users/IT-HP/Documents/GitHub/absensi-rspkrw/absensi-core-template/backend/database/schema.sql).

### 3. Setup Backend
1. Buka folder `backend` melalui terminal.
2. Instal dependensi:
   ```bash
   npm install
   ```
3. Sesuaikan konfigurasi database Anda di dalam file `.env`.
4. Jalankan server:
   * **Mode Development (Auto-Reload)**:
     ```bash
     npm run dev
     ```
   * **Mode Production**:
     ```bash
     npm start
     ```

### 4. Akses Dashboard
Buka browser Anda dan akses:
```text
http://localhost:6032
```
Anda akan melihat dashboard real-time. Anda bisa menambahkan IP mesin absensi baru pada menu **Mesin Absensi (TCP)** dan melakukan uji penarikan data secara manual atau otomatis.

---

## 📡 Cara Menghubungkan Mesin Absensi Fisik

### Opsi A: Mode ADMS Push (Sangat Direkomendasikan)
Mesin akan mengirim data secara otomatis setiap ada scan baru tanpa membebani server.
1. Masuk ke **Menu Utama Mesin** -> **Comm (Komunikasi)** -> **ADMS** / **Cloud Server**.
2. Atur konfigurasi berikut:
   * **Server IP / Address**: IP komputer server tempat aplikasi ini berjalan (misalnya `192.168.1.100`).
   * **Server Port**: `6032` (port aplikasi backend ini).
   * **Enable Proxy**: **Off** (Nonaktif).
3. Setelah terhubung, pastikan indikator ADMS/Bola Dunia di layar utama mesin berwarna hijau.

### Opsi B: Mode TCP Pull (Default untuk Mesin Standalone)
Aplikasi backend akan secara berkala (setiap 5 menit via `cron`) menarik data log dari memori mesin.
1. Daftarkan mesin di dashboard web (Menu **Mesin Absensi** -> **Daftarkan Mesin**).
2. Isi kolom **IP Address** dengan IP mesin absensi fisik (misal: `192.168.1.201`).
3. Pastikan port TCP `4370` pada mesin absensi terbuka dan tidak terhalang firewall router.
