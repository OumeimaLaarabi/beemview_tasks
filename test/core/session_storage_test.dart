import 'package:beemview_tasks/core/storage/session_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockSecureStorage storage;
  late SessionStorage session;

  setUp(() {
    storage = MockSecureStorage();
    session = SessionStorage(storage);
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {});
  });

  test('a persisted token is written to secure storage', () async {
    await session.saveToken('abc');
    verify(() => storage.write(key: 'auth_token', value: 'abc')).called(1);
    expect(await session.readToken(), 'abc');
  });

  test('a non-persisted token stays in memory and clears storage', () async {
    await session.saveToken('abc', persist: false);
    verifyNever(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    );
    verify(() => storage.delete(key: 'auth_token')).called(1);
    expect(await session.readToken(), 'abc');
  });
}
