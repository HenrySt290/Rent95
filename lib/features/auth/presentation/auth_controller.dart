import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/env.dart';
import '../../../core/network/auth_event_bus.dart';
import '../../../core/storage/token_storage.dart';
import '../../../shared/models/user.dart';
import '../../../shared/services/mock_store.dart';

/// High-level auth state for the whole app.
class AuthState {
  const AuthState({
    this.isLoading = false,
    this.user,
    this.error,
    this.initialized = false,
  });

  final bool isLoading;
  final AppUser? user;
  final String? error;
  final bool initialized;

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    bool? isLoading,
    AppUser? user,
    String? error,
    bool? initialized,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: clearUser ? null : (user ?? this.user),
      error: clearError ? null : (error ?? this.error),
      initialized: initialized ?? this.initialized,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref) : super(const AuthState()) {
    _forceLogoutSub = _ref.read(authEventBusProvider).stream.listen((event) {
      if (event == AuthEvent.forceLogout && mounted) {
        // Refresh token was rejected — drop session state so the router
        // bounces the user back to the login screen on the next redirect.
        state = const AuthState(initialized: true);
      }
    });
    _bootstrap();
  }
  final Ref _ref;
  StreamSubscription<AuthEvent>? _forceLogoutSub;

  @override
  void dispose() {
    _forceLogoutSub?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final storage = _ref.read(tokenStorageProvider);
    final token = await storage.readAccessToken();
    if (token != null && token.isNotEmpty) {
      // In mock mode, treat any saved token as "logged in as the mock user".
      state = state.copyWith(
        user: _ref.read(mockStoreProvider).currentUser,
        initialized: true,
      );
    } else {
      state = state.copyWith(initialized: true);
    }
  }

  Future<void> loginWithEmail({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    await Future<void>.delayed(const Duration(milliseconds: 600));

    if (!email.contains('@') || password.length < 4) {
      state = state.copyWith(
        isLoading: false,
        error: 'Enter a valid email and a password of at least 4 characters.',
      );
      return;
    }

    if (Env.useMocks) {
      await _ref.read(tokenStorageProvider).saveTokens(
            accessToken: 'mock.access.${DateTime.now().millisecondsSinceEpoch}',
            refreshToken: 'mock.refresh',
          );
      state = AuthState(
        user: _ref.read(mockStoreProvider).currentUser,
        initialized: true,
      );
      return;
    }

    // TODO: implement real POST /api/auth/login via Dio when backend is live.
    throw UnimplementedError('Real auth backend not wired yet.');
  }

  Future<void> loginWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await _ref.read(tokenStorageProvider).saveTokens(
          accessToken: 'mock.google.${DateTime.now().millisecondsSinceEpoch}',
        );
    state = AuthState(
      user: _ref.read(mockStoreProvider).currentUser,
      initialized: true,
    );
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await _ref.read(tokenStorageProvider).saveTokens(
          accessToken: 'mock.reg.${DateTime.now().millisecondsSinceEpoch}',
        );
    state = AuthState(
      user: _ref.read(mockStoreProvider).currentUser.copyWith(
            fullName: fullName,
            isEmailVerified: false,
          ),
      initialized: true,
    );
  }

  Future<void> logout() async {
    await _ref.read(tokenStorageProvider).clear();
    state = const AuthState(initialized: true);
  }

  void becomeSeller() {
    final u = state.user;
    if (u == null) return;
    state = state.copyWith(user: u.copyWith(role: UserRole.seller));
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
