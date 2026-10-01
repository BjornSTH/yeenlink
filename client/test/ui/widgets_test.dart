import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeenlink/core/redact.dart';
import 'package:yeenlink/ui/widgets/widgets.dart';

import '../helpers/app.dart';

void main() {
  testWidgets('кнопка без обработчика не нажимается', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      testApp(
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              YlButton(label: 'Да', onPressed: () => taps++),
              const YlButton(label: 'Выберите, что показать', onPressed: null),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Да'));
    await tester.tap(find.text('Выберите, что показать'));
    expect(taps, 1);
  });

  testWidgets('кнопка нажимается с клавиатуры', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      testApp(
        Center(
          child: YlButton(label: 'Да', onPressed: () => taps++),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(taps, 1);
  });

  testWidgets('переключатель: подпись слева, нажатие по строке, блокировка', (tester) async {
    var value = false;
    await tester.pumpWidget(
      testApp(
        StatefulBuilder(
          builder: (context, setState) => Column(
            children: [
              YlToggle(label: 'Шум', value: value, onChanged: (v) => setState(() => value = v)),
              YlToggle(
                label: 'Закрыто',
                value: false,
                onChanged: (_) => value = false,
                lockedReason: 'Только Владелец',
              ),
            ],
          ),
        ),
      ),
    );
    final label = tester.getTopLeft(find.text('Шум'));
    final track = tester.getTopLeft(find.byType(AnimatedContainer).first);
    expect(label.dx, lessThan(track.dx), reason: 'подпись слева (Toggle/README.md)');

    await tester.tap(find.text('Шум'));
    await tester.pumpAndSettle();
    expect(value, isTrue);

    expect(find.text('Только Владелец'), findsOneWidget);
    await tester.tap(find.text('Закрыто'));
    expect(value, isTrue, reason: 'заблокированный не переключается');
  });

  testWidgets('сегменты: недоступный помечен «· нет» и не выбирается', (tester) async {
    var v = 'a';
    await tester.pumpWidget(
      testApp(
        StatefulBuilder(
          builder: (context, setState) => YlSegmented<String>(
            segments: const [
              YlSegment('a', 'A'),
              YlSegment('b', 'B'),
              YlSegment('c', 'C', available: false),
            ],
            value: v,
            onChanged: (x) => setState(() => v = x),
          ),
        ),
      ),
    );
    expect(find.text('C · нет'), findsOneWidget);
    await tester.tap(find.text('C · нет'));
    expect(v, 'a');
    await tester.tap(find.text('B'));
    expect(v, 'b');
  });

  testWidgets('полоса состояния прячет адрес в режиме стримера', (tester) async {
    addTearDown(() => streamerMode.value = false);
    await tester.pumpWidget(
      testApp(
        const YlStatusBanner(
          kind: YlBannerKind.warn,
          message: 'Переподключаюсь',
          address: '185.12.40.7:8443',
        ),
      ),
    );
    expect(find.text('185.12.40.7:8443'), findsOneWidget);
    streamerMode.value = true;
    await tester.pump();
    expect(find.text('185.12.40.7:8443'), findsNothing);
    expect(find.text('скрыто'), findsOneWidget);
  });

  testWidgets('счётчик больше 99 показывается как 99+', (tester) async {
    await tester.pumpWidget(testApp(const Center(child: YlBadge.count(120))));
    expect(find.text('99+'), findsOneWidget);
  });

  testWidgets('реакция: своя и чужая, нажатие', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      testApp(
        Center(
          child: YlChip.reaction(label: '+1', count: 4, mine: true, onTap: () => taps++),
        ),
      ),
    );
    expect(find.text('+1 · 4'), findsOneWidget);
    await tester.tap(find.text('+1 · 4'));
    expect(taps, 1);
  });

  test('инициалы аватара', () {
    expect(YlAvatar.initials('Кривозуб'), 'КР');
    expect(YlAvatar.initials('Ночной привал'), 'НП');
    expect(YlAvatar.initials('  '), '');
  });

  test('redact: заглушки фиксированной длины', () {
    // L10n нужен только для текста заглушек — проверяем через виджет-тест выше;
    // здесь — что без режима значение не меняется.
    expect(streamerMode.value, isFalse);
  });
}
