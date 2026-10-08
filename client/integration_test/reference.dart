// Эталонные значения из testdata/vectors/identity (вектор «main» и конверт
// «profile», подписанный на Go). На устройство файлы testdata не попадают,
// поэтому значения встроены; test/integration_reference_test.dart следит,
// чтобы они не разошлись с testdata.

const refMnemonic =
    'virus lock response horror bread test riot control flavor poverty isolate arch';
const refMasterPub = '0549d5731f7bae78ff3efe80965b5f5ba9a7b77d40ddae858e462f3b00eda2a6';
const refFingerprint = '2DEC·9955·D7E0·675A';
const refNextKeyHash = 'e44de17709a3f89533c284b40aca7d796acca74d41bff7dc5ac99e7f37b6c597';

/// Конверт профиля, подписанный на Go: CBOR целиком.
const refProfileSigned =
    'a4616b58200549d5731f7bae78ff3efe80965b5f5ba9a7b77d40ddae858e462f3b00eda2a6617059012daa6176016373'
    '657103646e616d6572d09fd18fd182d0bdd0b8d181d182d18bd0b96477616c6cf56561626f75747836d09bd18ed0b1d0'
    'bbd18e20d0bdd0bed187d0bdd18bd0b520d0bfd0bed185d0bed0b4d18b2e0ad09820d0bad183d0b1d0b8d0bad0b82e66'
    '617661746172a3646d696d6569696d6167652f706e676473697a6519bc556673686132353658205649dbd48b0c810ad9'
    '2329e2ae5a636365e20490d695deda88f57e18368a8424666d617374657258200549d5731f7bae78ff3efe80965b5f5b'
    'a9a7b77d40ddae858e462f3b00eda2a667757064617465641b000001a0c4524e406c62616e6e65725f636f6c6f726862'
    '616e6e65722d326d6e6578745f6b65795f686173685820e44de17709a3f89533c284b40aca7d796acca74d41bff7dc5a'
    'c99e7f37b6c59761735840809b30bfbe117ef4001a1e753cc319233b6b7c81b1fb322ac2146622b00462341b58c7d931'
    '23185d525241ce7ef5c9ec8feb2577149ee5cedc9a904b0902db0f61746770726f66696c65';

/// Подпись того же профиля — её должна воспроизвести каждая платформа.
const refProfileSignature =
    '809b30bfbe117ef4001a1e753cc319233b6b7c81b1fb322ac2146622b00462341b58c7d93123185d525241ce7ef5c9ec'
    '8feb2577149ee5cedc9a904b0902db0f';
