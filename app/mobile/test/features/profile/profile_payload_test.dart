import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile/data/datasources/profile_remote_datasource.dart';

void main() {
  test('ProfileUpdatePayload includes password fields when set', () {
    const p = ProfileUpdatePayload(
      phone: '20000000',
      oldPassword: 'old',
      newPassword: 'newpass',
    );
    expect(p.toJson()['phone'], '20000000');
    expect(p.toJson()['old_password'], 'old');
    expect(p.toJson()['new_password'], 'newpass');
  });

  test('ProfileUpdatePayload omits empty passwords', () {
    const p = ProfileUpdatePayload(email: 'a@b.com', oldPassword: '');
    expect(p.toJson().containsKey('old_password'), isFalse);
    expect(p.toJson()['email'], 'a@b.com');
  });
}
