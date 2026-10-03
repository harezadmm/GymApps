/// Grafik UI v3: sparkline halus berisi gradien, batang membulat dengan
/// garis rata-rata dan gelembung nilai, dan peta otot yang punya bokong di
/// kedua sisi tampak belakang.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/body_map_data.dart';
import 'package:gymapps/core/charts.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/domain/muscle_volume.dart';

void main() {
  test('smoothPath: satu kontur yang mulai dan berakhir di titik ujung', () {
    final pts = [const Offset(0, 30), const Offset(20, 10), const Offset(40, 20), const Offset(60, 5)];
    final path = smoothPath(pts);
    final metrics = path.computeMetrics().toList();
    expect(metrics, hasLength(1));
    final bounds = path.getBounds();
    expect(bounds.left, closeTo(0, 0.01));
    expect(bounds.right, closeTo(60, 0.01));
    final start = metrics.first.getTangentForOffset(0)!.position;
    final end = metrics.first.getTangentForOffset(metrics.first.length)!.position;
    expect(start, const Offset(0, 30));
    expect((end - const Offset(60, 5)).distance, lessThan(0.01));
  });

  testWidgets('BarSeries: gelembung pada batang terakhir tanpa ketukan, garis rata-rata', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildGymTheme(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 318,
            child: BarSeries(
              values: const [38, 44, 41, 47, 52, 30, 46, 51],
              leftLabel: '-7 mgg',
              midLabel: '-4 mgg',
              rightLabel: 'sekarang',
              valueFormat: (v) => '${v.round()} set',
              average: 44,
              averageFormat: (v) => 'rata-rata ${v.round()} set',
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('51 set'), findsOneWidget);
    expect(find.text('rata-rata 44 set'), findsOneWidget);
    expect(tester.widget<Text>(find.text('sekarang')).style!.color, GymColors.dark.accent);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sparkline bawaan 94×36 tergambar tanpa error', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildGymTheme(),
      home: const Scaffold(body: Center(child: Sparkline(values: [92, 94, 97, 97, 103, 109]))),
    ));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(Sparkline)), const Size(94, 36));
    expect(tester.takeException(), isNull);
  });

  test('otot bokong ada di dua sisi tampak belakang, simetris', () {
    final glutes = [
      for (var i = 0; i < bodyHeatmapGroups.length; i++)
        if (bodyHeatmapGroups[i] == MuscleGroup.glutes.index) i,
    ];
    expect(glutes.length, greaterThanOrEqualTo(2));
    expect(bodyHeatmapPaths.length, bodyHeatmapGroups.length);
    expect(bodyHeatmapLevels.length, bodyHeatmapPaths.length);

    double cx(List<double> enc) {
      var s = 0.0;
      var n = 0;
      var k = 0;
      while (k < enc.length) {
        final op = enc[k].toInt();
        final m = op == 0 || op == 1 ? 1 : (op == 2 ? 3 : 0);
        for (var j = 0; j < m; j++) {
          s += enc[k + 1 + j * 2];
          n++;
        }
        k += 1 + m * 2;
      }
      return s / n;
    }

    // Sumbu tengah figur belakang: 222,2 dari 320.
    final a = cx(bodyHeatmapPaths[glutes[glutes.length - 2]]);
    final b = cx(bodyHeatmapPaths[glutes.last]);
    expect((a + b) / 2, closeTo(222.2 / 320, 0.01));
  });
}
