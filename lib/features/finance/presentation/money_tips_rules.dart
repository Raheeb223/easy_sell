import '../../../l10n/app_localizations.dart';
import '../../../shared/extensions/format.dart';
import '../domain/cash_flow_alerts.dart';
import '../domain/finance_health.dart';
import '../domain/financing_match.dart';
import 'finance_text.dart';

/// Up to three money tips, worked out on the phone from the Money health
/// numbers (replaces the Gemini `money-tips` function; design §2).
///
/// Same rules the Gemini prompt enforced, now guaranteed by construction:
/// every amount is a figure the card already shows, the app's warnings are
/// handled first and in order, each tip is one thing to do this week, and a
/// financing option is only ever "could help -- compare terms", never "take a
/// loan".
List<String> moneyTips({
  required FinanceHealth health,
  required AppLocalizations l10n,
  required String currency,
}) {
  String money(double v) => Money.compact(v, currencyCode: currency);
  final tips = <String>[];

  for (final a in cashFlowAlerts(health)) {
    tips.add(switch (a) {
      OverdueAlert(:final name, :final balance) =>
        l10n.finance_tipOverdue(name, money(balance)),
      CashShortAlert(:final shortBy) => l10n.finance_tipCashShort(money(shortBy)),
      CreditGrowingAlert(:final owedNow) =>
        l10n.finance_tipCreditGrowing(money(owedNow)),
      SalesDropAlert(:final dropPercent) =>
        l10n.finance_tipSalesDrop(Pct.format(dropPercent.roundToDouble())),
    });
    if (tips.length == 3) return tips;
  }

  if (tips.isEmpty) {
    // Healthy shop: tips for keeping it so.
    if (health.owedNow > 0) {
      tips.add(l10n.finance_tipCollectEarly(money(health.owedNow)));
    }
    final digitalShare = health.sales90d > 0
        ? health.digitalSales90d / health.sales90d
        : 0.0;
    if (health.sales90d > 0 && digitalShare < 0.3) {
      tips.add(l10n.finance_tipGoDigital);
    }
  }

  final fit = matchFinancing(health).where((m) => m.fits).firstOrNull;
  if (fit != null && tips.length < 3) {
    tips.add(l10n.finance_tipFinancing(financingName(l10n, fit.kind)));
  }
  if (tips.isEmpty) tips.add(l10n.finance_tipKeepRecording);
  return tips.take(3).toList();
}
