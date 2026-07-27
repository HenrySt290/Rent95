import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/auth_event_bus.dart';
import '../../../shared/models/user.dart';
import '../data/auth_providers.dart';
import '../data/auth_repository.dart';

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

  AuthRepository get _repo => _ref.read(authRepositoryProvider);

  @override
  void dispose() {
    _forceLogoutSub?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final user = await _repo.currentUser();
      state = state.copyWith(user: user, clearUser: user == null, initialized: true);
    } catch (_) {
      state = state.copyWith(initialized: true);
    }
  }

  Future<void> loginWithEmail({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repo.loginWithEmail(email: email, password: password);
      state = AuthState(user: user, initialized: true);
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _humanize(e));
    }
  }

  Future<void> loginWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repo.loginWithGoogle();
      state = AuthState(user: user, initialized: true);
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _humanize(e));
    }
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repo.register(
        fullName: fullName,
        email: email,
        password: password,
        phone: phone,
      );
      state = AuthState(user: user, initialized: true);
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _humanize(e));
    }
  }

  Future<void> logout() async {
    try {
      await _repo.logout();
    } catch (_) {
      // Ignore — local state is authoritative for the UI.
    }
    state = const AuthState(initialized: true);
  }

  void becomeSeller() {
    final u = state.user;
    if (u == null) return;
    state = state.copyWith(user: u.copyWith(role: UserRole.seller));
  }

  String _humanize(Object err) {
    final s = err.toString();
    return s.replaceFirst(RegExp(r'^Exception: '), '');
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
