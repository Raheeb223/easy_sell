import 'package:ai_shopkeeper/core/config/theme.dart';
import 'package:ai_shopkeeper/core/error/failure.dart';
import 'package:ai_shopkeeper/features/finance/domain/finance_health.dart';
import 'package:ai_shopkeeper/features/finance/presentation/finance_providers.dart';
import 'package:ai_shopkeeper/features/finance/presentation/finance_screen.dart';
import 'package:ai_shopkeeper/features/finance/presentation/money_health_card.dart';
import 'package:ai_shopkeeper/l10n/app_localizations.dart';
import 'package:ai_shopkeeper/shared/providers/locale_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

FinanceHealth _h({
  double cash = 0,
  double restock = 0,
  double owedNow = 0,
  int overdue = 0,
  int tradingDays = 0,
  double sales90 = 0,
  double restock90 = 0,
  int weeks = 0,
}) => FinanceHealth(
  cashSales7d: cash,
  digitalSales7d: 0,
  creditSales7d: 0,
  collected7d: 0,
  restockSpend7d: restock,
  salesWeek: 0,
  salesPrevWeek: 0,
  owedNow: owedNow,
  owedWeekAgo: owedNow,
  overdueCount: overdue,
  overdueTopName: overdue > 0 ? 'Rahim' : null,
  overdueTopBalance: overdue > 0 ? 1200 : null,
  overdueTopDays: overdue > 0 ? 34 : null,
  sales90d: sales90,
  profit90d: sales90 * 0.2,
  digitalSales90d: 0,
  restockSpend90d: restock90,
  activeWeeks12: weeks,
  tradingDays: tradingDays,
);

Future<void> _pump(
  WidgetTester tester,
  AsyncValue<FinanceHealth> value,
  Widget home, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        financeHealthProvider.overrideWith((ref) {
          return switch (value) {
            AsyncData(:final value) => Future.value(value),
            AsyncError(:final error) => Future.error(error),
            _ => Future.delayed(const Duration(days: 1), () => _h()),
          };
        }),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: locale,
        supportedLocales: supportedAppLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('AI advice: only on tap, then shown with its caveat', (
    tester,
  ) async {
    await _pump(
      tester,
      AsyncValue.data(_h(cash: 300, restock: 800, overdue: 2)),
      const Scaffold(body: SingleChildScrollView(child: MoneyHealthCard())),
    );
    expect(find.textContaining('Visit or call'), findsNothing);
    await tester.tap(find.text('Get advice from EasySell AI'));
    await tester.pump();
    await tester.pump();
    expect(find.text('AI advice'), findsOneWidget);
    // Worked out on the phone from the card's own warnings.
    expect(find.textContaining('Visit or call'), findsOneWidget);
    expect(find.textContaining('Check them before you act'), findsOneWidget);
    expect(find.text('Get advice from EasySell AI'), findsNothing);
  });

  group('Home card', () {
    const card = Scaffold(
      body: SingleChildScrollView(child: MoneyHealthCard()),
    );

    testWidgets('shows in / out / net and the warnings', (tester) async {
      await _pump(
        tester,
        AsyncValue.data(_h(cash: 300, restock: 800, overdue: 2)),
        card,
      );
      expect(find.text('Money health'), findsOneWidget);
      expect(find.text(r'$300'), findsOneWidget);
      expect(find.text(r'$800'), findsOneWidget);
      expect(find.text(r'-$500'), findsOneWidget);
      expect(find.text(r'Rahim owes $1,200.00 for 34 days'), findsOneWidget);
      expect(
        find.text(r'Restocks cost $500.00 more than the money that came in'),
        findsOneWidget,
      );
      expect(find.text('See financing options for your shop'), findsOneWidget);
    });

    testWidgets('a calm week says so', (tester) async {
      await _pump(tester, AsyncValue.data(_h(cash: 500, restock: 100)), card);
      expect(find.text('No money warnings this week'), findsOneWidget);
    });

    testWidgets('counts the financing options that fit', (tester) async {
      await _pump(
        tester,
        AsyncValue.data(
          _h(
            cash: 500,
            tradingDays: 200,
            sales90: 9000,
            restock90: 6000,
            weeks: 12,
          ),
        ),
        card,
      );
      // Supplier credit + microfinance fit; wallet (no digital) and SME
      // (under 12 months) do not.
      expect(find.text('2 financing options fit your shop'), findsOneWidget);
    });

    testWidgets('fits a 360 dp phone in Bangla with big amounts', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await _pump(
        tester,
        AsyncValue.data(_h(cash: 1234567, restock: 9876543, overdue: 3)),
        card,
        locale: const Locale('bn'),
      );
      expect(find.text('টাকার অবস্থা'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hidden for a shop with no money movement', (tester) async {
      await _pump(tester, AsyncValue.data(_h()), card);
      expect(find.text('Money health'), findsNothing);
    });

    testWidgets('hidden on error (e.g. 0019 not run yet)', (tester) async {
      await _pump(
        tester,
        AsyncValue.error(const DatabaseFailure('missing'), StackTrace.empty),
        card,
      );
      expect(find.text('Money health'), findsNothing);
    });
  });

  group('Money health screen', () {
    testWidgets('lists fits first, not-yets with what to do, and the '
        'disclaimer', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await _pump(
        tester,
        AsyncValue.data(
          _h(
            cash: 500,
            tradingDays: 200,
            sales90: 9000,
            restock90: 6000,
            weeks: 12,
          ),
        ),
        const FinanceScreen(),
      );
      expect(find.text('Financing for your shop'), findsOneWidget);
      expect(find.text('Fits you'), findsNWidgets(2));
      expect(find.text('Not yet'), findsNWidgets(2));
      expect(find.text(r'You restock about $2,000.00 a month'), findsOneWidget);
      expect(find.text(r'Up to about $2,000.00'), findsOneWidget);
      expect(find.text('Keep trading 6 more months'), findsOneWidget);
      expect(
        find.text('Take at least 10% of sales digitally (now 0%)'),
        findsOneWidget,
      );
      expect(find.textContaining('not loan offers'), findsOneWidget);
      // Fits come first on the page.
      final supplier = tester.getTopLeft(find.text('Supplier credit')).dy;
      final sme = tester.getTopLeft(find.text('Bank SME loan')).dy;
      expect(supplier, lessThan(sme));
    });

    testWidgets('error shows a retry', (tester) async {
      await _pump(
        tester,
        AsyncValue.error(const DatabaseFailure('missing'), StackTrace.empty),
        const FinanceScreen(),
      );
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
