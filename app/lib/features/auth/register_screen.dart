/// Layar daftar akun.
///
/// **Tidak ada padanannya di artboard Pen** — Pen hanya punya `01 Login`.
/// Layar ini memakai struktur dan token yang sama persis supaya tidak terasa
/// datang dari aplikasi lain; yang baru cuma field ulangi-kata-sandi dan
/// validasinya.
///
/// Validasinya dikerjakan di sisi klien saja dan sengaja sederhana: cek email
/// berbentuk email, kata sandi cukup panjang, dan dua kata sandi sama.
/// Pemeriksaan yang sebenarnya — apakah email sudah terpakai — hanya bisa
/// dijawab server, jadi tidak ditiru di sini.
library;

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'field.dart';

/// Panjang minimum kata sandi. Mengikuti ambang Supabase Auth supaya
/// penolakan terjadi di sini, bukan setelah perjalanan bolak-balik ke server.
const minPasswordLength = 8;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.onRegistered, required this.onSignInInstead});

  final VoidCallback onRegistered;
  final VoidCallback onSignInInstead;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _obscure = true;
  bool _obscureConfirm = true;

  String? _emailError;
  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// Cukup untuk menangkap salah ketik, bukan untuk membuktikan alamatnya ada.
  /// Satu-satunya bukti sebuah email nyata adalah email yang terkirim ke sana.
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$');

  void _submit() {
    final t = context.t;
    final email = _email.text.trim();

    setState(() {
      _emailError = email.isEmpty
          ? t.emailRequired
          : (_emailPattern.hasMatch(email) ? null : t.emailInvalid);
      _passwordError = _password.text.length < minPasswordLength
          ? t.passwordTooShort(minPasswordLength)
          : null;
      // Ketidakcocokan baru ditampilkan kalau kata sandinya sendiri sudah sah —
      // dua pesan sekaligus untuk satu kesalahan hanya membingungkan.
      _confirmError = _passwordError == null && _confirm.text != _password.text
          ? t.passwordMismatch
          : null;
    });

    if (_emailError == null && _passwordError == null && _confirmError == null) {
      widget.onRegistered();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(GymRadius.card),
                  ),
                  child: Icon(Icons.fitness_center, size: 28, color: c.accentInk),
                ),
                const SizedBox(height: 18),
                Text(t.createAccount, style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 8),
                Text(t.createAccountSub,
                    style: TextStyle(fontSize: 14, height: 1.45, color: c.text2)),
                const SizedBox(height: 26),

                SectionLabel(t.email),
                const SizedBox(height: 8),
                GymField(
                  controller: _email,
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  hint: 'nama@email.com',
                  error: _emailError,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                SectionLabel(t.password),
                const SizedBox(height: 8),
                GymField(
                  controller: _password,
                  icon: Icons.lock_outline,
                  obscure: _obscure,
                  error: _passwordError,
                  textInputAction: TextInputAction.next,
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 19, color: c.text2),
                    tooltip: _obscure ? t.showPassword : t.hidePassword,
                  ),
                ),
                const SizedBox(height: 16),

                SectionLabel(t.confirmPassword),
                const SizedBox(height: 8),
                GymField(
                  controller: _confirm,
                  icon: Icons.lock_outline,
                  obscure: _obscureConfirm,
                  error: _confirmError,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    icon: Icon(
                        _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 19,
                        color: c.text2),
                    tooltip: _obscureConfirm ? t.showPassword : t.hidePassword,
                  ),
                ),
                const SizedBox(height: 22),

                GymButton(label: t.signUp, onPressed: _submit),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: widget.onSignInInstead,
                    child: Text(t.haveAccount,
                        style: TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700, color: c.accent)),
                  ),
                ),
                const SizedBox(height: 10),

                // Perbedaannya dengan layar masuk disebut di sini: mendaftar
                // adalah satu-satunya langkah yang benar-benar butuh sinyal.
                NoteBanner(icon: Icons.cloud_queue, text: t.signUpOffline, tone: c.text2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
