import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeenlink/core/account/platform_bridge.dart';

/// Буфер обмена с фразой очищается, когда приложение уходит в фон или
/// закрывается, — но не трогает то, что человек скопировал после.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String? clip;

  setUp(() {
    clip = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        switch (call.method) {
          case 'Clipboard.setData':
            clip = (call.arguments as Map)['text'] as String?;
            return null;
          case 'Clipboard.getData':
            return clip == null ? null : {'text': clip};
        }
        return null;
      },
    );
  });

  test('фраза ещё в буфере — очищается', () async {
    final b = PlatformBridge();
    await b.copySensitive('virus lock');
    expect(clip, 'virus lock');
    await b.clearSensitiveClipboard();
    expect(clip, '');
  });

  test('человек скопировал другое — не трогаем', () async {
    final b = PlatformBridge();
    await b.copySensitive('virus lock');
    clip = 'что-то своё';
    await b.clearSensitiveClipboard();
    expect(clip, 'что-то своё');
  });

  test('без скопированной фразы ничего не делает', () async {
    clip = 'чужое';
    await PlatformBridge().clearSensitiveClipboard();
    expect(clip, 'чужое');
  });
}
