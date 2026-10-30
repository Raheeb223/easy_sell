import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/motion.dart';
import '../widgets/app_backdrop.dart';

import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/customers/presentation/customer_detail_screen.dart';
import '../../features/customers/presentation/customers_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/expiry/presentation/expiry_alerts_screen.dart';
import '../../features/finance/presentation/finance_screen.dart';
import '../../features/inventory/domain/product.dart';
import '../../features/inventory/presentation/archived_products_screen.dart';
import '../../features/inventory/presentation/inventory_list_screen.dart';
import '../../features/inventory/presentation/manage_categories_screen.dart';
import '../../features/inventory/presentation/product_detail_screen.dart';
import '../../features/inventory/presentation/product_form_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/onboarding/presentation/welcome_screen.dart';
import '../../features/restock/presentation/restock_screen.dart';
import '../../features/scan/presentation/scan_session_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/shell/presentation/main_shell.dart';
import '../../features/transactions/domain/transaction.dart';
import '../../features/transactions/presentation/history_screen.dart';
import '../../features/transactions/presentation/sale_detail_screen.dart';
import '../../shared/providers/onboarding_provider.dart';

/// Centralized route path constants — reference these instead of raw strings.
class AppRoutes {
  const AppRoutes._();

  static const String welcome = '/welcome';
  static const String onboarding = '/onboarding';
  static const String dashboard = '/';
  static const String inventory = '/inventory';
  static const String analytics = '/analytics';
  static const String history = '/history';
  static const String settings = '/settings';
  static const String alerts = '/alerts';
  static const String restock = '/restock';
  static const String finance = '/finance';
  static const String categories = '/categories';
  static const String archivedProducts = '/archived-products';
  static const String customers = '/customers';
  static const String saleDetail = '/history/sale';
}

/// The root navigator's key.
///
/// Public because anything mounted *above* the router — `app.dart`'s builder
/// hosts the offline and voice banners there so they outlive navigation — has
/// no `Navigator` ancestor of its own and so cannot push a route from its own
/// context. This key is the only handle on a context that can.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Wraps a screen in a shared slide-and-fade page transition. Forward navigation
/// eases the new screen in from a short rightward offset while fading; back
/// navigation reverses it. Honours reduced-motion by skipping the movement.
/// Pass [slide] false for top-level destinations (auth/onboarding) that should
/// just crossfade rather than imply spatial depth.
CustomTransitionPage<void> _transitionPage(Widget child, {bool slide = true}) {
  return CustomTransitionPage<void>(
    // Inside the transition, so each page carries its own opaque backdrop.
    child: AppBackdrop(child: child),
    transitionDuration: AppMotion.page,
    reverseTransitionDuration: AppMotion.exit,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (AppMotion.reduced(context)) return child;
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.easeOut,
        reverseCurve: AppMotion.easeInOut,
      );
      final fade = FadeTransition(opacity: curved, child: child);
      if (!slide) return fade;
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.06, 0),
          end: Offset.zero,
        ).animate(curved),
        child: fade,
      );
    },
  );
}

/// The app router: a [StatefulShellRoute] hosts the four bottom-nav destinations
/// (Home / Items / Reports / History); onboarding, product detail/forms and the
/// settings sub-pages render full-screen on the root navigator.
///
/// Redirects: first launch → /welcome; no shop on this phone yet →
/// /onboarding; otherwise the app. There is no sign-in: the shop lives on the
/// phone (phone-only design). Refreshes on shop and onboarding changes.
final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(myShopProvider, (_, _) => refresh.value++);
  ref.listen(onboardingSeenProvider, (_, _) => refresh.value++);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.dashboard,
    refreshListenable: refresh,
    redirect: (context, state) {
      final seenOnboarding = ref.read(onboardingSeenProvider);
      final loc = state.matchedLocation;
      final setupLoc = loc == AppRoutes.welcome || loc == AppRoutes.onboarding;

      return ref
          .read(myShopProvider)
          .maybeWhen(
            data: (shop) {
              if (shop == null) {
                // First launch shows the welcome page once, then shop setup.
                if (!seenOnboarding) {
                  return loc == AppRoutes.welcome ? null : AppRoutes.welcome;
                }
                return loc == AppRoutes.onboarding ? null : AppRoutes.onboarding;
              }
              return setupLoc ? AppRoutes.dashboard : null;
            },
            // The shop row loads in milliseconds; stay put until it has.
            orElse: () => null,
          );
    },
    routes: [
      GoRoute(
        path: AppRoutes.welcome,
        pageBuilder: (_, _) =>
            _transitionPage(const WelcomeScreen(), slide: false),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        pageBuilder: (_, _) =>
            _transitionPage(const OnboardingScreen(), slide: false),
      ),

      // Bottom-nav shell.
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                builder: (_, _) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.inventory,
                builder: (_, _) => const InventoryListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.analytics,
                builder: (_, _) => const AnalyticsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.history,
                builder: (_, _) => const HistoryScreen(),
              ),
            ],
          ),
        ],
      ),

      // Full-screen routes (root navigator — no bottom bar).
      GoRoute(
        path: '/inventory/new',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) => _transitionPage(const ProductFormScreen()),
      ),
      GoRoute(
        path: '/cart',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) => _transitionPage(const CartScreen()),
      ),
      GoRoute(
        path: '/scan',
        builder: (context, state) =>
            const AppBackdrop(child: ScanSessionScreen()),
      ),
      GoRoute(
        path: '/inventory/:id',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, state) => _transitionPage(
          ProductDetailScreen(productId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/inventory/:id/edit',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, state) => _transitionPage(
          ProductFormScreen(product: state.extra as Product?),
        ),
      ),
      GoRoute(
        path: AppRoutes.settings,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) => _transitionPage(const SettingsScreen()),
      ),
      GoRoute(
        path: AppRoutes.alerts,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) => _transitionPage(const ExpiryAlertsScreen()),
      ),
      GoRoute(
        path: AppRoutes.restock,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) => _transitionPage(const RestockScreen()),
      ),
      GoRoute(
        path: AppRoutes.finance,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) => _transitionPage(const FinanceScreen()),
      ),
      GoRoute(
        path: AppRoutes.categories,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) => _transitionPage(const ManageCategoriesScreen()),
      ),
      GoRoute(
        path: AppRoutes.archivedProducts,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) => _transitionPage(const ArchivedProductsScreen()),
      ),
      GoRoute(
        path: AppRoutes.customers,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) => _transitionPage(const CustomersScreen()),
      ),
      GoRoute(
        path: '/customers/:id',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, state) => _transitionPage(
          CustomerDetailScreen(customerId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/history/sale/:id',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, state) => _transitionPage(
          SaleDetailScreen(sale: state.extra as Transaction?),
        ),
      ),
    ],
  );
});
