/// Layar masuk — artboard `01 Login`.
library;

import 'package:flutter/material.dart';

import '../../data/account_store.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../main.dart' show supabaseConfigured;
import '../../core/widgets.dart';
import 'field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.store,
    required this.onSignedIn,
    required this.onCreateAccount,
  });

  final AccountStore store;
  final VoidCallback onSignedIn;
  final VoidCallback onCreateAccount;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_busy) return;
    final t = context.t;
    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await widget.store.signIn(
      email: _email.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    switch (result) {
      case SignInOk():
        widget.onSignedIn();
      case SignInError(reason: final r):
        // Tiga kegagalan, tiga pesan berbeda. "Gagal masuk" saja membuat orang
        // mencoba kata sandi berulang kali padahal akunnya memang belum ada.
        setState(() => _error = switch (r) {
              SignInFailure.noAccount => t.noAccountYet,
              SignInFailure.wrongEmail => t.wrongEmail,
              SignInFailure.wrongPassword => t.wrongPassword,
            });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
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
                Text('GymApps', style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 8),
                Text(
                  context.t.tagline,
                  style: TextStyle(fontSize: 14, height: 1.45, color: c.text2),
                ),
                const SizedBox(height: 26),
                SectionLabel(context.t.email),
                const SizedBox(height: 8),
                GymField(
                  controller: _email,
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  hint: 'nama@email.com',
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                SectionLabel(context.t.password),
                const SizedBox(height: 8),
                GymField(
                  controller: _password,
                  icon: Icons.lock_outline,
                  obscure: _obscure,
                  error: _error,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 19, color: c.text2),
                    tooltip: _obscure ? context.t.showPassword : context.t.hidePassword,
                  ),
                ),
                const SizedBox(height: 22),
                GymButton(label: context.t.signIn, onPressed: _busy ? null : _submit),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: widget.onCreateAccount,
                    child: Text(context.t.noAccount,
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.accent)),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: () {},
                    child: Text(context.t.forgotPassword,
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.accent)),
                  ),
                ),
                const SizedBox(height: 10),
                // Janji offline-first (FR-A3) disebut di sini karena di sinilah
                // orang mengira butuh sinyal untuk memakai aplikasinya.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(GymRadius.card),
                    border: Border.all(color: c.border),
                  ),
                  child: Row(
                    children: [
                      // Ikon awan dicoret dulu terpasang mati di sini. Setelah
                      // sinkron benar-benar jalan, gambar itu justru menyatakan
                      // kebalikan dari yang terjadi.
                      Icon(
                        supabaseConfigured ? Icons.cloud_sync_outlined : Icons.cloud_off_outlined,
                        size: 17,
                        color: c.text2,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                            supabaseConfigured
                                ? context.t.offlineNoteSyncs
                                : context.t.offlineNoteLocalOnly,
                            style: TextStyle(fontSize: 12.5, color: c.text2)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

