import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ApiClient(storage);
});

final authRemoteDatasourceProvider = Provider<AuthRemoteDatasource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthRemoteDatasource(apiClient);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final remoteDs = ref.watch(authRemoteDatasourceProvider);
  final storage = ref.watch(secureStorageProvider);
  return AuthRepositoryImpl(remoteDs, storage);
});

abstract class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final UserEntity user;
  const AuthAuthenticated(this.user);
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(AuthInitial()) {
    checkAutoLogin();
  }

  Future<void> checkAutoLogin() async {
    state = AuthLoading();
    try {
      final user = await _repository.checkAutoLogin();
      if (user != null) {
        state = AuthAuthenticated(user);
      } else {
        state = AuthUnauthenticated();
      }
    } catch (_) {
      state = AuthUnauthenticated();
    }
  }

  Future<void> login(String username, String password) async {
    state = AuthLoading();
    try {
      final user = await _repository.login(username, password);
      state = AuthAuthenticated(user);
    } catch (e) {
      final msg = e.toString().replaceAll('ApiException: ', '');
      state = AuthError(msg);
    }
  }

  Future<void> logout() async {
    state = AuthLoading();
    await _repository.logout();
    state = AuthUnauthenticated();
  }

  /// Local sign-out after a 401 from a protected API (session already cleared).
  void forceLogout() {
    if (state is AuthUnauthenticated) return;
    state = AuthUnauthenticated();
  }

  /// Refresh cached user after profile/password update.
  Future<void> applyUser(UserEntity user) async {
    await _repository.persistUser(user);
    state = AuthAuthenticated(user);
  }
}

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  final client = ref.watch(apiClientProvider);
  final notifier = AuthNotifier(repo);
  client.onUnauthorized = notifier.forceLogout;
  return notifier;
});
