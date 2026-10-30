import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/theme.dart';
import 'core/router/app_router.dart';
import 'features/expiry/presentation/expiry_providers.dart';
import 'features/expiry/presentation/reminder_sync.dart';
import 'features/voice/presentation/voice_controller.dart';
import 'features/voice/presentation/voice_ready_banner.dart';
import 'l10n/app_localizations.dart';
import 'shared/providers/locale_provider.dart';
import 'shared/providers/theme_mode_provider.dart';

/// Root widget: wires the Material 3 theme and the go_router config.
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    // Locks expired counts / closes sold-out deliveries on shop load, date
    // change and app resume (expiry spec §4.2).
    ref.listen(expiryAutoReconcileProvider, (_, _) {});
    // Daily 9 AM expiry reminders (expiry spec §6) and their tap routing.
    ref.listen(reminderSyncProvider, (_, _) {});
    ref.listen(reminderTapRouterProvider, (_, _) {});

    return MaterialApp.router(
      title: 'EasySell',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: supportedAppLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      // Pin the OS font scale to 1.0 so the app always renders at its designed
      // (compact) sizes regardless of the device's "Font size / Display size"
      // setting — the most common reason text looked oversized on-device.
      builder: (context, child) {
        // Transparent system bars with icon brightness that follows the active
        // theme, so status/nav icons always contrast. Applies app-wide,
        // including the AppBar-less main tab screens.
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
          ),
          child: MediaQuery.withClampedTextScaling(
            minScaleFactor: 1.0,
            maxScaleFactor: 1.0,
            child: Consumer(
              builder: (context, ref, _) {
                // The banner sits above the routed screen and its own
                // SafeArea already consumes the status-bar inset, so strip the
                // top padding from the screen below whenever it is showing --
                // otherwise that gap is reserved twice. Scoped to this Consumer
                // so only this subtree rebuilds when a backgrounded voice sale
                // flips.
                final voiceWaiting = ref.watch(
                  voiceControllerProvider.select((s) => s.hasBackgroundSale),
                );
                // Solid canvas behind the navigator. Every route paints its
                // own AppBackdrop, so this only shows if a route misses the
                // wrap, and then as plain background rather than black.
                final canvas = Theme.of(
                  context,
                ).extension<AppColors>()!.background;
                return ColoredBox(
                  color: canvas,
                  child: Column(
                    children: [
                      // Sits above every screen rather than inside one: a
                      // backgrounded voice sale must still be reachable after
                      // the shopkeeper has navigated away from wherever they
                      // started it.
                      const VoiceReadyBanner(),
                      Expanded(
                        child: MediaQuery.removePadding(
                          context: context,
                          removeTop: voiceWaiting,
                          child: child!,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
