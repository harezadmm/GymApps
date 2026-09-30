/// Layar masuk — artboard `01 Login`.
library;

import 'package:flutter/material.dart';
import '../../core/gym_icons.dart';
import '../../core/illustration.dart';

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
    this.onForgotPassword,
  });

  final AccountStore store;
  final VoidCallback onSignedIn;
  final VoidCallback onCreateAccount;

  /// Kirim link reset ke email ini. null = build tanpa server.
  final Future<bool> Function(String email)? onForgotPassword;

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
              SignInFailure.invalidCredentials => t.invalidCredentials,
              SignInFailure.offline => t.authOffline,
            });
    }
  }

  /// Lupa kata sandi: kirim link reset. Dulu tombolnya tidak berbuat apa-apa.
  Future<void> _forgot() async {
    final t = context.t;
    final messenger = ScaffoldMessenger.of(context);
    final send = widget.onForgotPassword;
    if (send == null) {
      messenger.showSnackBar(SnackBar(content: Text(t.forgotNoServer)));
      return;
    }
    final email = await showDialog<String>(
      context: context,
      builder: (_) => _ForgotDialog(initial: _email.text.trim()),
    );
    if (email == null || email.isEmpty || !mounted) return;
    setState(() => _busy = true);
    final ok = await send(email);
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(content: Text(ok ? t.forgotSent : t.authOffline)));
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
                const Center(child: GymIllustration(GymArt.liftOverhead, height: 170, blob: true)),
                const SizedBox(height: 18),
                Row(children: [
                  // Berkas yang sama dengan ikon di layar Home ponsel, bukan
                  // gambar kedua yang perlahan menyimpang dari yang pertama.
                  Image.asset(
                    'assets/brand/app_icon.png',
                    width: 40,
                    height: 40,
                    // 256 px turun ke 40 pt; tanpa ini tepinya bergerigi.
                    filterQuality: FilterQuality.medium,
                  ),
                  const SizedBox(width: 12),
                  Flexible(child: Text('GymApps', style: Theme.of(context).textTheme.displaySmall)),
                ]),
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
                  icon: GymIcons.mail,
                  keyboardType: TextInputType.emailAddress,
                  hint: 'nama@email.com',
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                SectionLabel(context.t.password),
                const SizedBox(height: 8),
                GymField(
                  controller: _password,
                  icon: GymIcons.lock,
                  obscure: _obscure,
                  error: _error,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? GymIcons.eye : GymIcons.eyeOff, size: 19, color: c.text2),
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
                    onPressed: _forgot,
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
                        supabaseConfigured ? GymIcons.sync : GymIcons.cloudOff,
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

class _ForgotDialog extends StatefulWidget {
  const _ForgotDialog({required this.initial});

  final String initial;

  @override
  State<_ForgotDialog> createState() => _ForgotDialogState();
}

class _ForgotDialogState extends State<_ForgotDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    return AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.large)),
      title: Text(t.forgotTitle, style: Theme.of(context).textTheme.titleLarge),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.forgotBody, style: TextStyle(fontSize: 13.5, height: 1.45, color: c.text2)),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: widget.initial.isEmpty,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.cancel, style: TextStyle(fontWeight: FontWeight.w700, color: c.text2)),
        ),
        GymButton(
          label: t.sendLink,
          height: 42,
          expand: false,
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
        ),
      ],
    );
  }
}
