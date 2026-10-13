import '../../../../core/storage/secure_storage_service.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource _remoteDatasource;
  final SecureStorageService _storageService;

  AuthRepositoryImpl(this._remoteDatasource, this._storageService);

  @override
  Future<UserEntity> login(String username, String password) async {
    final result = await _remoteDatasource.login(username, password);
    final userModel = result.user;

    if (result.sessionId == null || result.sessionId!.isEmpty) {
      await _storageService.clearSession();
      throw StateError('Login succeeded but no sessionid was returned');
    }

    await _storageService.saveUserSession(
      userId: userModel.id,
      username: userModel.username,
      email: userModel.email,
      role: userModel.role,
      phone: userModel.phone,
      address: userModel.address,
      specialite: userModel.specialite,
      firstLogin: userModel.firstLogin,
      cookie: 'sessionid=${result.sessionId}',
    );

    return userModel.toEntity();
  }

  @override
  Future<void> logout() async {
    try {
      await _remoteDatasource.logout();
    } finally {
      await _storageService.clearSession();
    }
  }

  @override
  Future<UserEntity?> checkAutoLogin() async {
    final userId = await _storageService.getUserId();
    final username = await _storageService.getUsername();
    final role = await _storageService.getUserRole();
    final cookie = await _storageService.getSessionCookie();

    if (userId == null ||
        username == null ||
        role == null ||
        cookie == null ||
        cookie.isEmpty) {
      return null;
    }

    final valid = await _remoteDatasource.validateSession();
    if (!valid) {
      await _storageService.clearSession();
      return null;
    }

    return UserEntity(
      id: userId,
      username: username,
      email: await _storageService.getUserEmail(),
      role: role,
      phone: await _storageService.getUserPhone(),
      address: await _storageService.getUserAddress(),
      specialite: await _storageService.getUserSpecialite(),
      firstLogin: await _storageService.getFirstLogin(),
    );
  }

  @override
  Future<void> persistUser(UserEntity user) async {
    await _storageService.saveUserSession(
      userId: user.id,
      username: user.username,
      email: user.email,
      role: user.role,
      phone: user.phone,
      address: user.address,
      specialite: user.specialite,
      firstLogin: user.firstLogin,
    );
  }
}
