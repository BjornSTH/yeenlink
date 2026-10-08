// Замер Argon2id на этой машине: flutter test --run-skipped -t bench test/core/vault
import 'package:flutter_test/flutter_test.dart';
import 'package:yeenlink/core/vault/master_lock.dart';

void main() {
  for (final (name, params) in [('standard', KdfParams.standard), ('light', KdfParams.light)]) {
    test(
      'argon2id $name',
      () async {
        final sw = Stopwatch()..start();
        await MasterLock.seal(
          entropy: List.filled(16, 1),
          secret: '123456',
          kind: SecretKind.pin,
          masterPub: List.filled(32, 2),
          params: params,
        );
        // ignore: avoid_print
        print('argon2id $name: ${sw.elapsedMilliseconds} мс');
      },
      timeout: const Timeout(Duration(minutes: 5)),
      tags: ['bench'],
    );
  }
}
