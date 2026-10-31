import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/motion.dart';
import '../../../core/error/failure.dart';
import '../../../core/l10n/enum_labels.dart';
import '../../../core/l10n/l10n_ext.dart';
import '../../../core/widgets/pressable.dart';
import '../../expiry/presentation/expiry_date_field.dart';
import '../../expiry/presentation/expiry_providers.dart';
import '../domain/product.dart';
import 'category_picker.dart';
import 'inventory_controller.dart';
import 'product_form_controller.dart';

/// Add or edit a product. `product == null` means create.
///
/// The field set is ADAPTIVE: a "How is this item sold?" selector drives whether
/// the item is counted by piece, weighed, or measured by volume. That choice
/// (held in [productFormUnitProvider]) decides whether brand/variant show, the
/// stock unit, decimal vs. whole quantities, and the per-unit price labels.
class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.product, this.initialName});

  final Product? product;

  /// Prefills a new product's name (e.g. the label a scan read). The screen
  /// pops with the saved product.
  final String? initialName;

  bool get isNew => product == null;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _brand;
  late final TextEditingController _variant;
  late final TextEditingController _quantity;
  late final TextEditingController _buyingPrice;
  late final TextEditingController _sellingPrice;
  late final TextEditingController _reorder;
  late final TextEditingController _warnDays;

  /// The first delivery's expiry date (new products only, spec §5).
  DateTime? _expiryDate;

  /// Selected category id (null = uncategorized). Managed here so it survives
  /// rebuilds and is included on save.
  String? _categoryId;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _categoryId = p?.categoryId;
    _name = TextEditingController(text: p?.name ?? widget.initialName ?? '');
    _brand = TextEditingController(text: p?.brand ?? '');
    _variant = TextEditingController(text: p?.variant ?? '');
    _quantity = TextEditingController(
      text: p == null ? '' : Product.trimNum(p.quantity),
    );
    _buyingPrice = TextEditingController(
      text: p == null ? '' : p.buyingPrice.toStringAsFixed(2),
    );
    _sellingPrice = TextEditingController(
      text: p == null ? '' : p.sellingPrice.toStringAsFixed(2),
    );
    _reorder = TextEditingController(
      text: p == null ? '0' : Product.trimNum(p.reorderThreshold),
    );
    _warnDays = TextEditingController(
      text: p?.expiryWarnDays?.toString() ?? '',
    );
    // The expiry field only shows while quantity > 0 (a 0-quantity delivery
    // is rejected by the database), so rebuild as the quantity is typed.
    _quantity.addListener(_onQuantityChanged);

    // Seed the unit selector from the edited product (defaults to piece/pcs for
    // a new one). Done post-frame so we don't mutate a provider mid-initState.
    if (p != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(productFormUnitProvider.notifier).seed(p.unitType, p.unit);
        }
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _variant.dispose();
    _quantity.removeListener(_onQuantityChanged);
    _quantity.dispose();
    _buyingPrice.dispose();
    _sellingPrice.dispose();
    _reorder.dispose();
    _warnDays.dispose();
    super.dispose();
  }

  void _onQuantityChanged() {
    if (mounted) setState(() {});
  }

  String? _emptyToNull(String s) => s.trim().isEmpty ? null : s.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final sel = ref.read(productFormUnitProvider);
    final isPiece = sel.unitType == UnitType.piece;

    final base = widget.product ?? const Product(id: '', shopId: '', name: '');
    final draft = base.copyWith(
      name: _name.text.trim(),
      unitType: sel.unitType,
      unit: sel.unit,
      // Brand/variant only apply to pieces; cleared otherwise.
      brand: isPiece ? _emptyToNull(_brand.text) : null,
      variant: isPiece ? _emptyToNull(_variant.text) : null,
      // Only a new product takes stock here; an edit never changes it (see
      // Product.toUpdateRow).
      quantity: widget.isNew
          ? double.parse(_quantity.text.trim())
          : base.quantity,
      buyingPrice: double.parse(_buyingPrice.text.trim()),
      sellingPrice: double.parse(_sellingPrice.text.trim()),
      reorderThreshold: double.parse(
        _reorder.text.trim().isEmpty ? '0' : _reorder.text.trim(),
      ),
      categoryId: _categoryId,
      expiryWarnDays: _warnDays.text.trim().isEmpty
          ? null
          : int.parse(_warnDays.text.trim()),
    );

    Product? saved;
    final outcome = await ref
        .read(inventoryControllerProvider.notifier)
        .save(
          draft,
          isNew: widget.isNew,
          expiryDate: _expiryDate,
          onSaved: (p) => saved = p,
        );

    if (!mounted || outcome == ProductSaveOutcome.failed) return;
    if (outcome == ProductSaveOutcome.savedWithoutExpiry) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.expiry_savedWithoutDate)),
      );
    }
    Navigator.of(context).pop(saved);
  }

  // --- validation ------------------------------------------------------------

  String? _requiredText(String? v) =>
      (v == null || v.trim().isEmpty) ? context.l10n.form_required : null;

  /// Stock/reorder: non-negative; whole numbers only for pieces.
  String? _quantityField(String? v, {required bool allowDecimal}) {
    final l10n = context.l10n;
    if (v == null || v.trim().isEmpty) return l10n.form_required;
    final s = v.trim();
    final n = double.tryParse(s);
    if (n == null) return l10n.form_enterNumber;
    if (n < 0) return l10n.form_cannotBeNegative;
    if (!allowDecimal && n != n.roundToDouble()) {
      return l10n.form_wholeNumberOnly;
    }
    return null;
  }

  String? _moneyField(String? v) {
    final l10n = context.l10n;
    if (v == null || v.trim().isEmpty) return l10n.form_required;
    final n = double.tryParse(v.trim());
    if (n == null) return l10n.form_enterValidAmount;
    if (n < 0) return l10n.form_cannotBeNegative;
    return null;
  }

  /// Optional whole number of days (the formatter already allows digits only).
  String? _optionalWholeDays(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return int.tryParse(v.trim()) == null
        ? context.l10n.form_wholeNumberOnly
        : null;
  }

  void _unitChangeBlocked() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(context.l10n.expiry_unitChangeBlocked)),
      );
  }

  // --- build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final sel = ref.watch(productFormUnitProvider);
    final unitType = sel.unitType;
    final unit = sel.unit;
    final isLoading = ref.watch(inventoryControllerProvider).isLoading;
    final l10n = context.l10n;
    final perUnit = unitType == UnitType.piece ? '' : ' / ${unit.label}';
    // A product with open deliveries keeps its unit: their amounts are in it.
    final hasDeliveries =
        !widget.isNew &&
        ref.watch(productExpiryProvider).containsKey(widget.product!.id);
    final quantityTyped = double.tryParse(_quantity.text.trim()) ?? 0;

    ref.listen<AsyncValue<void>>(inventoryControllerProvider, (_, next) {
      if (next is AsyncError) {
        final message = switch (next.error) {
          Failure(:final message) => message,
          _ => l10n.common_somethingWrong,
        };
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isNew
              ? l10n.inventory_formAddTitle
              : l10n.inventory_formEditTitle,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // How is this item sold? ------------------------------------
                // Wrapped in a RepaintBoundary so this bordered/elevated card
                // is cached as its own layer — while the keyboard slides up and
                // the scroll view relayouts, it is re-composited rather than
                // repainted every frame, keeping the transition smooth.
                RepaintBoundary(
                  child: _UnitTypeSelector(
                    selected: unitType,
                    onChanged: (t) => hasDeliveries
                        ? _unitChangeBlocked()
                        : ref
                              .read(productFormUnitProvider.notifier)
                              .selectType(t),
                  ),
                ),
                const SizedBox(height: 16),

                _field(
                  _name,
                  l10n.inventory_formName,
                  validator: _requiredText,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                ),

                // Brand + variant only make sense for discrete pieces.
                AnimatedSwitcher(
                  duration: AppMotion.reduced(context)
                      ? Duration.zero
                      : AppMotion.fast,
                  switchInCurve: AppMotion.easeOut,
                  switchOutCurve: AppMotion.easeOut,
                  transitionBuilder: (child, animation) => SizeTransition(
                    sizeFactor: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: unitType.showsBrandVariant
                      ? Column(
                          key: const ValueKey('brand-variant'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _field(
                              _brand,
                              l10n.inventory_formBrand,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                            ),
                            _field(
                              _variant,
                              l10n.inventory_formVariant,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                            ),
                          ],
                        )
                      : const SizedBox(
                          width: double.infinity,
                          key: ValueKey('no-brand-variant'),
                        ),
                ),

                // Reusable, shop-scoped category (with inline add).
                CategoryField(
                  value: _categoryId,
                  onChanged: (id) => setState(() => _categoryId = id),
                ),

                // Stock + reorder, both in the active unit. -----------------
                // Editing has no stock box: stock moves through sales, Restock
                // and Remove from stock only, so a typed number cannot bypass
                // them and the batches. The unit picker moves to Reorder.
                if (!widget.isNew)
                  _field(
                    _reorder,
                    l10n.inventory_formReorderAt,
                    keyboardType: _numberKeyboard(unitType.allowsDecimal),
                    inputFormatters: _numberFormatters(unitType.allowsDecimal),
                    suffixIcon: _UnitSuffix(
                      unitType: unitType,
                      unit: unit,
                      onChanged: (u) => hasDeliveries
                          ? _unitChangeBlocked()
                          : ref
                                .read(productFormUnitProvider.notifier)
                                .selectUnit(u),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        _quantityField(v, allowDecimal: unitType.allowsDecimal),
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _StockField(
                          controller: _quantity,
                          unitType: unitType,
                          unit: unit,
                          onUnitChanged: (u) => hasDeliveries
                              ? _unitChangeBlocked()
                              : ref
                                    .read(productFormUnitProvider.notifier)
                                    .selectUnit(u),
                          validator: (v) => _quantityField(
                            v,
                            allowDecimal: unitType.allowsDecimal,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          _reorder,
                          l10n.inventory_formReorderAt,
                          keyboardType: _numberKeyboard(unitType.allowsDecimal),
                          inputFormatters: _numberFormatters(
                            unitType.allowsDecimal,
                          ),
                          suffixText: unit.label,
                          textInputAction: TextInputAction.next,
                          validator: (v) => _quantityField(
                            v,
                            allowDecimal: unitType.allowsDecimal,
                          ),
                        ),
                      ),
                    ],
                  ),

                if (widget.isNew && quantityTyped > 0)
                  ExpiryDateField(
                    value: _expiryDate,
                    enabled: !isLoading,
                    onChanged: (d) => setState(() => _expiryDate = d),
                  ),

                // Per-unit prices. ------------------------------------------
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        _buyingPrice,
                        l10n.inventory_formBuyingPrice(perUnit),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: _numberFormatters(true),
                        textInputAction: TextInputAction.next,
                        validator: _moneyField,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(
                        _sellingPrice,
                        l10n.inventory_formSellingPrice(perUnit),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: _numberFormatters(true),
                        textInputAction: TextInputAction.done,
                        validator: _moneyField,
                      ),
                    ),
                  ],
                ),

                Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(l10n.expiry_moreOptions),
                    initiallyExpanded: widget.product?.expiryWarnDays != null,
                    children: [
                      _field(
                        _warnDays,
                        l10n.expiry_warnDaysLabel,
                        helperText: l10n.expiry_warnDaysHint,
                        keyboardType: _numberKeyboard(false),
                        inputFormatters: _numberFormatters(false),
                        textInputAction: TextInputAction.done,
                        validator: _optionalWholeDays,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                FilledButton(
                  onPressed: isLoading ? null : _save,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          widget.isNew
                              ? l10n.inventory_formCreate
                              : l10n.inventory_formSaveChanges,
                        ),
                ),

                // Quick-fill examples that showcase the three selling modes.
                if (widget.isNew) ...[
                  const SizedBox(height: 24),
                  RepaintBoundary(child: _ExamplePicker(onPick: _applyExample)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _applyExample(_Example e) {
    _name.text = e.name;
    _brand.text = e.brand ?? '';
    _variant.text = e.variant ?? '';
    _quantity.text = e.quantity;
    _reorder.text = e.reorder;
    _buyingPrice.text = e.buying.toStringAsFixed(2);
    _sellingPrice.text = e.selling.toStringAsFixed(2);
    ref.read(productFormUnitProvider.notifier).seed(e.unitType, e.unit);
    setState(() {});
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? suffixText,
    Widget? suffixIcon,
    String? helperText,
    String? Function(String?)? validator,
    TextInputAction? textInputAction,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        textInputAction: textInputAction,
        textCapitalization: textCapitalization,
        // "Next" on the keyboard jumps to the following field so the whole form
        // can be filled without reaching for the screen between fields.
        onFieldSubmitted: textInputAction == TextInputAction.next
            ? (_) => FocusScope.of(context).nextFocus()
            : null,
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffixText,
          suffixIcon: suffixIcon,
          helperText: helperText,
        ),
        validator: validator,
      ),
    );
  }
}

