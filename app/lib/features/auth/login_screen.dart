/// Layar masuk — artboard `01 Login`.
library;

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onSignedIn});

  final VoidCallback onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(text: 'hariz@example.com');
  final _password = TextEditingController(text: 'gymapps123');
  bool _obscure = true;

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
                _Field(
                  controller: _email,
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                SectionLabel(context.t.password),
                const SizedBox(height: 8),
                _Field(
                  controller: _password,
                  icon: Icons.lock_outline,
                  obscure: _obscure,
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 19, color: c.text2),
                    tooltip: _obscure ? context.t.showPassword : context.t.hidePassword,
                  ),
                ),
                const SizedBox(height: 22),
                GymButton(label: context.t.signIn, onPressed: widget.onSignedIn),
                const SizedBox(height: 16),
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
                      Icon(Icons.cloud_off_outlined, size: 17, color: c.text2),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(context.t.offlineNote,
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

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
  });

  final TextEditingController controller;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    OutlineInputBorder border(Color colour) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(GymRadius.card),
          borderSide: BorderSide(color: colour),
        );

    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      autocorrect: false,
      style: TextStyle(fontSize: 15, color: c.text),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 19, color: c.text2),
        suffixIcon: suffix,
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: border(c.border),
        enabledBorder: border(c.border),
        focusedBorder: border(c.accent),
      ),
    );
  }
}
