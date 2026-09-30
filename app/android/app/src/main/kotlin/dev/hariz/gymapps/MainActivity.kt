package dev.hariz.gymapps

import android.annotation.TargetApi
import android.content.ContentResolver
import android.content.ContentUris
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.FileNotFoundException
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException

/**
 * Sisi Android cadangan harian ke folder Download (FR-A5, FR-A6; pasangannya
 * `lib/core/auto_backup.dart`).
 *
 * Lewat MediaStore, bukan `java.io.File`: sejak Android 10 aplikasi tidak
 * boleh menulis langsung ke /sdcard/Download, tapi lewat koleksi Download
 * publik berkas milik sendiri boleh ditulis, dibaca, dan dihapus tanpa izin
 * penyimpanan apa pun — dan berkasnya tetap ada setelah aplikasi dihapus.
 * Itulah gunanya cadangan ini. Di bawah Android 10 (NFR-9 hanya menjanjikan
 * 10 ke atas) semua metode menjawab "unsupported" dan tidak berbuat apa-apa.
 */
class MainActivity : FlutterActivity() {
    // Satu thread untuk semua I/O: query MediaStore dan penulisan ratusan KB
    // tidak boleh menahan thread utama, dan dua penulisan tidak boleh saling
    // mendahului. Jawaban dikirim balik lewat runOnUiThread karena
    // MethodChannel.Result hanya boleh dipanggil dari thread utama.
    private val io: ExecutorService = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            handle(call, result)
        }
    }

    override fun onDestroy() {
        io.shutdown()
        super.onDestroy()
    }

    /** Di thread utama: saring dulu, baru serahkan I/O-nya ke thread lain. */
    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method !in METHODS) {
            result.notImplemented()
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.success("unsupported")
            return
        }
        val downloads = Downloads(contentResolver)
        try {
            io.execute { perform(downloads, call, result) }
        } catch (e: RejectedExecutionException) {
            // Activity sudah ditutup selagi panggilan datang.
            result.error("closed", "activity sudah ditutup", null)
        }
    }

    /** Di thread I/O; jawabannya dikembalikan ke thread utama. */
    private fun perform(downloads: Downloads, call: MethodCall, result: MethodChannel.Result) {
        try {
            val value: Any = when (call.method) {
                "writeDownload" -> {
                    downloads.write(requireArg<String>(call, "name"), requireArg<ByteArray>(call, "bytes"))
                    "ok"
                }
                "listDownloads" -> downloads.list(call.argument<String>("prefix") ?: "")
                else -> {
                    downloads.delete(requireArg<String>(call, "name"))
                    "ok"
                }
            }
            runOnUiThread { result.success(value) }
        } catch (e: Exception) {
            // Penyimpanan penuh, MediaStore rewel, argumen kosong: sisi Dart
            // membacanya sebagai gagal-yang-boleh-dicoba-lagi, bukan sebagai
            // "tidak didukung".
            runOnUiThread { result.error("io", e.message ?: e.javaClass.simpleName, null) }
        }
    }

    private fun <T : Any> requireArg(call: MethodCall, key: String): T =
        call.argument<T>(key) ?: throw IllegalArgumentException("argumen '$key' kosong")

    /**
     * Berkas di `Download/GymApps` lewat MediaStore.Downloads (API 29+; yang
     * memanggil sudah memeriksa versinya).
     *
     * Tanpa izin penyimpanan, query hanya mengembalikan baris milik pemasangan
     * ini. Berkas pemasangan lama (aplikasi dihapus lalu dipasang lagi) tidak
     * terlihat dan tidak bisa disentuh; kalau namanya bentrok, MediaStore
     * memberi berkas baru nama "… (1).json" — sisi Dart mengenali pola itu
     * saat memangkas.
     */
    @TargetApi(Build.VERSION_CODES.Q)
    private class Downloads(private val resolver: ContentResolver) {
        private val collection: Uri = MediaStore.Downloads.EXTERNAL_CONTENT_URI

        // MediaStore menyimpan RELATIVE_PATH dengan garis miring penutup;
        // dicocokkan dua bentuk supaya tidak bergantung pada normalisasi versi
        // Android yang dipakai.
        private fun ours(clause: String) = "$clause AND ${MediaStore.MediaColumns.RELATIVE_PATH} IN (?, ?)"

        private fun oursArgs(vararg args: String) = arrayOf(*args, RELATIVE_PATH, RELATIVE_PATH.trimEnd('/'))

        /**
         * Query yang ikut melihat baris IS_PENDING. Penulisan yang terputus di
         * tengah (HP mati) meninggalkan baris pending yang tidak terlihat query
         * biasa; tanpa ini, penulisan berikutnya membuat "nama (1).json" di
         * sampingnya dan baris setengah jadi itu tinggal selamanya.
         */
        @Suppress("DEPRECATION")
        private fun query(selection: String, args: Array<String>, projection: Array<String>): Cursor? {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val queryArgs = Bundle().apply {
                    putString(ContentResolver.QUERY_ARG_SQL_SELECTION, selection)
                    putStringArray(ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS, args)
                    putInt(MediaStore.QUERY_ARG_MATCH_PENDING, MediaStore.MATCH_INCLUDE)
                }
                return resolver.query(collection, projection, queryArgs, null)
            }
            // Android 10: cara lamanya, yang diganti di 11.
            return resolver.query(MediaStore.setIncludePending(collection), projection, selection, args, null)
        }

        private fun findByName(name: String): Uri? {
            query(ours("${MediaStore.MediaColumns.DISPLAY_NAME} = ?"), oursArgs(name), arrayOf(MediaStore.MediaColumns._ID))
                ?.use { c -> if (c.moveToFirst()) return ContentUris.withAppendedId(collection, c.getLong(0)) }
            return null
        }

        private fun insertPending(name: String): Uri {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.MediaColumns.MIME_TYPE, "application/json")
                put(MediaStore.MediaColumns.RELATIVE_PATH, RELATIVE_PATH)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            return resolver.insert(collection, values) ?: throw IllegalStateException("MediaStore menolak berkas baru")
        }

        private fun setPending(uri: Uri, pending: Boolean) {
            val values = ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, if (pending) 1 else 0) }
            resolver.update(uri, values, null, null)
        }

        /**
         * Isi berkas: tandai pending dulu supaya pengelola berkas dan pemindai
         * media tidak membaca berkas setengah jadi, tulis dari awal ("wt"
         * memotong isi lama — "w" saja tidak selalu, dan sisa JSON lama di
         * ekor berkas membuatnya tidak bisa diimpor), lalu lepas tandanya.
         */
        private fun fill(uri: Uri, bytes: ByteArray) {
            setPending(uri, true)
            val out = resolver.openOutputStream(uri, "wt") ?: throw IllegalStateException("berkas tidak bisa dibuka")
            out.use { it.write(bytes) }
            setPending(uri, false)
        }

        /**
         * Berkas hari yang sama ditimpa, bukan diduplikasi: barisnya dicari
         * lewat nama tampilan dan folder, lalu diisi ulang. Baris yang
         * berkasnya sudah tidak ada (dihapus lewat pengelola berkas yang tidak
         * memberi tahu MediaStore) dibuang dan diganti baris baru. Kegagalan
         * lain — penyimpanan penuh, MediaStore rewel — dilempar ke pemanggil.
         */
        fun write(name: String, bytes: ByteArray) {
            val existing = findByName(name)
            if (existing != null) {
                try {
                    fill(existing, bytes)
                    return
                } catch (e: FileNotFoundException) {
                    runCatching { resolver.delete(existing, null, null) }
                }
            }
            fill(insertPending(name), bytes)
        }

        fun list(prefix: String): ArrayList<String> {
            val names = ArrayList<String>()
            query(ours("${MediaStore.MediaColumns.DISPLAY_NAME} LIKE ?"), oursArgs("$prefix%"), arrayOf(MediaStore.MediaColumns.DISPLAY_NAME))
                ?.use { c -> while (c.moveToNext()) names.add(c.getString(0) ?: continue) }
            return names
        }

        fun delete(name: String) {
            val uri = findByName(name) ?: return
            resolver.delete(uri, null, null)
        }
    }

    private companion object {
        const val CHANNEL = "dev.hariz.gymapps/backup"
        const val RELATIVE_PATH = "Download/GymApps/"
        val METHODS = setOf("writeDownload", "listDownloads", "deleteDownload")
    }
}
