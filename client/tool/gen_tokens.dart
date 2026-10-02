// Генератор токенов дизайн-системы: docs/design/tokens.json →
// lib/ui/theme/tokens.g.dart (YlColors, YlShadows, YlText, YlSpace,
// YlRadius, YlSize, YlOpacity).
//
// Запуск из client/: dart run tool/gen_tokens.dart
// В CI файл перегенерируется и сверяется с репозиторием (git diff).
import 'dart:convert';
import 'dart:io';

const tokensPath = '../docs/design/tokens.json';

/// Группы верхнего уровня, которые генератор знает. Новая группа в выгрузке —
/// ошибка, чтобы её значения не потерялись молча.
/// Семейства цветов с номерами (avatar-1…N): для них генерируется список.
const paletteFamilies = ['avatar', 'banner'];

const knownGroups = {
  'name',
  'version',
  'color',
  'type',
  'spacing',
  'radius',
  'shadow',
  'size',
  'opacity',
};

const outPath = 'lib/ui/theme/tokens.g.dart';

void main(List<String> args) {
  final tokens = _readJson(tokensPath)!;
  final unknown = tokens.keys.toSet().difference(knownGroups);
  if (unknown.isNotEmpty) {
    stderr.writeln('В $tokensPath новые группы, генератор их не знает: ${unknown.join(', ')}');
    exit(1);
  }

  final colors = _list(tokens, ['color', 'tokens']);
  final themes = [
    for (final t in _list(tokens, ['color', 'themes'])) t['id'] as String,
  ];
  final families = (tokens['type'] as Map<String, dynamic>)['families'] as Map<String, dynamic>;
  final textStyles = [
    for (final g in _list(tokens, ['type', 'groups']))
      for (final s in g['styles'] as List) {...s as Map<String, dynamic>, 'family': g['family']},
  ];

  final out = StringBuffer()
    ..writeln('// СГЕНЕРИРОВАНО tool/gen_tokens.dart из docs/design/tokens.json')
    ..writeln('// Не править руками.')
    ..writeln()
    ..writeln("import 'package:flutter/material.dart' show Theme, ThemeExtension;")
    ..writeln("import 'package:flutter/widgets.dart';")
    ..writeln();

  _colors(out, colors, themes);
  _shadows(out, _list(tokens, ['shadow', 'tokens']), themes);
  _text(out, textStyles, families);
  _scalar(
    out,
    'YlSpace',
    'Отступы, сетка 4 px.',
    _list(tokens, ['spacing', 'tokens']),
    (n) => 's${n.replaceFirst('space-', '')}',
  );
  _radius(out, _list(tokens, ['radius', 'tokens']));
  _scalar(
    out,
    'YlSize',
    'Размеры элементов управления.',
    _list(tokens, ['size', 'tokens']),
    _camel,
  );
  _scalar(
    out,
    'YlOpacity',
    'Прозрачность состояний.',
    _list(tokens, ['opacity', 'tokens']),
    (n) => _camel(n.replaceFirst(RegExp(r'-opacity$'), '')),
  );

  File(outPath).writeAsStringSync(out.toString());
  final fmt = Process.runSync('dart', ['format', '--page-width', '100', outPath]);
  if (fmt.exitCode != 0) {
    stderr.write(fmt.stderr);
    exit(1);
  }
  stdout.writeln('Записан $outPath');
}

Map<String, dynamic>? _readJson(String path) {
  final f = File(path);
  if (!f.existsSync()) return null;
  return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
}

List<Map<String, dynamic>> _list(Map<String, dynamic>? root, List<String> path) {
  Object? cur = root;
  for (final k in path) {
    if (cur is! Map) return const [];
    cur = cur[k];
  }
  return [for (final e in (cur as List?) ?? const []) e as Map<String, dynamic>];
}

/// bg-000 → bg000, accent-alt-teal → accentAltTeal, radius-2xl → xxl.
String _camel(String name) {
  final parts = name.split('-');
  return parts.first +
      parts.skip(1).map((p) => p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1)).join();
}

String _doc(Map<String, dynamic> t) {
  final u = t['usage'];
  return u == null ? '' : '  /// $u\n';
}

String _color(String css) {
  css = css.trim();
  if (css.startsWith('#')) {
    final hex = css.substring(1);
    if (hex.length != 6) throw FormatException('цвет $css');
    return 'Color(0xFF${hex.toUpperCase()})';
  }
  final m = RegExp(r'rgba\((\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\)').firstMatch(css);
  if (m == null) throw FormatException('цвет $css');
  final a = (double.parse(m[4]!) * 255).round();
  final argb = [
    a,
    int.parse(m[1]!),
    int.parse(m[2]!),
    int.parse(m[3]!),
  ].map((v) => v.toRadixString(16).padLeft(2, '0').toUpperCase()).join();
  return 'Color(0x$argb)';
}

