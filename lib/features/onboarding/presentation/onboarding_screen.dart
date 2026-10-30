import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/motion.dart';
import '../../../core/l10n/l10n_ext.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../settings/presentation/backup_flow.dart';
import 'language_step.dart';
import 'shop_setup_step.dart';

/// First-run setup wizard for a signed-in user who has no shop yet. Two steps
/// on one route: (1) compulsory language choice, (2) shop setup in that
/// language. A `NeverScrollableScrollPhysics` PageView makes it structurally
/// impossible to reach step 2 without completing step 1 — movement is only via
/// the step-1 Continue button and the step-2 back arrow. A Sign-out action is
/// kept as an escape hatch.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _step = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _go(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(
      step,
      duration: AppMotion.page,
      curve: AppMotion.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: _step == 1 ? BackButton(onPressed: () => _go(0)) : null,
        title: Text(
          l10n.onboarding_step(_step + 1, 2),
          style: theme.textTheme.labelLarge,
        ),
        actions: [
          // A new phone, or the app reinstalled: bring the shop back from a
          // backup file instead of starting empty.
          TextButton(
            onPressed: isLoading ? null : () => restoreBackupFlow(context, ref),
            child: Text(l10n.backup_restore),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_step + 1) / 2,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  LanguageStep(onContinue: () => _go(1)),
                  const ShopSetupStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
