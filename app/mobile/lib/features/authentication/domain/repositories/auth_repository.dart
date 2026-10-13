import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<UserEntity> login(String username, String password);
  Future<void> logout();
  Future<UserEntity?> checkAutoLogin();
  Future<void> persistUser(UserEntity user);
}
