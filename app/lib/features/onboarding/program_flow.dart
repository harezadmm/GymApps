/// Alur memilih atau mengganti program dari dalam aplikasi (Home, tab Workout).
///
/// Onboarding memakai layar yang sama, tapi urutannya diatur `AppFlow`.
library;

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/workout_store.dart';
import '../../domain/templates.dart';
import 'custom_split_screen.dart';
import 'onboarding_screens.dart';

/// Buka pemilih program. true kalau program baru terpasang.
///
/// Mengganti program yang sudah ada selalu ditanyakan dulu: rutinitasnya
/// diganti, walau riwayat latihan tidak disentuh.
Future<bool> chooseProgram(BuildContext context) async {
  final store = WorkoutScope.read(context);
  var installed = false;
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (routeContext) => ProgramPickerScreen(
      onBack: () => Navigator.of(routeContext).pop(),
      onContinue: (tpl) async {
        if (store.hasProgram && !await confirmReplaceProgram(routeContext)) return;
        await store.applyTemplate(tpl.id);
        installed = true;
        if (routeContext.mounted) Navigator.of(routeContext).pop();
      },
      onBuildOwn: () async {
        final built = await buildOwnSplit(routeContext);
        if (built == null || !routeContext.mounted) return;
        if (store.hasProgram && !await confirmReplaceProgram(routeContext)) return;
        await store.setProgram(built.program, built.routines);
        installed = true;
        if (routeContext.mounted) Navigator.of(routeContext).pop();
      },
    ),
  ));
  return installed;
}

/// Buka layar susun split sendiri. null kalau batal.
Future<ProgramBundle?> buildOwnSplit(BuildContext context) => Navigator.of(context).push<ProgramBundle>(
      MaterialPageRoute(builder: (_) => const CustomSplitScreen()),
    );

Future<bool> confirmReplaceProgram(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) {
      final c = context.gym;
      return AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.large)),
        title: Text(context.t.changeProgram, style: Theme.of(context).textTheme.titleLarge),
        content: Text(context.t.changeProgramBody, style: TextStyle(fontSize: 13.5, height: 1.45, color: c.text2)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.t.cancel, style: TextStyle(fontWeight: FontWeight.w700, color: c.text2)),
          ),
          GymButton(
            label: context.t.replace,
            height: 42,
            expand: false,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      );
    },
  );
  return ok == true;
}