// --- shared input helpers ----------------------------------------------------

TextInputType _numberKeyboard(bool decimal) =>
    TextInputType.numberWithOptions(decimal: decimal);

List<TextInputFormatter> _numberFormatters(bool decimal) => [
  FilteringTextInputFormatter.allow(
    decimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
  ),
];

// --- unit-type selector ------------------------------------------------------

/// The "How is this item sold?" segmented selector — three tappable cards with
/// an icon, a label, and a one-line hint describing the active mode.
class _UnitTypeSelector extends StatelessWidget {
  const _UnitTypeSelector({required this.selected, required this.onChanged});

  final UnitType selected;
  final ValueChanged<UnitType> onChanged;

  static const _icons = {
    UnitType.piece: Icons.view_in_ar_outlined,
    UnitType.weight: Icons.scale_outlined,
    UnitType.volume: Icons.water_drop_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.inventory_formHowSold,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final type in UnitType.values) ...[
                  if (type != UnitType.values.first) const SizedBox(width: 10),
                  Expanded(
                    child: _UnitTypeCard(
                      icon: _icons[type]!,
                      label: unitTypeLabel(context.l10n, type),
                      selected: type == selected,
                      onTap: () => onChanged(type),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              unitTypeHint(context.l10n, selected),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitTypeCard extends StatelessWidget {
  const _UnitTypeCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.primary : scheme.onSurfaceVariant;
    return PressableScale(
      onTap: onTap,
      scale: 0.96,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: AppMotion.reduced(context) ? Duration.zero : AppMotion.fast,
        curve: AppMotion.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.10)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: fg, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: fg,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- stock field with inline unit selector -----------------------------------

/// Stock amount plus a unit selector. Pieces show a fixed "pcs"; weight/volume
/// expose a dropdown (kg/g or litre/ml) so the same field adapts to the mode.
class _StockField extends StatelessWidget {
  const _StockField({
    required this.controller,
    required this.unitType,
    required this.unit,
    required this.onUnitChanged,
    required this.validator,
  });

  final TextEditingController controller;
  final UnitType unitType;
  final ProductUnit unit;
  final ValueChanged<ProductUnit> onUnitChanged;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    final allowDecimal = unitType.allowsDecimal;
    final label = unitType == UnitType.piece
        ? context.l10n.inventory_formStockPieces
        : context.l10n.inventory_formStock;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: _numberKeyboard(allowDecimal),
        inputFormatters: _numberFormatters(allowDecimal),
        textInputAction: TextInputAction.next,
        onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: _UnitSuffix(
            unitType: unitType,
            unit: unit,
            onChanged: onUnitChanged,
          ),
        ),
        validator: validator,
      ),
    );
  }
}

class _UnitSuffix extends StatelessWidget {
  const _UnitSuffix({
    required this.unitType,
    required this.unit,
    required this.onChanged,
  });

