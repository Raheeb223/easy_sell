import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/theme.dart';
import '../../../core/l10n/l10n_ext.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_card.dart';
import '../../../shared/extensions/format.dart';
import '../../auth/data/auth_repository.dart';
import '../../expiry/presentation/today_provider.dart';
import '../domain/cash_flow_alerts.dart';
import '../domain/finance_health.dart';
import '../domain/financing_match.dart';
import 'finance_providers.dart';
import 'finance_text.dart';
import 'money_tips_controller.dart';
import 'money_tips_facts.dart';
import 'money_tips_rules.dart';

/// Home's "Money health" card (spec §6): the last 7 days' money in / out /
/// net, up to three warnings and how many financing options fit.
///
/// Hidden for a shop with no money movement yet, on error and while loading,
/// so a database without 0019 leaves Home exactly as it was.
class MoneyHealthCard extends ConsumerWidget {
  const MoneyHealthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ref.watch(financeHealthProvider).value;
    if (h == null || !h.hasActivity) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final currency = ref.watch(myShopProvider).value?.currency ?? 'USD';
    final alerts = cashFlowAlerts(h);
    final fitting = matchFinancing(h).where((m) => m.fits).length;

    // Bottom margin inside the visible branch, as ReceivablesCard does, so
    // the gap collapses with the card.
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        onTap: () => context.push(AppRoutes.finance),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.muted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.monitor_heart_outlined, color: colors.link),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.finance_title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        l10n.finance_last7Days,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.textDim),
              ],
            ),
            const SizedBox(height: 14),
            MoneyFlowRow(health: h, currency: currency),
            const SizedBox(height: 12),
            if (alerts.isEmpty)
              _Line(
                icon: Icons.check_circle_outline,
                color: colors.positive,
                text: l10n.finance_allGood,
              )
            else
              for (final a in alerts.take(3))
                _Line(
                  icon: Icons.warning_amber_rounded,
                  color: a is OverdueAlert ? colors.negative : colors.warning,
                  text: alertText(l10n, a, currency),
                ),
            const SizedBox(height: 6),
            _Line(
              icon: Icons.account_balance_outlined,
              color: colors.link,
              text: l10n.finance_financingFooter(fitting),
              textColor: colors.link,
            ),
            const SizedBox(height: 8),
            MoneyTipsSection(health: h, currency: currency),
          ],
        ),
      ),
    );
  }
}

/// Gemini's advice on the numbers above (spec §9). Nothing is sent until the
/// seller taps; tips for these exact numbers today are shown from the phone.
class MoneyTipsSection extends ConsumerWidget {
  const MoneyTipsSection({
    super.key,
    required this.health,
    required this.currency,
  });

  final FinanceHealth health;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final lang = Localizations.localeOf(context).languageCode;
    final facts = moneyTipsFacts(
      health: health,
      l10n: l10n,
      currency: currency,
    );
    final key = moneyTipsKey(ref.watch(todayProvider), lang, facts);
    final state = ref.watch(moneyTipsProvider);
    void ask() => ref
        .read(moneyTipsProvider.notifier)
        .ask(
          key: key,
          tips: moneyTips(health: health, l10n: l10n, currency: currency),
        );

    final askButton = Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: ask,
        icon: const Icon(Icons.auto_awesome, size: 18),
        label: Text(l10n.finance_tipsAsk),
      ),
    );

    // A state for other numbers (an older day, or before the latest sale) is
    // stale: offer to ask again rather than show advice about other figures.
    return switch (state) {
      TipsLoading(key: final k) when k == key => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(l10n.finance_tipsThinking),
          ],
        ),
      ),
      TipsReady(key: final k, :final tips) when k == key => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.muted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 16, color: colors.link),
                const SizedBox(width: 6),
                Text(
                  l10n.finance_tipsTitle,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.link,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final t in tips)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text(t, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              l10n.finance_tipsNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      TipsFailed(key: final k) when k == key => Row(
        children: [
          Expanded(
            child: Text(
              l10n.finance_tipsError,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.negative,
              ),
            ),
          ),
          TextButton(onPressed: ask, child: Text(l10n.common_retry)),
        ],
      ),
      _ => askButton,
    };
  }
}

/// In / Out / Net side by side. Shared with the Money health screen.
class MoneyFlowRow extends StatelessWidget {
  const MoneyFlowRow({super.key, required this.health, required this.currency});

  final FinanceHealth health;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).extension<AppColors>()!;
    final net = health.net7d;
    // Whole amounts, like the dashboard stat cards: with paisa, "৳14,870.00"
    // filled its third of the row and ran into "Out" on an S22. The exact
    // figures are in the breakdown on the Money health screen.
    String money(double v) => Money.compact(v, currencyCode: currency);
    return Row(
      children: [
        Expanded(
          child: _Stat(label: l10n.finance_in, value: money(health.cashIn7d)),
        ),
        Expanded(
          child: _Stat(label: l10n.finance_out, value: money(health.cashOut7d)),
        ),
        Expanded(
          child: _Stat(
            label: l10n.finance_net,
            value: money(net),
            color: net < 0 ? colors.negative : colors.positive,
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The right gap keeps neighbouring amounts apart even when one fills its
    // whole third and FittedBox has scaled it to the edge.
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          // Scales down rather than wrapping: three amounts share a 360 dp row.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.color,
    required this.text,
    this.textColor,
  });

  final IconData icon;
  final Color color;
  final String text;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}
