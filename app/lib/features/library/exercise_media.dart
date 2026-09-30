/// Gambar dan animasi gerakan (FR-C1) dari dataset openGym di jsDelivr:
/// thumbnail JPG di baris library, kartu sesi, dan lembar riwayat; GIF di
/// detail gerakan. Sumber dan lisensinya di NOTICE.md — media ini bukan
/// milik kita, jadi tidak dibundel dan tidak disimpan ke disk: hanya dimuat
/// dari CDN dan dipegang [ImageCache] bawaan Flutter di memori.
///
/// Tiga aturan dijaga di sini, bukan diulang di tiap layar:
/// - Setelan `showExerciseMedia` mati = tidak ada satu pun [Image.network]
///   yang dibangun, jadi tidak ada permintaan jaringan sama sekali — bukan
///   gambar yang diunduh lalu disembunyikan.
/// - Gagal (offline, CDN mati) jatuh ke ikon alat yang memang sudah ada,
///   tanpa teks merah. URL-nya dicatat di [ExerciseMedia]: Flutter membuang
///   gambar yang gagal dari cache-nya, jadi tanpa catatan ini daftar 1.324
///   baris yang digulir offline menembak CDN sekali per baris per gulir.
///   Dicoba lagi saat library dibuka lagi atau detail gerakannya dibuka.
/// - Gerak lewat `motion.dart`: gambar memudar masuk, dan saat sistem
///   meminta gerak dikurangi detail menampilkan gambar diam, bukan GIF.
library;

import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../core/strings.dart';
import '../../core/strings_media.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/exercise_catalog.dart';
import '../../data/workout_store.dart';

/// Catatan URL yang gagal dimuat selama aplikasi hidup.
abstract final class ExerciseMedia {
  static final _failed = <String>{};

  static bool hasFailed(String url) => _failed.contains(url);

  static void markFailed(String url) => _failed.add(url);

  /// Lupakan semua kegagalan supaya dicoba sekali lagi. Dipanggil saat
  /// library dibuka: sekali per pembukaan, bukan per rebuild.
  static void retryAll() => _failed.clear();

  /// Lupakan kegagalan satu URL — membuka detail gerakan adalah niat yang
  /// jelas, dan sinyal yang tadi hilang mungkin sudah kembali.
  static void retry(String? url) {
    if (url != null) _failed.remove(url);
  }

  /// Setelan akun, dibaca lewat scope supaya ketiga pemakai thumbnail tidak
  /// masing-masing mengeja aturannya.
  static bool enabledIn(BuildContext context) => WorkoutScope.of(context).settings.showExerciseMedia;
}

/// Gambar yang memudar masuk di atas [under] begitu frame pertamanya ada.
/// [under] selalu ada di baliknya supaya bentuknya sama di setiap keadaan;
/// gambar yang sudah di cache tampil seketika tanpa memudar — tidak ada yang
/// "datang".
Widget _revealOver({
  required BuildContext context,
  required Widget under,
  required Widget image,
  required int? frame,
  required bool wasSynchronouslyLoaded,
  required double radius,
}) {
  Widget top = ClipRRect(borderRadius: BorderRadius.circular(radius), child: image);
  if (!wasSynchronouslyLoaded) {
    top = AnimatedOpacity(
      opacity: frame == null ? 0 : 1,
      duration: GymMotion.of(context, GymMotion.normal),
      curve: GymMotion.curve,
      child: top,
    );
  }
  return Stack(fit: StackFit.expand, children: [under, top]);
}

/// Thumbnail kecil di samping nama gerakan.
///
/// [fallback] adalah ikon yang dipakai layar itu sebelum ada gambar. Ia tetap
/// tampil selagi gambar dimuat dan gambarnya memudar masuk di atasnya — tidak
/// ada kotak kosong, dan barisnya tidak berubah ukuran. Gagal, media mati,
/// atau gerakan custom ([url] null) berarti [fallback] apa adanya.
class ExerciseThumb extends StatelessWidget {
  const ExerciseThumb({super.key, required this.url, required this.fallback, this.size = 44});

