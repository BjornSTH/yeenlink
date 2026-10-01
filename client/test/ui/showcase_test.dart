import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeenlink/core/redact.dart';
import 'package:yeenlink/showcase/showcase.dart';
import 'package:yeenlink/ui/widgets/widgets.dart';

import '../helpers/app.dart';

/// Критерий фазы 0: витрина показывает все 9 компонентов в тёмной и
/// светлой темах.
const components = <Type>[
  YlButton,
  YlToggle,
  YlSegmented<String>,
  YlInput,
  YlAvatar,
  YlChip,
  YlBadge,
  YlStatusBanner,
  YlChannelRow,
];

void main() {
  setUpAll(loadAppFonts);

  testWidgets('витрина: все 9 компонентов в обеих темах', (tester) async {
    setSurface(tester, const Size(2 * ShowcasePanel.width, 2400));
    await tester.pumpWidget(testApp(const ShowcasePage()));
    final panels = find.byType(ShowcasePanel);
    expect(panels, findsNWidgets(2));
    for (final b in [Brightness.dark, Brightness.light]) {
      final panel = find.byWidgetPredicate((w) => w is ShowcasePanel && w.brightness == b);
      for (final type in components) {
        expect(
          find.descendant(of: panel, matching: find.byType(type)),
          findsWidgets,
          reason: '$type в теме $b',
        );
      }
    }
  });

  testWidgets('витрина в режиме стримера не показывает адрес и сервер', (tester) async {
    addTearDown(() => streamerMode.value = false);
    setSurface(tester, const Size(2 * ShowcasePanel.width, 2400));
    await tester.pumpWidget(testApp(const ShowcasePage()));
    expect(find.textContaining('nightcamp.ru'), findsWidgets);

    streamerMode.value = true;
    await tester.pump();
    for (final id in ['nightcamp.ru', '185.12.40.7']) {
      expect(find.textContaining(id), findsNothing, reason: id);
    }
  });

  testWidgets('на узком окне темы переключаются сегментами', (tester) async {
    setSurface(tester, const Size(420, 900));
    await tester.pumpWidget(testApp(const ShowcasePage()));
    expect(find.byType(ShowcasePanel), findsOneWidget);
    await tester.tap(find.text('Светлая матовая').first);
    await tester.pumpAndSettle();
    final panel = tester.widget<ShowcasePanel>(find.byType(ShowcasePanel));
    expect(panel.brightness, Brightness.light);
  });

  for (final b in [Brightness.dark, Brightness.light]) {
    testWidgets(
      'golden: витрина, ${b.name}',
      (tester) async {
        setSurface(tester, const Size(ShowcasePanel.width, 2400));
        await tester.pumpWidget(
          testApp(
            SingleChildScrollView(
              child: RepaintBoundary(
                key: const ValueKey('panel'),
                child: ShowcasePanel(brightness: b),
              ),
            ),
          ),
        );
        await expectLater(
          find.byKey(const ValueKey('panel')),
          matchesGoldenFile('goldens/showcase_${b.name}.png'),
        );
      },
      tags: ['golden'],
      skip: !Platform.isLinux,
    );
  }
}
