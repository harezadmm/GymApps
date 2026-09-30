/// Field teks layar masuk dan daftar.
///
/// Sebelumnya `_Field` privat di dalam `login_screen.dart`. Diangkat ke sini
/// saat layar daftar dibuat, supaya kedua layar berbagi satu bentuk field dan
/// tidak melenceng pelan-pelan setiap kali salah satunya disunting.
library;

import 'package:flutter/material.dart';

import '../../core/gym_icons.dart';
import '../../core/theme.dart';

class GymField extends StatelessWidget {
  const GymField({
    super.key,
    required this.controller,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.hint,
    this.error,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final String? hint;

  /// Pesan kesalahan, atau null kalau isinya sah. Bukan `bool` + string
  /// terpisah: satu nilai membuat "salah tapi tidak ada pesannya" mustahil.
  final String? error;

  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final invalid = error != null;

    OutlineInputBorder border(Color colour) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(GymRadius.card),
          borderSide: BorderSide(color: colour),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          autocorrect: false,
          // Keyboard iOS mengapitalkan huruf pertama secara bawaan. Untuk email
          // dan kata sandi itu menghasilkan salah ketik yang sulit dilihat,
          // karena kata sandinya tertutup titik-titik.
          textCapitalization: TextCapitalization.none,
          enableSuggestions: !obscure,
          style: TextStyle(fontSize: 15, color: c.text),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 19, color: invalid ? c.danger : c.text2),
            suffixIcon: suffix,
            hintText: hint,
            hintStyle: TextStyle(fontSize: 15, color: c.text3),
            filled: true,
            fillColor: c.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: border(c.border),
            enabledBorder: border(invalid ? c.danger : c.border),
            focusedBorder: border(invalid ? c.danger : c.accent),
          ),
        ),
        if (invalid) ...[
          const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ikon di samping teks, bukan warna saja: warna sendirian bukan
              // penanda yang cukup bagi orang yang sulit membedakan merah.
              Icon(GymIcons.alert, size: 14, color: c.danger),
              const SizedBox(width: 6),
              Expanded(
                child: Text(error!,
                    style: TextStyle(fontSize: 12.5, height: 1.35, color: c.danger)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
