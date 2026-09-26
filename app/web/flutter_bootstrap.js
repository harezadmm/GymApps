{{flutter_js}}
{{flutter_build_config}}

// Tanpa serviceWorkerSettings: service worker bawaan Flutter di versi ini
// hanya pekerja pembersih yang mencabut dirinya sendiri, dan karena ia
// mendaftar di scope yang sama dengan sw.js milik GymApps, pencabutan itu
// ikut menghapus langganan notifikasi istirahat. sw.js didaftarkan dari
// aplikasi (lib/core/web_push_web.dart).
_flutter.loader.load();
