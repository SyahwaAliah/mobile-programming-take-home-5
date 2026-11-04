# 🎵 Music Player - Tugas 5 Mobprog (API & Networking)

Aplikasi pemutar musik berbasis Flutter yang mengambil data lagu dari **iTunes Search API**. Pengguna bisa mencari lagu, memutar preview 30 detik, menyimpan lagu favorit, membuat playlist sendiri, dan melihat riwayat putar.

- **Nama:** Syahwa Aliah Wandi
- **NIM:** 825240139
- **Program Studi:** Sistem Informasi
- **Kampus:** Universitas Tarumanagara
- **Mata Kuliah:** Mobile Programming

---

## ✨ Fitur

### Fitur Utama (API & Networking)
- **Pencarian lagu** berdasarkan judul atau nama artis lewat iTunes Search API.
- **Loading state** (progress bar) saat data sedang diambil.
- **Error state** untuk koneksi gagal, server error, dan hasil kosong.
- **Pemutaran audio** preview 30 detik dengan kontrol play/pause, next, previous, dan seek.

### Fitur Tambahan
- **Mini player** di bagian bawah yang tampil di semua halaman (termasuk detail playlist).
- **Halaman player penuh** dengan artwork, slider durasi, dan gradient tema.
- **Shuffle** dan **Repeat** (off / semua lagu / satu lagu).
- **Favorit**: simpan lagu dengan ikon hati (tersimpan permanen).
- **Playlist**:
  - Buat playlist baru lewat tombol **+** di AppBar tab Playlist.
  - Tambah lagu ke playlist lewat ikon **playlist_add** di daftar lagu atau di player penuh, termasuk membuat playlist baru langsung dari menu tersebut.
  - Ubah nama dan hapus playlist (dengan dialog konfirmasi).
  - Halaman detail playlist dengan tombol **Putar Semua** dan hapus lagu dari playlist.
  - Cover playlist otomatis memakai artwork lagu pertama.
  - Lagu yang sama tidak bisa ditambahkan dua kali ke playlist yang sama.
- **Riwayat putar**: maksimal 30 lagu terakhir, bisa dihapus.
- **Profil**: ubah nama, statistik favorit/playlist/riwayat, dan 3 lagu terakhir diputar.
- **Penyimpanan lokal** dengan `shared_preferences` (favorit, riwayat, playlist, dan nama) sehingga data tidak hilang saat aplikasi ditutup.
- **Animasi transisi**: fade/slide pada daftar, hero artwork, dan player yang naik dari bawah.
- **Tema gelap** dengan palet warna merah tua dan abu gelap.

---

## 🌐 API yang Digunakan

**iTunes Search API** (tanpa API key)

```
GET https://itunes.apple.com/search?term={kata_kunci}&entity=song&limit=25
```

| Parameter | Keterangan |
|-----------|------------|
| `term`    | Kata kunci pencarian (judul / artis) |
| `entity`  | `song` |
| `limit`   | Jumlah hasil maksimal (25) |

### Alur Parsing JSON
1. Request dikirim memakai package `http`.
2. Status code dicek: jika `200` data diproses, jika selain itu ditampilkan pesan `Server error (kode)`.
3. Body di-decode dengan `jsonDecode`, lalu field `results` diubah menjadi `List<Song>` lewat `Song.fromItunes()`.
4. Lagu tanpa `previewUrl` otomatis dibuang.
5. Semua proses dibungkus `try-catch` untuk menangani gagal koneksi.

### Model Data

**`Song`**

| Field | Sumber JSON |
|-------|-------------|
| `id` | `trackId` |
| `title` | `trackName` |
| `artist` | `artistName` |
| `album` | `collectionName` |
| `artwork` | `artworkUrl100` (diubah ke ukuran 400x400) |
| `previewUrl` | `previewUrl` |

**`Playlist`**

| Field | Keterangan |
|-------|------------|
| `id` | ID unik (dari timestamp saat dibuat) |
| `name` | Nama playlist |
| `songs` | Daftar `Song` di dalam playlist |

Kedua model punya `toJson()` dan `fromJson()` untuk menyimpan data secara lokal.

### Penyimpanan Lokal (`shared_preferences`)

| Key | Isi |
|-----|-----|
| `favorites` | Daftar lagu favorit (JSON) |
| `history` | Riwayat putar, maksimal 30 lagu (JSON) |
| `playlists` | Daftar playlist beserta lagunya (JSON) |
| `name` | Nama pengguna |

---

## 🧱 Struktur Kode

Seluruh kode berada di `lib/main.dart` dan dibagi dengan bagian-bagian berikut:

| Bagian | Fungsi |
|--------|--------|
| Palet warna | Konstanta warna tema |
| `MusicApp` | Konfigurasi `MaterialApp` dan tema |
| `Song` | Model data lagu + parsing JSON |
| `Playlist` | Model data playlist + konversi JSON |
| `PlayerController` | State management (`ChangeNotifier`): audio, antrian, favorit, riwayat, playlist, profil |
| Helper dialog & sheet | `showNameDialog` dan `showAddToPlaylistSheet` |
| `HomeShell` | Navigasi bawah (5 tab) + mini player |
| `SongTile` | Item lagu yang dipakai ulang (tombol tambah ke playlist / hapus dari playlist, favorit) |
| `SearchPage` | Halaman cari + request API |
| `SongListPage` | Halaman Favorit dan Riwayat (dipakai ulang) |
| `PlaylistPage` | Daftar playlist, ubah nama, hapus |
| `PlaylistDetailPage` | Isi playlist, putar semua, hapus lagu dari playlist |
| `ProfilePage` | Halaman profil |
| `MiniPlayer` / `PlayerPage` | Pemutar mini dan pemutar penuh |

---

## 🚀 Cara Menjalankan

1. Clone repository
   ```bash
   git clone https://github.com/SyahwaAliah/mobile-programming-take-home-5.git
   cd D:\Semester 5\Moprog\pertemuan 11 b
   ```
2. Install dependencies
   ```bash
   flutter pub get
   ```
3. Jalankan aplikasi

   Di Android / emulator:
   ```bash
   flutter run
   ```
   Di web (bisa diakses dari perangkat lain di jaringan yang sama):
   ```bash
   flutter run -d web-server --web-port=8081 --web-hostname=0.0.0.0
   ```

---

## 📝 Catatan

- Audio yang diputar hanyalah **preview 30 detik** dari iTunes, bukan lagu penuh.
- Data lagu bersumber dari iTunes Search API milik Apple.
- Playlist tersimpan di penyimpanan lokal perangkat/browser, jadi tidak tersinkron antar perangkat.