double _px(Object v) {
  if (v is num) return v.toDouble();
  final s = (v as String).trim();
  return double.parse(s.endsWith('px') ? s.substring(0, s.length - 2) : s);
}

String _num(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : _trim(v.toStringAsFixed(4));

String _trim(String s) => s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;

void _colors(StringBuffer out, List<Map<String, dynamic>> colors, List<String> themes) {
  final names = [for (final c in colors) _camel(c['name'] as String)];
  out
    ..writeln('/// Цвета темы. Получение: `YlColors.of(context)`.')
    ..writeln('@immutable')
    ..writeln('class YlColors extends ThemeExtension<YlColors> {')
    ..writeln('  const YlColors({')
    ..writeAll([for (final n in names) '    required this.$n,\n'])
    ..writeln('  });')
    ..writeln();
  for (var i = 0; i < colors.length; i++) {
    out
      ..write(_doc(colors[i]))
      ..writeln('  final Color ${names[i]};');
  }
  for (final theme in themes) {
    out
      ..writeln()
      ..writeln('  static const YlColors $theme = YlColors(');
    for (var i = 0; i < colors.length; i++) {
      final v = (colors[i]['value'] as Map)[theme] as String;
      out.writeln('    ${names[i]}: ${_color(v)},');
    }
    out.writeln('  );');
  }
  out
    ..writeln()
    ..writeln('  static YlColors of(BuildContext context) =>')
    ..writeln('      _ylExtension<YlColors>(context);')
    ..writeln()
    ..writeAll([
      for (final family in paletteFamilies)
        '  /// Палитра $family-1…N по порядку.\n'
            '  List<Color> get ${family}Palette => '
            '[${[for (final n in names)
              if (RegExp('^$family\\d+\$').hasMatch(n)) n].join(', ')}];\n\n',
    ])
    ..writeln('  /// Цвет баннера по имени токена (banner-N); неизвестное имя — banner-1.')
    ..writeln('  Color bannerByName(String? token) {')
    ..writeln("    final i = int.tryParse(token?.replaceFirst('banner-', '') ?? '') ?? 1;")
    ..writeln('    return bannerPalette[i >= 1 && i <= bannerPalette.length ? i - 1 : 0];')
    ..writeln('  }')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  YlColors copyWith({')
    ..writeAll([for (final n in names) '    Color? $n,\n'])
    ..writeln('  }) => YlColors(')
    ..writeAll([for (final n in names) '    $n: $n ?? this.$n,\n'])
    ..writeln('  );')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  YlColors lerp(YlColors? other, double t) {')
    ..writeln('    if (other == null) return this;')
    ..writeln('    return YlColors(')
    ..writeAll([for (final n in names) '      $n: Color.lerp($n, other.$n, t)!,\n'])
    ..writeln('    );')
    ..writeln('  }')
    ..writeln('}')
    ..writeln()
    ..writeln('T _ylExtension<T extends ThemeExtension<T>>(BuildContext context) {')
    ..writeln('  final ext = Theme.of(context).extension<T>();')
    ..writeln("  assert(ext != null, 'В теме нет \$T: оберните виджет в ylTheme().');")
    ..writeln('  return ext!;')
    ..writeln('}')
    ..writeln();
}

/// CSS-тень `x y blur rgba(…)` → BoxShadow. Размытие CSS — это 2σ, а во
/// Flutter σ = blurRadius·0.57735 + 0.5; переводим, чтобы тень совпала.
String _shadow(String css) {
  final parts = <String>[];
  for (final layer in css.split(RegExp(r',(?![^(]*\))'))) {
    final m = RegExp(
      r'^\s*(-?[\d.]+)(?:px)?\s+(-?[\d.]+)(?:px)?\s+([\d.]+)(?:px)?\s+(rgba\([^)]*\))\s*$',
    ).firstMatch(layer);
    if (m == null) throw FormatException('тень $css');
    final blur = double.parse(m[3]!);
    final radius = blur == 0 ? 0.0 : (blur / 2 - 0.5) / 0.57735;
    parts.add(
      'BoxShadow(offset: Offset(${_num(double.parse(m[1]!))}, ${_num(double.parse(m[2]!))}), '
      'blurRadius: ${_num(radius)}, color: ${_color(m[4]!)})',
    );
  }
  return '[${parts.join(', ')}]';
}

void _shadows(StringBuffer out, List<Map<String, dynamic>> shadows, List<String> themes) {
  final names = [
    for (final s in shadows) _camel((s['name'] as String).replaceFirst('shadow-', '')),
  ];
  out
    ..writeln('/// Тени — только у того, что парит над экраном. `YlShadows.of(context)`.')
    ..writeln('@immutable')
    ..writeln('class YlShadows extends ThemeExtension<YlShadows> {')
    ..writeln('  const YlShadows({${[for (final n in names) 'required this.$n'].join(', ')}});')
    ..writeln();
  for (var i = 0; i < shadows.length; i++) {
    out
      ..write(_doc(shadows[i]))
      ..writeln('  final List<BoxShadow> ${names[i]};');
  }
  for (final theme in themes) {
    out
      ..writeln()
      ..writeln('  static const YlShadows $theme = YlShadows(');
    for (var i = 0; i < shadows.length; i++) {
      out.writeln('    ${names[i]}: ${_shadow((shadows[i]['value'] as Map)[theme] as String)},');
    }
    out.writeln('  );');
  }
  out
    ..writeln()
    ..writeln('  static YlShadows of(BuildContext context) => _ylExtension<YlShadows>(context);')
    ..writeln()
    ..writeln('  @override')
    ..writeln(
      '  YlShadows copyWith({${[for (final n in names) 'List<BoxShadow>? $n'].join(', ')}}) =>',
    )
    ..writeln('      YlShadows(${[for (final n in names) '$n: $n ?? this.$n'].join(', ')});')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  YlShadows lerp(YlShadows? other, double t) {')
    ..writeln('    if (other == null) return this;')
    ..writeln('    return YlShadows(')
    ..writeAll([for (final n in names) '      $n: BoxShadow.lerpList($n, other.$n, t)!,\n'])
    ..writeln('    );')
    ..writeln('  }')
    ..writeln('}')
    ..writeln();
}

String _family(String css) {
  final m = RegExp(r'"([^"]+)"').firstMatch(css);
  if (m == null) throw FormatException('семейство $css');
  return m[1]!;
}

void _text(StringBuffer out, List<Map<String, dynamic>> styles, Map<String, dynamic> families) {
  out
    ..writeln('/// Шкала текста. Цвета здесь нет — его задаёт виджет из YlColors.')
    ..writeln('abstract final class YlText {')
    ..writeln("  static const String sansFamily = '${_family(families['sans'] as String)}';")
    ..writeln("  static const String monoFamily = '${_family(families['mono'] as String)}';")
    ..writeln();
  for (final s in styles) {
    final size = _px(s['fontSize'] as Object);
    final ls = s['letterSpacing'] as String?;
    final spacing = ls == null
        ? null
        : ls.endsWith('em')
        ? double.parse(ls.substring(0, ls.length - 2)) * size
        : _px(ls);
    final family = s['family'] == 'mono' ? 'monoFamily' : 'sansFamily';
    out
      ..write(_doc(s))
      ..writeln('  static const TextStyle ${_camel(s['name'] as String)} = TextStyle(')
      ..writeln('    fontFamily: $family,')
      ..writeln('    fontSize: ${_num(size)},')
      ..writeln('    height: ${_num((s['lineHeight'] as num).toDouble())},')
      ..writeln('    fontWeight: FontWeight.w${s['fontWeight']},')
      ..write(spacing == null ? '' : '    letterSpacing: ${_num(spacing)},\n')
      ..writeln('  );');
  }
  out.writeln('}');
  out.writeln();
}

void _scalar(
  StringBuffer out,
  String cls,
  String doc,
  List<Map<String, dynamic>> tokens,
  String Function(String) name,
) {
  out
    ..writeln('/// $doc')
    ..writeln('abstract final class $cls {');
  for (final t in tokens) {
    out
      ..write(_doc(t))
      ..writeln(
        '  static const double ${name(t['name'] as String)} = ${_num(_px(t['value'] as Object))};',
      );
  }
  out
    ..writeln('}')
    ..writeln();
}

void _radius(StringBuffer out, List<Map<String, dynamic>> tokens) {
  String n(String name) => name.replaceFirst('radius-', '').replaceFirst('2xl', 'xxl');
  out
    ..writeln('/// Скругления: `YlRadius.lg` — BorderRadius, `YlRadius.lgPx` — число.')
    ..writeln('abstract final class YlRadius {');
  for (final t in tokens) {
    final v = _num(_px(t['value'] as Object));
    out
      ..write(_doc(t))
      ..writeln('  static const double ${n(t['name'] as String)}Px = $v;')
      ..writeln(
        '  static const BorderRadius ${n(t['name'] as String)} = BorderRadius.all(Radius.circular($v));',
      );
  }
  out
    ..writeln('}')
    ..writeln();
}
