import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';

/// Drives shop creation at onboarding and surfaces its outcome as an
/// [AsyncValue]. There is no sign-in: the shop lives on this phone.
///
/// `build` returns nothing — this controller models an *action*, not a piece of
/// loaded state. Screens watch its `isLoading` to disable buttons and
/// `ref.listen` for `AsyncError` to show messages.
class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Creates the phone's shop. [myShopProvider] watches the `shops` table, so
  /// the router moves on by itself once the row exists.
  Future<void> createShop({
    required String name,
    String? address,
    String? phone,
    String currency = 'BDT',
  }) async {
    state = const AsyncLoading();
    final result = await ref
        .read(shopRepositoryProvider)
        .createShop(
          name: name.trim(),
          address: address?.trim(),
          phone: phone?.trim(),
          currency: currency,
        );
    state = result.when(
      success: (_) => const AsyncData(null),
      failure: (f) => AsyncError(f, StackTrace.current),
    );
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);
