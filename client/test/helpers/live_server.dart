import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:yeenlink/core/identity/identity.dart';
import 'package:yeenlink/core/net/server_address.dart';
import 'package:yeenlink/core/net/server_link.dart';

/// Бинарник сервера: YL_SERVER_BIN или server/bin/ylsrv (make build-server).
String? ylsrvPath() {
  final env = Platform.environment['YL_SERVER_BIN'];
  for (final p in [?env, '../server/bin/ylsrv']) {
    if (File(p).existsSync()) return File(p).absolute.path;
  }
  return null;
}

/// Живой ylsrv на 127.0.0.1 с самоподписанным сертификатом во временной папке.
class LiveServer {
  LiveServer._(this.dir, this.addr, this._proc, this.initOutput);

  final Directory dir;
  final ServerAddress addr;
  final Process _proc;
  final String initOutput;
  final log = StringBuffer();

  String get tokenPath => '${dir.path}/data/admin-token';

  String readToken() => File(tokenPath).readAsStringSync().trim();

  /// Отпечаток ключа сервера из вывода init.
  String get printedFingerprint =>
      RegExp(r'[0-9A-F]{4}·[0-9A-F]{4}·[0-9A-F]{4}·[0-9A-F]{4}').firstMatch(initOutput)!.group(0)!;

  static Future<LiveServer> start(String bin, {String name = 'Тест'}) async {
    final dir = await Directory.systemTemp.createTemp('ylsrv-');
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    await probe.close();
    final cfg = '${dir.path}/ylsrv.toml';
    final init = await Process.run(bin, [
      'init',
      '--non-interactive',
      '--systemd=false',
      '--config',
      cfg,
      '--data-dir',
      '${dir.path}/data',
      '--name',
      name,
      '--host',
      '127.0.0.1',
      '--listen',
      '127.0.0.1:$port',
      '--tls',
      'self-signed',
    ]);
    if (init.exitCode != 0) throw StateError('ylsrv init: ${init.stderr}${init.stdout}');
    final proc = await Process.start(bin, ['run', '--config', cfg]);
    final addr = ServerAddress('127.0.0.1', port);
    final srv = LiveServer._(dir, addr, proc, '${init.stdout}');
    proc.stderr.transform(utf8.decoder).listen(srv.log.write);
    proc.stdout.transform(utf8.decoder).listen(srv.log.write);
    for (var i = 0; i < 100; i++) {
      try {
        await fetchServerInfo(addr);
        return srv;
      } on LinkException {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
    await srv.stop();
    throw StateError('ylsrv не поднялся: ${srv.log}');
  }

  Future<void> stop() async {
    _proc.kill();
    await _proc.exitCode;
    await dir.delete(recursive: true);
  }
}

/// Случайная личность и устройство — как после онбординга.
Future<(Identity, LinkCredentials)> newCredentials({String device = 'Тест'}) async {
  final rnd = Random.secure();
  Uint8List bytes(int n) => Uint8List.fromList(List.generate(n, (_) => rnd.nextInt(256)));
  final id = await Identity.fromEntropy(bytes(16));
  final seed = bytes(32);
  final devicePub = await publicKeyOf(seed);
  final cert = await Signed.sign(
    SignedType.deviceCert,
    DeviceCert(
      devicePub: devicePub,
      name: device,
      platform: 'linux',
      created: DateTime.now().millisecondsSinceEpoch,
    ).toMap(),
    id.masterSeed,
  );
  return (
    id,
    LinkCredentials(
      masterPub: id.masterPub,
      devicePub: devicePub,
      deviceCert: cert,
      deviceSeed: seed,
    ),
  );
}
