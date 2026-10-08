// Проверка правил CLAUDE.md, которые не ловит анализатор:
//
//  - цвета, шрифты и отступы — только из сгенерированных токенов;
//  - Material-виджеты — только внутри своих обёрток (lib/ui/widgets);
//  - тексты интерфейса — только через локализацию (никакой кириллицы
//    в строковых литералах интерфейса).
//
// Запуск из client/: dart run tool/check_rules.dart
import 'dart:io';

const _generated = 'lib/ui/theme/tokens.g.dart';

/// Декоративные иллюстрации: координаты и размеры из макета, числами.
const _illustrations = 'lib/ui/illustrations/';

bool _numbersChecked(String p) => p != _generated && !p.startsWith(_illustrations);

/// Где живут обёртки: здесь Material разрешён.
const _wrappers = 'lib/ui/widgets/';

/// Код интерфейса: здесь строки должны идти через L10n.
const _uiRoots = [
  'lib/ui/',
  'lib/features/',
  'lib/app/',
  'lib/showcase/',
  'lib/main.dart',
  'lib/main_showcase.dart',
];

const _materialWidgets = [
  'AppBar',
  'Badge',
  'BottomNavigationBar',
  'Card',
  'Checkbox',
  'Chip',
  'ChoiceChip',
  'CircleAvatar',
  'DropdownButton',
  'ElevatedButton',
  'FilledButton',
  'FilterChip',
  'FloatingActionButton',
  'IconButton',
  'InkWell',
  'InputChip',
  'ListTile',
  'NavigationBar',
  'NavigationRail',
  'OutlinedButton',
  'PopupMenuButton',
  'Radio',
  'SegmentedButton',
  'Slider',
  'SnackBar',
  'Switch',
  'SwitchListTile',
  'TabBar',
  'TextButton',
  'TextField',
  'TextFormField',
  'ToggleButtons',
  'Tooltip',
];

final _rules = <({String name, RegExp re, bool Function(String path) applies})>[
  (
    name: 'цвет не из токенов (используйте YlColors)',
    re: RegExp(r'\bColor\(\s*0x|Color\.from(ARGB|RGBO)\(|\bColors\.'),
    applies: (p) => p != _generated,
  ),
  (
    name: 'размер шрифта числом (используйте YlText)',
    re: RegExp(r'fontSize:\s*\d'),
    applies: _numbersChecked,
  ),
  (
    name: 'семейство шрифта строкой (используйте YlText.sansFamily / monoFamily)',
    re: RegExp(r'''fontFamily:\s*['"]'''),
    applies: (p) => p != _generated,
  ),
  (
    name: 'отступ числом (используйте YlSpace / YlSize)',
    re: RegExp(r'EdgeInsets\.(all|symmetric|only|fromLTRB)\([^)]*\b[1-9]\d*(\.\d+)?\b'),
    applies: _numbersChecked,
  ),
  (
    name: 'размер или радиус числом (используйте YlSize / YlSpace / YlRadius)',
    re: RegExp(
      // Не ловит множитель к токену (2 * YlSize.x) и height: 1 — межстрочный
      // множитель в TextStyle, а не размер.
      r'\b(width|height|size|dimension|left|top|right|bottom|spreadRadius|blurRadius)\s*:\s*'
      r'(?!1\s*[,)])-?[1-9]\d*(\.\d+)?(?!\s*\*)\b'
      r'|Radius\.(circular|elliptical)\(\s*[1-9]',
    ),
    applies: _numbersChecked,
  ),
  (
    name: 'Material-виджет напрямую (используйте обёртку Yl*)',
    re: RegExp('\\b(${_materialWidgets.join('|')})\\('),
    applies: (p) => !p.startsWith(_wrappers),
  ),
  (
    name: 'текст интерфейса в коде (вынесите в lib/l10n/app_ru.arb)',
    re: RegExp('''(['"])[^'"]*[А-Яа-яЁё][^'"]*\\1'''),
    applies: (p) => _uiRoots.any(p.startsWith),
  ),
];

void main() {
  final files =
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.path.replaceAll(r'\', '/'))
          .where((p) => p.endsWith('.dart') && !p.startsWith('lib/l10n/gen/'))
          .toList()
        ..sort();

  var problems = 0;
  for (final path in files) {
    final lines = File(path).readAsLinesSync();
    var inAssert = false;
    for (var i = 0; i < lines.length; i++) {
      final code = _stripComment(lines[i]);
      if (code.trim().isEmpty) continue;
      // Сообщения assert — для разработчика, не текст интерфейса.
      inAssert = inAssert || code.contains('assert(');
      final devText = inAssert;
      if (inAssert && code.contains(');')) inAssert = false;
      for (final rule in _rules) {
        if (devText && rule.re == _rules.last.re) continue;
        if (rule.applies(path) && rule.re.hasMatch(code)) {
          stderr.writeln('$path:${i + 1}: ${rule.name}\n    ${lines[i].trim()}');
          problems++;
        }
      }
    }
  }
  if (problems > 0) {
    stderr.writeln('\nНарушений правил: $problems');
    exit(1);
  }
  stdout.writeln('Правила CLAUDE.md соблюдены (${files.length} файлов).');
}

/// Отрезает комментарий `//`, если он не внутри строки.
String _stripComment(String line) {
  String? quote;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (quote != null) {
      if (ch == r'\') {
        i++;
      } else if (ch == quote) {
        quote = null;
      }
    } else if (ch == "'" || ch == '"') {
      quote = ch;
    } else if (ch == '/' && i + 1 < line.length && line[i + 1] == '/') {
      return line.substring(0, i);
    }
  }
  return line;
}
