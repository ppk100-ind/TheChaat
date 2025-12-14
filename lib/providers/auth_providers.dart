import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

final currentUserProvider = StreamProvider<UserModel?>((ref) async* {
  final authService = ref.watch(authServiceProvider);

  await for (final user in authService.authStateChanges) {
    if (user != null) {
      try {
        print('User logged in (${user.uid})');
        final userData = await authService
            .getUserById(user.uid)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                print('Timeout fetching user data');
                return null;
              },
            );
        print('User data: ${userData?.username ?? "null"}');
        yield userData;
      } catch (e) {
        print('Error in currentUserProvider: $e');
        yield null;
      }
    } else {
      print('User logged out');
      yield null;
    }
  }
});

final currentFirebaseUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.value;
});
