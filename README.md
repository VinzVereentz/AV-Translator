# AV Translator

Android Flutter app untuk menerjemahkan subtitle Jepang ke Bahasa Indonesia menggunakan Google ML Kit On-Device Translation.

## Fitur v1
- Pilih subtitle `.srt` atau `.vtt` dari HP.
- Terjemahkan Jepang -> Indonesia di perangkat.
- Model bahasa diunduh sekali saat pertama kali digunakan.
- Preview subtitle.
- Simpan hasil sebagai `_ID.srt`.
- UI hitam-merah modern dengan logo AV Translator.

## Build tanpa PC
1. Upload seluruh isi folder ini ke repository GitHub baru.
2. Buka tab **Actions**.
3. Jalankan **Build AV Translator APK**.
4. Setelah selesai, buka hasil workflow dan download artifact **AV-Translator-APK**.
5. Ekstrak APK dan instal di HP Android.

## Catatan
ML Kit Translation mendukung bahasa Jepang (`ja`) dan Indonesia (`id`). Model terjemahan diunduh secara dinamis dan pemrosesan teks dilakukan di perangkat setelah model tersedia.
