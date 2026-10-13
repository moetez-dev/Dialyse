import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _keyUserId = 'user_id';
  static const String _keyUsername = 'username';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserRole = 'user_role';
  static const String _keyUserPhone = 'user_phone';
  static const String _keyUserAddress = 'user_address';
  static const String _keyUserSpecialite = 'user_specialite';
  static const String _keyFirstLogin = 'first_login';
  static const String _keySessionCookie = 'session_cookie';

  Future<void> saveUserSession({
    required int userId,
    required String username,
    required String? email,
    required String role,
    String? phone,
    String? address,
    String? specialite,
    bool? firstLogin,
    String? cookie,
  }) async {
    await _storage.write(key: _keyUserId, value: userId.toString());
    await _storage.write(key: _keyUsername, value: username);
    if (email != null) {
      await _storage.write(key: _keyUserEmail, value: email);
    }
    await _storage.write(key: _keyUserRole, value: role);
    if (phone != null) {
      await _storage.write(key: _keyUserPhone, value: phone);
    }
    if (address != null) {
      await _storage.write(key: _keyUserAddress, value: address);
    }
    if (specialite != null) {
      await _storage.write(key: _keyUserSpecialite, value: specialite);
    }
    if (firstLogin != null) {
      await _storage.write(key: _keyFirstLogin, value: firstLogin ? '1' : '0');
    }
    if (cookie != null) {
      await _storage.write(key: _keySessionCookie, value: cookie);
    }
  }

  Future<int?> getUserId() async {
    final val = await _storage.read(key: _keyUserId);
    return val != null ? int.tryParse(val) : null;
  }

  Future<String?> getUsername() async {
    return await _storage.read(key: _keyUsername);
  }

  Future<String?> getUserEmail() async {
    return await _storage.read(key: _keyUserEmail);
  }

  Future<String?> getUserRole() async {
    return await _storage.read(key: _keyUserRole);
  }

  Future<String?> getUserPhone() async {
    return await _storage.read(key: _keyUserPhone);
  }

  Future<String?> getUserAddress() async {
    return await _storage.read(key: _keyUserAddress);
  }

  Future<String?> getUserSpecialite() async {
    return await _storage.read(key: _keyUserSpecialite);
  }

  Future<bool> getFirstLogin() async {
    final val = await _storage.read(key: _keyFirstLogin);
    return val == '1';
  }

  Future<String?> getSessionCookie() async {
    return await _storage.read(key: _keySessionCookie);
  }

  Future<void> clearSession() async {
    await _storage.deleteAll();
  }
}
