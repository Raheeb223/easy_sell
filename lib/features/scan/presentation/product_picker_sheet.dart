import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_ext.dart';
import '../../inventory/domain/product.dart';

/// Bottom sheet listing [products] with a name search; returns the chosen
/// product, or null if dismissed. Reused for the match chooser and manual pick.
/// With [onAddNew], it also offers "Add as new product" (the sheet closes
/// first, then [onAddNew] runs).
Future<Product?> showProductPickerSheet(
  BuildContext context, {
  required List<Product> products,
  required String title,
  String? readLabel,
  VoidCallback? onAddNew,
}) {
  return showModalBottomSheet<Product>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ProductPickerSheet(
      products: products,
      title: title,
      readLabel: readLabel,
      onAddNew: onAddNew,
    ),
  );
}

class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet({
    required this.products,
    required this.title,
    this.readLabel,
    this.onAddNew,
  });

  final List<Product> products;
  final String title;
  final String? readLabel;
  final VoidCallback? onAddNew;

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _q.trim().toLowerCase();
    final list = q.isEmpty
        ? widget.products
        : widget.products
              .where((p) => p.name.toLowerCase().contains(q))
              .toList();
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (widget.readLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              context.l10n.scan_read(widget.readLabel!),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (widget.onAddNew case final VoidCallback addNew) ...[
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.of(context).pop();
                addNew();
              },
              icon: const Icon(Icons.add),
              label: Text(context.l10n.scan_addAsNew),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            autofocus: false,
            onChanged: (v) => setState(() => _q = v),
            decoration: InputDecoration(
              hintText: context.l10n.scan_searchProducts,
              prefixIcon: const Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final p = list[i];
                final subtitle = [
                  p.brand,
                  p.variant,
                ].where((s) => s != null && s.isNotEmpty).join(' · ');
                return ListTile(
                  title: Text(p.name),
                  subtitle: subtitle.isEmpty ? null : Text(subtitle),
                  onTap: () => Navigator.of(context).pop(p),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