  final UnitType unitType;
  final ProductUnit unit;
  final ValueChanged<ProductUnit> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Single-unit modes (pieces) just show the label — nothing to choose.
    if (unitType.units.length == 1) {
      return Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Align(
          alignment: Alignment.centerRight,
          widthFactor: 1,
          child: Text(
            unit.label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ProductUnit>(
          value: unit,
          isDense: true,
          borderRadius: BorderRadius.circular(12),
          onChanged: (u) {
            if (u != null) onChanged(u);
          },
          items: [
            for (final u in unitType.units)
              DropdownMenuItem(value: u, child: Text(u.label)),
          ],
        ),
      ),
    );
  }
}

// --- quick-fill examples -----------------------------------------------------

class _Example {
  const _Example({
    required this.name,
    required this.unitType,
    required this.unit,
    required this.quantity,
    required this.reorder,
    required this.buying,
    required this.selling,
    this.brand,
    this.variant,
  });

  final String name;
  final UnitType unitType;
  final ProductUnit unit;
  final String quantity;
  final String reorder;
  final double buying;
  final double selling;
  final String? brand;
  final String? variant;
}

class _ExamplePicker extends StatelessWidget {
  const _ExamplePicker({required this.onPick});

  final ValueChanged<_Example> onPick;

  static const _examples = [
    _Example(
      name: 'Lifebuoy soap',
      brand: 'Lifebuoy',
      unitType: UnitType.piece,
      unit: ProductUnit.pcs,
      quantity: '48',
      reorder: '10',
      buying: 25,
      selling: 35,
    ),
    _Example(
      name: 'Pepsi',
      variant: '500ml',
      unitType: UnitType.piece,
      unit: ProductUnit.pcs,
      quantity: '24',
      reorder: '6',
      buying: 30,
      selling: 45,
    ),
    _Example(
      name: 'Loose rice',
      unitType: UnitType.weight,
      unit: ProductUnit.kg,
      quantity: '25',
      reorder: '5',
      buying: 60,
      selling: 80,
    ),
    _Example(
      name: 'Loose oil',
      unitType: UnitType.volume,
      unit: ProductUnit.litre,
      quantity: '10',
      reorder: '2',
      buying: 150,
      selling: 185,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.inventory_formTryExample,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final e in _examples)
              OutlinedButton(
                onPressed: () => onPick(e),
                child: Text(
                  e.variant == null ? e.name : '${e.name} ${e.variant}',
                ),
              ),
          ],
        ),
      ],
    );
  }
}
