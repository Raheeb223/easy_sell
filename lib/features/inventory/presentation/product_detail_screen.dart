import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/haptics.dart';
import '../../../core/config/theme.dart';
import '../../../core/error/failure.dart';
import '../../../core/l10n/l10n_ext.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/brand_fill.dart';
import '../../../shared/extensions/format.dart';
import '../../auth/data/auth_repository.dart';
import '../../cart/presentation/add_to_cart_sheet.dart';
import '../../expiry/presentation/deliveries_section.dart';
import '../../expiry/presentation/expiry_providers.dart';
import '../../scan/presentation/teach_photos_section.dart';
import '../../transactions/presentation/transaction_confirmation_sheet.dart';
import '../domain/product.dart';
import 'category_controller.dart';
import 'inventory_controller.dart';

/// Read-only product details with edit/delete and sale/restock actions. Looks
/// the product up by id from the realtime stream so it reflects live edits and
/// stock changes.
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsStreamProvider);
    final currency = ref.watch(myShopProvider).value?.currency ?? 'USD';

    ref.listen<AsyncValue<void>>(inventoryControllerProvider, (_, next) {
      if (next is AsyncError) {
        final message = switch (next.error) {
          Failure(:final message) => message,
          _ => context.l10n.common_somethingWrong,
        };
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });

    return productsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(context.l10n.inventory_couldNotLoadProduct)),
      ),
      data: (products) {
        final matches = products.where((p) => p.id == productId);
        if (matches.isEmpty) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(context.l10n.inventory_productGone)),
          );
        }
        return _DetailView(product: matches.first, currency: currency);
      },
    );
  }
}

class _DetailView extends ConsumerWidget {
  const _DetailView({required this.product, required this.currency});

  final Product product;
  final String currency;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.inventory_removeTitle),
        content: Text(l10n.inventory_removeBody(product.name)),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(
                    l10n.common_cancel,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    softWrap: false,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(
                    l10n.common_delete,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    softWrap: false,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final controller = ref.read(inventoryControllerProvider.notifier);
    final ok = await controller.delete(product.id);
    if (!ok) return; // failure SnackBar is surfaced by the screen's listener

    if (context.mounted) context.pop();
    // Soft delete → offer a one-tap Undo that restores it. The notifier (not
    // autoDispose) and the app-level messenger both outlive the popped screen.
    //
    // The framework's built-in auto-dismiss timer doesn't fire for this SnackBar
    // on device (action SnackBars stay up under accessible navigation), so we
    // run our own 5s timer and close it. Swipe-to-dismiss still works; the
    // `dismissed` guard makes closing an already-gone SnackBar a no-op, and the
    // long `duration` is just a backstop so the framework never races our timer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!messenger.mounted) return;
      messenger.clearSnackBars();
      final snackBar = messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.inventory_removed(product.name)),
          duration: const Duration(seconds: 30),
          action: SnackBarAction(
            label: l10n.common_undo,
            onPressed: () {
              AppHaptics.tap();
              controller.restore(product.id);
            },
          ),
        ),
      );
      var dismissed = false;
      snackBar.closed.whenComplete(() => dismissed = true);
      Timer(const Duration(seconds: 5), () {
        if (!dismissed && messenger.mounted) snackBar.close();
      });
    });
  }

  Future<void> _addToCart(BuildContext context) async {
    // Manual sale entry point. // MEMBER B: a parsed voice/image intent
    // resolves to this same product + a quantity, then stages it into the
    // cart the same way — the Cart screen's checkout is the only commit path,
    // so AI output is never auto-committed.
    final added = await showAddToCartSheet(context, product: product);
    if (added == true && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.l10n.common_addedToCart)),
        );
    }
  }

  Future<void> _restock(BuildContext context) async {
    final recorded = await showRestockSheet(context, product: product);
    if (recorded == true && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.l10n.common_stockAdded)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final subtitle = [
      if (product.brand?.isNotEmpty ?? false) product.brand!,
      if (product.variant?.isNotEmpty ?? false) product.variant!,
    ].join(' · ');

    // Resolve the category name from its id (live).
    String? categoryName;
    if (product.categoryId != null) {
      final cats = ref.watch(categoriesStreamProvider).value ?? const [];
      for (final c in cats) {
        if (c.id == product.categoryId) {
          categoryName = c.name;
          break;
        }
      }
    }

    // Low stock judges GOOD stock: 5 expired + 1 good is low (spec §5).
    final isLow = product.isLowStockAt(ref.watch(goodStockProvider(product)));

    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        actions: [
          _BarAction(
            tooltip: l10n.common_edit,
            icon: Icons.edit_outlined,
            onPressed: () =>
                context.push('/inventory/${product.id}/edit', extra: product),
          ),
          const SizedBox(width: 8),
          _BarAction(
            tooltip: l10n.common_delete,
            icon: Icons.delete_outline,
            onPressed: () => _confirmDelete(context, ref),
          ),
          const SizedBox(width: 12),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _restock(context),
                  icon: const Icon(Icons.add_box_outlined),
                  label: Text(l10n.common_restock),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: product.quantity == 0
                      ? null
                      : () => _addToCart(context),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Text(l10n.common_addToCart),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 15,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (categoryName != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 10,
                  ),
                  decoration: idleFillDecoration(context),
                  child: Text(
                    categoryName,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 15,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
          // The gap lives inside the conditional so it collapses with the card
          // when stock is healthy, instead of doubling the space above the
          // stats card.
          if (isLow) ...[
            AppCard(
              color: colors.warningBg,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: colors.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.inventory_lowStock,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          l10n.inventory_reorderThresholdNote(
                            product.reorderLabel,
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _statRow(
                  context,
                  l10n.inventory_statInStock,
                  product.quantityLabel,
                ),
                _statRow(
                  context,
                  l10n.inventory_statBuyingPrice,
                  Money.format(product.buyingPrice, currencyCode: currency),
                ),
                _statRow(
                  context,
                  l10n.inventory_statSellingPrice,
                  Money.format(product.sellingPrice, currencyCode: currency),
                ),
                _statRow(
                  context,
                  l10n.inventory_statMarginPerUnit,
                  Money.format(product.marginPerUnit, currencyCode: currency),
                ),
                _statRow(
                  context,
                  l10n.inventory_statInventoryValue,
                  Money.format(product.inventoryValue, currencyCode: currency),
                ),
                _statRow(
                  context,
                  l10n.inventory_statReorderThreshold,
                  product.reorderThreshold <= 0
                      ? l10n.common_off
                      : product.reorderLabel,
                  last: true,
                ),
              ],
            ),
          ),
          TeachPhotosSection(product: product),
          DeliveriesSection(product: product),
        ],
      ),
    );
  }

  /// One outlined label/value row inside the stats card (design §8, Product
  /// detail): ~60 high, radius 16.
  Widget _statRow(
    BuildContext context,
    String label,
    String value, {
    bool last = false,
  }) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    return Container(
      margin: EdgeInsets.only(bottom: last ? 0 : 10),
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: colors.rowDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// An AppBar action as a rounded-square glass button (edit, delete).
class _BarAction extends StatelessWidget {
  const _BarAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: idleFillDecoration(
        context,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        color: isDark ? colors.iconButton : null,
      ),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon),
        onPressed: onPressed,
        style: IconButton.styleFrom(
          fixedSize: const Size(44, 44),
          minimumSize: const Size(44, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
