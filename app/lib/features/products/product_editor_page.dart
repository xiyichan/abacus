import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/catalog_repository.dart';
import '../../data/database.dart';
import '../../domain/stock.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../ui/empty_state.dart';
import '../../ui/input_dialog.dart';
import '../../ui/media.dart';
import '../../ui/money.dart';

const _newCreator = '__new__';

/// 新建或编辑商品。[productId] 为 null 时是新建。
class ProductEditorPage extends ConsumerStatefulWidget {
  const ProductEditorPage({super.key, this.productId});

  final String? productId;

  @override
  ConsumerState<ProductEditorPage> createState() => _ProductEditorPageState();
}

class _VariantRow {
  _VariantRow({this.id, String label = '', int? price, int cost = 0})
    : label = TextEditingController(text: label),
      price = TextEditingController(
        text: price == null ? '' : moneyInputText(price),
      ),
      cost = TextEditingController(text: cost == 0 ? '' : moneyInputText(cost));

  final String? id;
  final TextEditingController label;
  final TextEditingController price;
  final TextEditingController cost;

  void dispose() {
    label.dispose();
    price.dispose();
    cost.dispose();
  }
}

class _ComponentRow {
  _ComponentRow(this.variantId, this.quantity);

  String variantId;
  int quantity;
}

