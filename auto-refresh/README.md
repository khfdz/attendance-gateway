# Auto Sync Mekari Agent Fingerprint (Talenta)

Solusi otomatisasi sinkronisasi absensi untuk aplikasi **Mekari Agent Fingerprint** yang dirancang untuk **Windows Server 24 Jam** maupun **PC Kantor / Laptop**.

---

## 📌 Pilihan Mode Penggunaan

Anda dapat memilih mode yang paling sesuai dengan kebutuhan:

### 1. Mode Server 24 Jam (Sangat Direkomendasikan untuk Server)
Khusus untuk Windows Server yang menyala 24 jam (baik fisik maupun VM / VPS).
* **Keunggulan**: Berjalan di akun `NT AUTHORITY\SYSTEM`. Tetap berjalan otomatis meski sesi **Remote Desktop (RDP) ditutup**, user **Log Off**, atau **Layar Terkunci**.
* **Interval**: Mendukung sinkronisasi realtime **Setiap 1 Menit**!
* **Cara Pasang**:
  1. Klik kanan [`install_task_server.bat`](file:///c:/Users/IT-HP/Documents/GitHub/auto-refresh/install_task_server.bat) -> Pilih **Run as Administrator**.
  2. Tekan **Enter** (Pilihan [1] default: **Setiap 1 Menit**).
  3. Uji coba manual: Jalankan [`run_now_server.bat`](file:///c:/Users/IT-HP/Documents/GitHub/auto-refresh/run_now_server.bat).
  4. Log riwayat: Tersimpan di [`sync_server_history.log`](file:///c:/Users/IT-HP/Documents/GitHub/auto-refresh/sync_server_history.log).

### 2. Mode Visual (GUI)
Untuk PC / Laptop kerja yang layarnya menyala dan pengguna ingin melihat status visual secara langsung.
* **Keunggulan**: Menampilkan jendela status berwarna dan notifikasi balon (*balloon toast*) di pojok layar setiap kali sinkronisasi berhasil.
* **Cara Pakai**:
  * Jalankan kapan saja dengan klik ganda [`run_gui.bat`](file:///c:/Users/IT-HP/Documents/GitHub/auto-refresh/run_gui.bat).
  * Jadwalkan otomatis: Jalankan [`install_task_gui.bat`](file:///c:/Users/IT-HP/Documents/GitHub/auto-refresh/install_task_gui.bat).
  * Log riwayat: Tersimpan di [`sync_gui_history.log`](file:///c:/Users/IT-HP/Documents/GitHub/auto-refresh/sync_gui_history.log).

---

## 💡 Parameter Sukses Sinkronisasi

Aplikasi Mekari Agent Fingerprint berkomunikasi secara lokal melalui port bawaan developer Mekari (`127.0.0.1:8081`):
* **Endpoint Pemicu**: `POST http://127.0.0.1:8081/sync` dengan payload Connection ID.
* **Respon Aplikasi**: `{"success": true, "data": {"message": "Sync in progress"}}`.
* **Pengiriman ke HRD**: Mesin Mekari secara otomatis mengunggah data absensi (*delta*) ke `https://canary-api.talenta.co/pro/automatic-fingerprint/new-import-attendance`.
* **Waktu Eksekusi**: Hanya **< 1 detik** (rata-rata 300 - 500 ms).

---

## 📁 Daftar File

| File | Fungsi |
|---|---|
| [`install_task_server.bat`](file:///c:/Users/IT-HP/Documents/GitHub/auto-refresh/install_task_server.bat) | Pasang jadwal otomatis di Server (Akun SYSTEM, 24/7 non-stop, interval 1 menit). |
| [`run_now_server.bat`](file:///c:/Users/IT-HP/Documents/GitHub/auto-refresh/run_now_server.bat) | Tes jalankan sinkronisasi server sekarang juga. |
| [`sync_mekari_server.ps1`](file:///c:/Users/IT-HP/Documents/GitHub/auto-refresh/sync_mekari_server.ps1) | Script PowerShell utama untuk Server. |
| [`install_task_gui.bat`](file:///c:/Users/IT-HP/Documents/GitHub/auto-refresh/install_task_gui.bat) | Pasang jadwal sinkronisasi mode visual di PC/Laptop. |
| [`run_gui.bat`](file:///c:/Users/IT-HP/Documents/GitHub/auto-refresh/run_gui.bat) | Jalankan sinkronisasi dengan tampilan GUI visual sekarang. |
| [`sync_mekari_gui.ps1`](file:///c:/Users/IT-HP/Documents/GitHub/auto-refresh/sync_mekari_gui.ps1) | Script PowerShell mode tampilan visual dan notifikasi. |
| [`uninstall_task.bat`](file:///c:/Users/IT-HP/Documents/GitHub/auto-refresh/uninstall_task.bat) | Menghapus semua jadwal Task Scheduler yang pernah dibuat. |
