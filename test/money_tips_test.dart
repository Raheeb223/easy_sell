import 'package:ai_shopkeeper/features/finance/domain/finance_health.dart';
import 'package:ai_shopkeeper/features/finance/presentation/money_tips_controller.dart';
import 'package:ai_shopkeeper/features/finance/presentation/money_tips_facts.dart';
import 'package:ai_shopkeeper/features/finance/presentation/money_tips_rules.dart';
import 'package:ai_shopkeeper/l10n/app_localizations_en.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

FinanceHealth _h({double cash = 500, int overdue = 0}) => FinanceHealth(
  cashSales7d: cash,
  digitalSales7d: 0,
  creditSales7d: 0,
  collected7d: 0,
  restockSpend7d: 900,
  salesWeek: 0,
  salesPrevWeek: 0,
  owedNow: 0,
  owedWeekAgo: 0,
  overdueCount: overdue,
  overdueTopName: overdue > 0 ? 'Rahim' : null,
  overdueTopBalance: overdue > 0 ? 1200 : null,
  overdueTopDays: overdue > 0 ? 34 : null,
  sales90d: 0,
  profit90d: 0,
  digitalSales90d: 0,
  restockSpend90d: 0,
  activeWeeks12: 0,
  tradingDays: 10,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('facts', () {
    final l10n = AppLocalizationsEn();

    test('carry the numbers and the same sentences the card shows', () {
      final f = moneyTipsFacts(
        health: _h(overdue: 2),
        l10n: l10n,
        currency: 'USD',
      );
      final week = f['last_7_days'] as Map<String, dynamic>;
      expect(week['money_in'], r'$500');
      expect(week['money_out_restocks_only'], r'$900');
      expect(week['net'], r'-$400');
      final warnings = f['warnings'] as List;
      expect(
        warnings.first,
        r'Rahim owes $1,200.00 for 34 days and 1 more customer is late',
      );
      expect(
        warnings,
        contains(r'Restocks cost $400.00 more than the money that came in'),
      );
      final financing = f['financing_examples'] as List;
      expect(financing, hasLength(4));
      expect((financing.first as Map)['fits'], isFalse);
    });
  });

  group('rules (worked out on the phone)', () {
    final l10n = AppLocalizationsEn();

    test("warnings come first, in order, with the card's own figures", () {
      final tips = moneyTips(health: _h(overdue: 2), l10n: l10n, currency: 'USD');
      expect(tips.first, startsWith('Visit or call Rahim'));
      expect(tips.first, contains(r'$1,200'));
      expect(tips[1], startsWith('Restock smaller'));
      expect(tips.length, lessThanOrEqualTo(3));
    });

    test('a healthy shop gets keep-it-up advice, never invented problems', () {
      final tips = moneyTips(
        health: _h(cash: 2000),
        l10n: l10n,
        currency: 'USD',
      );
      expect(tips, isNotEmpty);
      for (final t in tips) {
        expect(t, isNot(contains('fell')));
        expect(t.toLowerCase(), isNot(contains('take a loan')));
      }
    });
  });

  group('controller', () {
    late ProviderContainer c;

    setUp(() {
      c = ProviderContainer();
      addTearDown(c.dispose);
    });

    void ask(String key, [List<String> tips = const ['Collect from Rahim.']]) =>
        c.read(moneyTipsProvider.notifier).ask(key: key, tips: tips);

    test('a tap shows tips for those numbers', () {
      ask('k1');
      final s = c.read(moneyTipsProvider);
      expect(s, isA<TipsReady>());
      expect((s as TipsReady).tips, ['Collect from Rahim.']);
    });

    test('new numbers replace the old advice', () {
      ask('k1');
      ask('k2', ['Other']);
      expect((c.read(moneyTipsProvider) as TipsReady).key, 'k2');
    });

    test('no tips is reported as a failure for that key', () {
      ask('k1', const []);
      expect(c.read(moneyTipsProvider), isA<TipsFailed>());
    });

    test('the answer survives a restart (saved on the phone)', () async {
      ask('k1');
      await Future<void>.delayed(Duration.zero);
      final fresh = ProviderContainer();
      addTearDown(fresh.dispose);
      fresh.read(moneyTipsProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      final s = fresh.read(moneyTipsProvider);
      expect(s, isA<TipsReady>());
      expect((s as TipsReady).key, 'k1');
    });
  });
}