  /// URL JPG dari [Exercise.imageUrl]; null untuk gerakan custom.
  final String? url;
  final Widget fallback;
  final double size;

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || !ExerciseMedia.enabledIn(context) || ExerciseMedia.hasFailed(u)) return fallback;
    return SizedBox(
      width: size,
      height: size,
      child: Image.network(
        u,
        // Kunci per URL: baris ListView yang dipakai ulang untuk gerakan lain
        // mendapat Image baru, bukan thumbnail gerakan lama yang bertahan
        // sampai yang baru datang.
        key: ValueKey(u),
        width: size,
        height: size,
        fit: BoxFit.cover,
        // Didekode seukuran yang digambar, bukan 180 px penuh: cache memegang
        // piksel, dan daftar ini 1.324 baris.
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
        filterQuality: FilterQuality.medium,
        // Rebuild (tema, satuan, favorit) tidak mengedipkan gambar yang ada.
        gaplessPlayback: true,
        // Nama gerakan ada persis di sebelahnya; pembaca layar tidak perlu
        // "gambar" tanpa keterangan.
        excludeFromSemantics: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) => _revealOver(
          context: context,
          under: Center(child: fallback),
          image: child,
          frame: frame,
          wasSynchronouslyLoaded: wasSynchronouslyLoaded,
          radius: GymRadius.small,
        ),
        errorBuilder: (context, error, stack) {
          ExerciseMedia.markFailed(u);
          return fallback;
        },
      ),
    );
  }
}

/// Animasi gerakan di puncak detail library — GIF dari dataset, atau gambar
/// diamnya kalau sistem meminta gerak dikurangi: posisinya tetap
/// diperagakan, dan tidak ada yang bergerak sendiri.
class ExerciseAnimation extends StatelessWidget {
  const ExerciseAnimation({super.key, required this.exercise, this.height = 200});

  final Exercise exercise;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final still = MediaQuery.disableAnimationsOf(context);
    final url = still ? exercise.imageUrl : exercise.gifUrl;
    if (url == null || !ExerciseMedia.enabledIn(context)) return const SizedBox.shrink();
    final unavailable = _MediaPanel(icon: exercise.icon, caption: t.animationUnavailable);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ExerciseMedia.hasFailed(url)
          ? unavailable
          : Image.network(
              url,
              key: ValueKey(url),
              fit: BoxFit.contain,
              // GIF dataset 360 px; kotak 200 dp di HP 3× butuh 600 px, jadi
              // ini hanya membatasi tablet dan layar besar. Semua frame GIF
              // ikut didekode seukuran ini.
              cacheHeight: (height * MediaQuery.devicePixelRatioOf(context)).round(),
              gaplessPlayback: true,
              semanticLabel: t.demonstrationOf(exercise.name),
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) => _revealOver(
                context: context,
                // Pemutar kecil hanya selagi frame pertama belum ada — bukan
                // animasi yang terus berjalan di balik gambar yang sudah tampil.
                under: _MediaPanel(icon: exercise.icon, loading: frame == null && !wasSynchronouslyLoaded),
                image: child,
                frame: frame,
                wasSynchronouslyLoaded: wasSynchronouslyLoaded,
                radius: GymRadius.control,
              ),
              errorBuilder: (context, error, stack) {
                ExerciseMedia.markFailed(url);
                return unavailable;
              },
            ),
    );
  }
}

/// Panel di balik animasi: latar bersarang dengan ikon alat yang diredam —
/// bahasa ilustrasi yang sama dengan layar kosong. Selagi memuat ada pemutar
/// kecil; gagal ada satu kalimat, bukan teks galat.
class _MediaPanel extends StatelessWidget {
  const _MediaPanel({required this.icon, this.caption, this.loading = false});

  final IconData icon;
  final String? caption;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.bgNested, borderRadius: BorderRadius.circular(GymRadius.control)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconDisc(icon, color: c.text3, size: 48, iconSize: 24),
          if (loading) ...[
            const SizedBox(height: 10),
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: c.text3)),
          ],
          if (caption != null) ...[
            const SizedBox(height: 8),
            Text(caption!, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: c.text3)),
          ],
        ],
      ),
    );
  }
}
