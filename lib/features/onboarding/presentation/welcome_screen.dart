import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/theme.dart';
import '../../../core/l10n/l10n_ext.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/entrance.dart';
import '../../../core/widgets/pressable.dart';
import '../../../shared/providers/onboarding_provider.dart';

/// First-launch welcome screen: dark-lime gradient hero with feature icons, a bold
/// headline, and a dark "Get started" pill. Shown once, then → shop setup.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    await ref.read(onboardingSeenProvider.notifier).markSeen();
    if (context.mounted) context.go(AppRoutes.onboarding);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Entrance(
                  index: 0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: const _GradientHero(),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Entrance(
                index: 1,
                child: Text(
                  l10n.welcome_headline,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Entrance(
                index: 2,
                child: Text(
                  l10n.welcome_subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Blue primary pill with a circular white arrow.
              Entrance(
                index: 3,
                child: PressableScale(
                  onTap: () => _start(context, ref),
                  borderRadius: BorderRadius.circular(40),
                  child: Material(
                    // Brand fill (gradient in light) when the app theme is
                    // present; plain primary otherwise.
                    color: theme.extension<AppColors>() == null
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    shape: const StadiumBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: Ink(
                      decoration: theme.extension<AppColors>() == null
                          ? null
                          : ShapeDecoration(
                              shape: const StadiumBorder(),
                              gradient: theme
                                  .extension<AppColors>()!
                                  .brandGradient,
                            ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 8, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.welcome_getStarted,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            _ArrowBadge(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular lime arrow badge on the "Get started" pill. Kept as its own
/// widget so the pill's Row can be non-const (reads context).
class _ArrowBadge extends StatelessWidget {
  const _ArrowBadge();

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: Colors.white,
      child: Icon(
        Icons.arrow_forward,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _GradientHero extends StatelessWidget {
  const _GradientHero();

  @override
  Widget build(BuildContext context) {
    const icons = [
      Icons.inventory_2_rounded,
      Icons.mic_rounded,
      Icons.photo_camera_rounded,
      Icons.insights_rounded,
    ];
    // The hero gradient with white feature tiles.
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient:
            Theme.of(context).extension<AppColors>()?.heroGradient ??
            const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.brand, AppTheme.brandDeep],
            ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final icon in icons)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(icon, color: Colors.white, size: 40),
              ),
          ],
        ),
      ),
    );
  }
}
