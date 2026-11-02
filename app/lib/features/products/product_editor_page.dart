import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/catalog_repository.dart';
import '../../data/database.dart';
import '../../domain/stock.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../ui/layout.dart';
import '../../ui/design.dart';
import '../../ui/empty_state.dart';
import '../../ui/grouped_list.dart';
import '../../ui/input_dialog.dart';
import '../../ui/media.dart';
import '../../ui/money.dart';
import 'categories_page.dart';

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
  List<String> _categoryIds = [];

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
        _categoryIds = existing.categoryIds;
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

  /// 分类：可以选多个；最后一个是“新建分类”。
  Widget _categoryField(AppLocalizations l10n) {
    final categories = ref.watch(categoriesProvider).value ?? const [];
    // 分组卡片里的内容默认居中，这里让标签从左边排起。
    return Container(
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsets.all(Gap.md),
      child: Wrap(
        spacing: Gap.sm,
        runSpacing: Gap.sm,
        children: [
          for (final c in categories)
            FilterChip(
              label: Text(c.name),
              selected: _categoryIds.contains(c.id),
              onSelected: (on) => setState(() {
                _categoryIds = on
                    ? [..._categoryIds, c.id]
                    : [
                        for (final id in _categoryIds)
                          if (id != c.id) id,
                      ];
              }),
            ),
          ActionChip(
            avatar: const Icon(CupertinoIcons.add, size: 18),
            label: Text(l10n.newCategory),
            onPressed: () async {
              final id = await createCategoryWithDialog(context, ref);
              if (id != null && mounted) {
                setState(() => _categoryIds = [..._categoryIds, id]);
              }
            },
          ),
        ],
      ),
    );
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
    final name = await pickAndStoreImage(ref, maxSize: 1024);
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
      // 已经删掉的分类不再保存。
      categoryIds: [
        for (final id in _categoryIds)
          if (ref.read(categoriesProvider).value?.any((c) => c.id == id) ??
              true)
            id,
      ],
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
    final theme = Theme.of(context);
    final noMargin = const EdgeInsets.only(bottom: Gap.lg);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.addProduct : l10n.editProduct),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Gap.sm),
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
                    padding: withBottomBar(
                      context,
                      const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.lg),
                    ),
                    children: [
                      _imageHeader(l10n),
                      const SizedBox(height: Gap.lg),
                      GroupedSection(
                        margin: noMargin,
                        children: [
                          _InlineField(
                            label: l10n.productName,
                            controller: _name,
                            autofocus: _isNew,
                            validator: (v) =>
                                (v ?? '').trim().isEmpty ? l10n.required : null,
                          ),
                          _creatorField(l10n),
                          _InlineField(
                            label: l10n.tags,
                            controller: _tags,
                            hint: l10n.tagsHint,
                          ),
                        ],
                      ),
                      GroupedSection(
                        header: l10n.categories,
                        margin: noMargin,
                        children: [_categoryField(l10n)],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Gap.lg,
                          Gap.xs,
                          Gap.lg,
                          6,
                        ),
                        child: Text(
                          l10n.productKindAndPrice,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
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
                      const SizedBox(height: Gap.md),
                      ...switch (_kind) {
                        ProductKind.variants => _variantsSection(l10n),
                        ProductKind.bundle => _bundleSection(l10n),
                        _ => _singleSection(l10n),
                      },
                      if (_listError != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            Gap.lg,
                            0,
                            Gap.lg,
                            Gap.lg,
                          ),
                          child: Text(
                            _listError!,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      if (!_isNew)
                        GroupedSection(
                          margin: const EdgeInsets.only(top: Gap.sm),
                          children: [
                            ListTile(
                              title: Text(
                                l10n.deleteProduct,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onTap: _delete,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  /// 顶部居中的大图：点一下选图，有图时下面多一个“移除图片”。
  Widget _imageHeader(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasImage = _imagePath != null;
    return Column(
      children: [
        Semantics(
          button: true,
          label: hasImage ? l10n.changeImage : l10n.chooseImage,
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.card),
            onTap: _pickImage,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.card),
                  child: SizedBox.square(
                    dimension: 120,
                    // 没有图片时跟着名字显示首字色块，和列表、收银台里一样。
                    child: StoredImage(
                      _imagePath,
                      placeholder: ValueListenableBuilder(
                        valueListenable: _name,
                        builder: (context, name, _) => name.text.trim().isEmpty
                            ? ColoredBox(
                                color: scheme.primaryContainer,
                                child: Icon(
                                  CupertinoIcons.photo,
                                  size: 40,
                                  color: scheme.onPrimaryContainer.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              )
                            : NamePlaceholder(name.text.trim()),
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  end: -6,
                  bottom: -6,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.surface, width: 3),
                    ),
                    child: Icon(
                      CupertinoIcons.camera_fill,
                      size: 16,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.xs),
        TextButton(
          onPressed: hasImage
              ? () => setState(() => _imagePath = null)
              : _pickImage,
          child: Text(hasImage ? l10n.removeImage : l10n.chooseImage),
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
      decoration: _inlineDecoration(context, label: l10n.creator),
      icon: Icon(
        CupertinoIcons.chevron_up_chevron_down,
        size: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      padding: const EdgeInsetsDirectional.only(end: Gap.lg),
      borderRadius: BorderRadius.circular(Radii.sm),
      style: Theme.of(context).textTheme.bodyLarge,
      items: [
        DropdownMenuItem(value: null, child: Text(l10n.none)),
        for (final c in creators)
          DropdownMenuItem(value: c.id, child: Text(c.name)),
        DropdownMenuItem(value: _newCreator, child: Text(l10n.newCreator)),
      ],
      onChanged: _pickCreator,
    );
  }

  String? _requiredMoney(String? v) => parseMoney(v ?? '') == null
      ? AppLocalizations.of(context).invalidAmount
      : null;

  String? _optionalMoney(String? v) =>
      (v ?? '').isEmpty || parseMoney(v!) != null
      ? null
      : AppLocalizations.of(context).invalidAmount;

  List<Widget> _singleSection(AppLocalizations l10n) {
    final currency = ref.watch(currencySymbolProvider);
    final row = _variants.first;
    return [
      GroupedSection(
        margin: const EdgeInsets.only(bottom: Gap.lg),
        children: [
          _InlineField.money(
            label: l10n.price,
            controller: row.price,
            currency: currency,
            validator: _requiredMoney,
          ),
          _InlineField.money(
            label: l10n.cost,
            controller: row.cost,
            currency: currency,
            hint: l10n.optional,
            validator: _optionalMoney,
          ),
        ],
      ),
    ];
  }

  /// 多规格：一张表，每行是“规格名 / 售价 / 成本”，最后一行是“添加规格”。
  List<Widget> _variantsSection(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final currency = ref.watch(currencySymbolProvider);
    final muted = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final canRemove = _variants.length > 1;
    Widget head(String title) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.md),
      child: Text(title, style: muted),
    );
    Widget columns(Widget a, Widget b, Widget c, [Widget? trailing]) => Row(
      children: [
        Expanded(flex: 5, child: a),
        Expanded(flex: 4, child: b),
        Expanded(flex: 4, child: c),
        SizedBox(width: 44, child: trailing),
      ],
    );
    return [
      GroupedSection(
        margin: const EdgeInsets.only(bottom: Gap.lg),
        dividerIndent: Gap.lg,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(Gap.xs, Gap.md, 0, 0),
            // 标题和单元格用同样的左内边距，列对齐。
            child: columns(
              head(l10n.variantLabel),
              head(l10n.price),
              head(l10n.cost),
            ),
          ),
          for (final row in _variants)
            Padding(
              key: ObjectKey(row),
              padding: const EdgeInsetsDirectional.only(start: Gap.xs),
              child: columns(
                _CellField(
                  controller: row.label,
                  hint: l10n.variantLabelHint,
                  semanticLabel: l10n.variantLabel,
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? l10n.required : null,
                ),
                _CellField(
                  controller: row.price,
                  money: true,
                  prefix: '$currency ',
                  semanticLabel: l10n.price,
                  validator: _requiredMoney,
                ),
                _CellField(
                  controller: row.cost,
                  money: true,
                  prefix: '$currency ',
                  hint: l10n.optional,
                  semanticLabel: l10n.cost,
                  validator: _optionalMoney,
                ),
                canRemove
                    ? IconButton(
                        tooltip: l10n.delete,
                        icon: Icon(
                          CupertinoIcons.minus_circle_fill,
                          color: theme.colorScheme.error,
                          size: 22,
                        ),
                        onPressed: () =>
                            setState(() => _variants.remove(row..dispose())),
                      )
                    : null,
              ),
            ),
          _AddRow(
            label: l10n.addVariant,
            onTap: () => setState(() {
              // 新规格默认沿用上一个规格的价格。
              final last = _variants.lastOrNull;
              _variants.add(
                _VariantRow(
                  price: last == null ? null : parseMoney(last.price.text),
                ),
              );
            }),
          ),
        ],
      ),
    ];
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
      GroupedSection(
        margin: const EdgeInsets.only(bottom: Gap.lg),
        footer: _components.isEmpty ? null : l10n.componentsValue(money(value)),
        children: [
          _InlineField.money(
            label: l10n.bundlePrice,
            controller: row.price,
            currency: currency,
            validator: _requiredMoney,
          ),
        ],
      ),
      GroupedSection(
        header: l10n.bundleComponents,
        margin: const EdgeInsets.only(bottom: Gap.lg),
        children: [
          if (options.isEmpty)
            ListTile(title: Text(l10n.noComponentsAvailable))
          else ...[
            for (final c in _components)
              Padding(
                key: ObjectKey(c),
                padding: const EdgeInsetsDirectional.only(end: Gap.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: c.variantId,
                        isExpanded: true,
                        decoration: _cellDecoration(context),
                        // 单元格自带左内边距，合起来和上面的标题对齐。
                        padding: const EdgeInsetsDirectional.only(
                          start: Gap.lg - Gap.md,
                        ),
                        icon: Icon(
                          CupertinoIcons.chevron_up_chevron_down,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        borderRadius: BorderRadius.circular(Radii.sm),
                        items: [
                          for (final (v, name) in options)
                            DropdownMenuItem(
                              value: v.id,
                              child: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() => c.variantId = v!),
                      ),
                    ),
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
            _AddRow(
              label: l10n.addComponent,
              onTap: () => setState(
                () => _components.add(_ComponentRow(options.first.$1.id, 1)),
              ),
            ),
          ],
        ],
      ),
    ];
  }
}

/// 分组卡片里的输入框：没有边框和底色，左边是标题（iOS 表单样式）。
/// [currency] 不为空时标题后面一直显示货币符号。
InputDecoration _inlineDecoration(
  BuildContext context, {
  required String label,
  String? hint,
  String? currency,
}) {
  final theme = Theme.of(context);
  final muted = theme.colorScheme.onSurfaceVariant;
  return InputDecoration(
    filled: false,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    contentPadding: const EdgeInsetsDirectional.fromSTEB(0, 16, Gap.lg, 16),
    prefixIcon: Padding(
      padding: const EdgeInsetsDirectional.only(start: Gap.lg, end: Gap.md),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题列一共 76 宽；有货币符号时它占标题列最右边的一格，
          // 这样金额和上面名称等文字从同一条线开始。
          ConstrainedBox(
            constraints: BoxConstraints(minWidth: currency == null ? 76 : 62),
            child: Text(label, style: theme.textTheme.bodyLarge),
          ),
          if (currency != null)
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 14),
              child: Text(
                currency,
                style: theme.textTheme.bodyLarge?.copyWith(color: muted),
              ),
            ),
        ],
      ),
    ),
    prefixIconConstraints: const BoxConstraints(minWidth: 0),
    hintText: hint,
    hintStyle: theme.textTheme.bodyLarge?.copyWith(
      color: muted.withValues(alpha: 0.6),
    ),
  );
}

/// 表格单元格里的输入框：没有边框，只有占位文字。
InputDecoration _cellDecoration(
  BuildContext context, {
  String? hint,
  String? prefix,
}) {
  final theme = Theme.of(context);
  return InputDecoration(
    filled: false,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: Gap.md,
      vertical: 14,
    ),
    prefixText: prefix,
    hintText: hint,
    hintStyle: theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
    ),
  );
}

class _InlineField extends StatelessWidget {
  const _InlineField({
    required this.label,
    required this.controller,
    this.hint,
    this.validator,
    this.autofocus = false,
  }) : currency = null;

  const _InlineField.money({
    required this.label,
    required this.controller,
    required String this.currency,
    this.hint,
    this.validator,
  }) : autofocus = false;

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? currency;
  final FormFieldValidator<String>? validator;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final money = currency != null;
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: money ? moneyKeyboard : null,
      inputFormatters: money ? moneyInputFormatters : null,
      decoration: _inlineDecoration(
        context,
        label: label,
        hint: hint,
        currency: currency,
      ),
      validator: validator,
    );
  }
}