class _ProductEditorPageState extends ConsumerState<ProductEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _tags = TextEditingController();
  String _kind = ProductKind.single;
  String? _creatorId;

  /// 取消新建作者时加一，强制下拉框重建回到原来的值。
  int _creatorFieldVersion = 0;
  String? _imagePath;
  final List<_VariantRow> _variants = [];
  final List<_ComponentRow> _components = [];
  List<CatalogProduct> _catalog = const [];
  bool _loaded = false;
  bool _saving = false;
  String? _listError;

  bool get _isNew => widget.productId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final catalog = await ref.read(catalogProvider.future);
    final existing = catalog
        .where((p) => p.product.id == widget.productId)
        .firstOrNull;
    if (!mounted) return;
    setState(() {
      _catalog = catalog;
      if (existing == null) {
        _variants.add(_VariantRow());
      } else {
        final p = existing.product;
        _name.text = p.name;
        _tags.text = p.tags;
        _kind = p.kind;
        _creatorId = p.creatorId;
        _imagePath = p.imagePath;
        for (final v in existing.variants) {
          _variants.add(
            _VariantRow(id: v.id, label: v.label, price: v.price, cost: v.cost),
          );
        }
        if (_variants.isEmpty) _variants.add(_VariantRow());
        for (final c
            in existing.components.values.firstOrNull ??
                const <BundleComponent>[]) {
          _components.add(_ComponentRow(c.variantId, c.quantity));
        }
      }
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _tags.dispose();
    for (final v in _variants) {
      v.dispose();
    }
    super.dispose();
  }

  /// 可以放进套装的规格：非套装商品的所有规格（排除自己）。
  List<(Variant, String)> get _componentOptions => [
    for (final p in _catalog)
      if (!p.isBundle && p.product.id != widget.productId)
        for (final v in p.variants) (v, p.displayName(v)),
  ];

  void _setKind(String kind) {
    setState(() {
      _kind = kind;
      _listError = null;
      // 单品和套装只有一个规格。
      if (kind != ProductKind.variants) {
        while (_variants.length > 1) {
          _variants.removeLast().dispose();
        }
      }
    });
  }

  Future<void> _pickCreator(String? value) async {
    if (value != _newCreator) {
      setState(() => _creatorId = value);
      return;
    }
    final l10n = AppLocalizations.of(context);
    final name = await showInputDialog(
      context,
      title: l10n.newCreator,
      label: l10n.creatorName,
      confirmLabel: l10n.add,
      cancelLabel: l10n.cancel,
    );
    if (!mounted) return;
    if (name == null || name.trim().isEmpty) {
      setState(() => _creatorFieldVersion++); // 让下拉框回到原来的值
      return;
    }
    final id = await ref.read(catalogRepositoryProvider).createCreator(name);
    if (mounted) setState(() => _creatorId = id);
  }

  Future<void> _pickImage() async {
    final name = await pickAndStoreImage(ref);
    if (name != null && mounted) setState(() => _imagePath = name);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _listError = null);
    final valid = _formKey.currentState!.validate();
    if (_kind == ProductKind.bundle && _components.isEmpty) {
      setState(() => _listError = l10n.needComponent);
      return;
    }
    if (!valid) return;

    final draft = ProductDraft(
      id: widget.productId,
      name: _name.text,
      kind: _kind,
      creatorId: _creatorId,
      tags: _tags.text,
      imagePath: _imagePath,
      variants: [
        for (final row in _variants)
          VariantDraft(
            id: row.id,
            label: _kind == ProductKind.variants ? row.label.text : '',
            price: parseMoney(row.price.text)!,
            cost: parseMoney(row.cost.text) ?? 0,
          ),
      ],
      components: [
        for (final c in _components) BundleComponent(c.variantId, c.quantity),
      ],
    );
    setState(() => _saving = true);
    await ref.read(catalogRepositoryProvider).saveProduct(draft);
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirmDialog(
      context,
      title: l10n.deleteProductTitle,
      body: l10n.deleteProductBody,
      confirmLabel: l10n.delete,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(catalogRepositoryProvider).deleteProduct(widget.productId!);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.addProduct : l10n.editProduct),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: l10n.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _loaded && !_saving ? _save : null,
              child: Text(l10n.save),
            ),
          ),
        ],
      ),
      body: !_loaded
          ? asyncLoading
          : Form(
              key: _formKey,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _imageAndName(l10n),
                      const SizedBox(height: 16),
                      _creatorField(l10n),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _tags,
                        decoration: InputDecoration(
                          labelText: l10n.tags,
                          hintText: l10n.tagsHint,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                            value: ProductKind.single,
                            label: Text(l10n.kindSingle),
                          ),
                          ButtonSegment(
                            value: ProductKind.variants,
                            label: Text(l10n.kindVariants),
                          ),
                          ButtonSegment(
                            value: ProductKind.bundle,
                            label: Text(l10n.kindBundle),
                          ),
                        ],
                        selected: {_kind},
                        // 已有商品不能在套装与普通商品之间切换，避免库存和订单对不上。
                        onSelectionChanged: (s) {
                          final next = s.single;
                          final crossesBundle =
                              (next == ProductKind.bundle) !=
                              (_kind == ProductKind.bundle);
                          if (!_isNew && crossesBundle) return;
                          _setKind(next);
                        },
                      ),
                      const SizedBox(height: 16),
                      ...switch (_kind) {
                        ProductKind.variants => _variantsSection(l10n),
                        ProductKind.bundle => _bundleSection(l10n),
                        _ => [
                          _variantFields(
                            l10n,
                            _variants.first,
                            showLabel: false,
                          ),
                        ],
                      },
                      if (_listError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _listError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _imageAndName(AppLocalizations l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _pickImage,
          onLongPress: _imagePath == null
              ? null
              : () => setState(() => _imagePath = null),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox.square(
              dimension: 88,
              child: StoredImage(
                _imagePath,
                placeholder: ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_photo_alternate_outlined),
                      const SizedBox(height: 4),
                      Text(
                        l10n.chooseImage,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            controller: _name,
            autofocus: _isNew,
            decoration: InputDecoration(labelText: l10n.productName),
            validator: (v) => (v ?? '').trim().isEmpty ? l10n.required : null,
          ),
        ),
      ],
    );
  }

  Widget _creatorField(AppLocalizations l10n) {
    final creators = ref.watch(creatorsProvider).value ?? const [];
    final value = creators.any((c) => c.id == _creatorId) ? _creatorId : null;
    return DropdownButtonFormField<String?>(
      key: ValueKey((value, _creatorFieldVersion)),
      initialValue: value,
      decoration: InputDecoration(labelText: l10n.creator),
      items: [
        DropdownMenuItem(value: null, child: Text(l10n.none)),
        for (final c in creators)
          DropdownMenuItem(value: c.id, child: Text(c.name)),
        DropdownMenuItem(value: _newCreator, child: Text(l10n.newCreator)),
      ],
      onChanged: _pickCreator,
    );
  }

  List<Widget> _variantsSection(AppLocalizations l10n) => [
    for (final row in _variants)
      Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
          child: _variantFields(
            l10n,
            row,
            showLabel: true,
            onRemove: _variants.length > 1
                ? () => setState(() => _variants.remove(row..dispose()))
                : null,
          ),
        ),
      ),
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => setState(() {
          // 新规格默认沿用上一个规格的价格。
          final last = _variants.lastOrNull;
          _variants.add(
            _VariantRow(
              price: last == null ? null : parseMoney(last.price.text),
            ),
          );
        }),
        icon: const Icon(Icons.add),
        label: Text(l10n.addVariant),
      ),
    ),
  ];

  Widget _variantFields(
    AppLocalizations l10n,
    _VariantRow row, {
    required bool showLabel,
    VoidCallback? onRemove,
  }) {
    final currency = ref.watch(currencySymbolProvider);
    String? moneyValidator(String? v) =>
        parseMoney(v ?? '') == null ? l10n.invalidAmount : null;
    String? optionalMoney(String? v) =>
        (v ?? '').isEmpty || parseMoney(v!) != null ? null : l10n.invalidAmount;

    final fields = <Widget>[
      if (showLabel)
        TextFormField(
          controller: row.label,
          decoration: InputDecoration(
            labelText: l10n.variantLabel,
            hintText: l10n.variantLabelHint,
          ),
          validator: (v) => (v ?? '').trim().isEmpty ? l10n.required : null,
        ),
      TextFormField(
        controller: row.price,
        keyboardType: moneyKeyboard,
        inputFormatters: moneyInputFormatters,
        decoration: InputDecoration(
          labelText: l10n.price,
          prefixText: '$currency ',
        ),
        validator: moneyValidator,
      ),
      TextFormField(
        controller: row.cost,
        keyboardType: moneyKeyboard,
        inputFormatters: moneyInputFormatters,
        decoration: InputDecoration(
          labelText: l10n.cost,
          prefixText: '$currency ',
        ),
        validator: optionalMoney,
      ),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 宽屏时并排，窄屏时两两一行。
              final perRow = constraints.maxWidth > 520 ? fields.length : 2;
              final width = (constraints.maxWidth - 12 * (perRow - 1)) / perRow;
              return Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  for (final f in fields) SizedBox(width: width, child: f),
                ],
              );
            },
          ),
        ),
        if (onRemove != null)
          IconButton(
            tooltip: l10n.delete,
            icon: const Icon(Icons.close),
            onPressed: onRemove,
          ),
      ],
    );
  }

  List<Widget> _bundleSection(AppLocalizations l10n) {
    final money = ref.watch(moneyProvider);
    final currency = ref.watch(currencySymbolProvider);
    final options = _componentOptions;
    final priceOf = {for (final (v, _) in options) v.id: v.price};
    final value = _components.fold<int>(
      0,
      (a, c) => a + (priceOf[c.variantId] ?? 0) * c.quantity,
    );
    final row = _variants.first;
    return [
      TextFormField(
        controller: row.price,
        keyboardType: moneyKeyboard,
        inputFormatters: moneyInputFormatters,
        decoration: InputDecoration(
          labelText: l10n.bundlePrice,
          prefixText: '$currency ',
          helperText: _components.isEmpty
              ? null
              : l10n.componentsValue(money(value)),
        ),
        validator: (v) =>
            parseMoney(v ?? '') == null ? l10n.invalidAmount : null,
      ),
      const SizedBox(height: 16),
      Text(
        l10n.bundleComponents,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 8),
      if (options.isEmpty)
        Text(l10n.noComponentsAvailable)
      else ...[
        for (final c in _components)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: c.variantId,
                    isExpanded: true,
                    items: [
                      for (final (v, name) in options)
                        DropdownMenuItem(
                          value: v.id,
                          child: Text(name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() => c.variantId = v!),
                  ),
                ),
                const SizedBox(width: 8),
                _QuantityStepper(
                  value: c.quantity,
                  onChanged: (q) => setState(() {
                    if (q <= 0) {
                      _components.remove(c);
                    } else {
                      c.quantity = q;
                    }
                  }),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(
              () => _components.add(_ComponentRow(options.first.$1.id, 1)),
            ),
            icon: const Icon(Icons.add),
            label: Text(l10n.addComponent),
          ),
        ),
      ],
    ];
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: () => onChanged(value - 1),
        ),
        Text('×$value', style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => onChanged(value + 1),
        ),
      ],
    );
  }
}