class _CellField extends StatelessWidget {
  const _CellField({
    required this.controller,
    required this.semanticLabel,
    this.hint,
    this.prefix,
    this.money = false,
    this.validator,
  });

  final TextEditingController controller;

  /// 没有可见标题，读屏时用列名。
  final String semanticLabel;
  final String? hint;
  final String? prefix;
  final bool money;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    child: TextFormField(
      controller: controller,
      keyboardType: money ? moneyKeyboard : null,
      inputFormatters: money ? moneyInputFormatters : null,
      decoration: _cellDecoration(context, hint: hint, prefix: prefix),
      validator: validator,
    ),
  );
}

/// 分组卡片最后一行的“＋ 添加…”。
class _AddRow extends StatelessWidget {
  const _AddRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(CupertinoIcons.plus_circle_fill, color: scheme.primary),
      minLeadingWidth: 0,
      horizontalTitleGap: Gap.md,
      title: Text(
        label,
        style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
      ),
      onTap: onTap,
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: l10n.removeOne,
          icon: Icon(CupertinoIcons.minus_circle, color: scheme.primary),
          onPressed: () => onChanged(value - 1),
        ),
        Text('×$value', style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          tooltip: l10n.addOne,
          icon: Icon(CupertinoIcons.plus_circle_fill, color: scheme.primary),
          onPressed: () => onChanged(value + 1),
        ),
      ],
    );
  }
}
