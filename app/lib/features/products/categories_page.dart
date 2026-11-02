import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../ui/design.dart';
import '../../ui/empty_state.dart';
import '../../ui/input_dialog.dart';
import '../../ui/large_title_page.dart';
import '../../ui/layout.dart';

/// 新建分类，返回新分类的 id；取消时返回 null。商品编辑页里也用它。
Future<String?> createCategoryWithDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context);
  final name = await showInputDialog(
    context,
    title: l10n.newCategory,
    label: l10n.categoryName,
    confirmLabel: l10n.add,
    cancelLabel: l10n.cancel,
  );
  if (name == null || name.trim().isEmpty) return null;
  return ref.read(catalogRepositoryProvider).createCategory(name);
}

/// 管理分类：新建、改名、删除、拖动排序。收银台左边的分类栏按这里的顺序显示。
class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});

  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage> {
  /// 刚拖完、数据库还没写回来时先按拖完的顺序显示，避免闪回原位。
  List<ProductCategory>? _reordered;

  Future<void> _rename(ProductCategory c) async {
    final l10n = AppLocalizations.of(context);
    final name = await showInputDialog(
      context,
      title: l10n.rename,
      label: l10n.categoryName,
      initialValue: c.name,
      confirmLabel: l10n.save,
      cancelLabel: l10n.cancel,
    );
    if (name == null || name.trim().isEmpty || name.trim() == c.name) return;
    await ref.read(catalogRepositoryProvider).renameCategory(c.id, name);
  }

  Future<void> _delete(ProductCategory c) async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirmDialog(
      context,
      title: l10n.deleteCategoryTitle(c.name),
      body: l10n.deleteCategoryBody,
      confirmLabel: l10n.delete,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (ok) await ref.read(catalogRepositoryProvider).deleteCategory(c.id);
  }

  void _reorder(List<ProductCategory> list, int from, int to) {
    final order = [...list];
    order.insert(to, order.removeAt(from));
    setState(() => _reordered = order);
    ref.read(catalogRepositoryProvider).reorderCategories([
      for (final c in order) c.id,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    ref.listen(categoriesProvider, (_, _) {
      if (_reordered != null) setState(() => _reordered = null);
    });
    final categories = ref.watch(categoriesProvider);
    final catalog = ref.watch(catalogProvider).value ?? const [];
    int countOf(String id) =>
        catalog.where((p) => p.categoryIds.contains(id)).length;
    Future<void> add() => createCategoryWithDialog(context, ref);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.manageCategories),
        actions: [
          BarButton(
            icon: CupertinoIcons.add,
            tooltip: l10n.newCategory,
            onPressed: add,
          ),
          const SizedBox(width: Gap.sm),
        ],
      ),
      body: categories.when(
        loading: () => asyncLoading,
        error: asyncError,
        data: (data) {
          final list = _reordered ?? data;
          if (list.isEmpty) {
            return EmptyState(
              icon: CupertinoIcons.square_grid_2x2,
              title: l10n.noCategories,
              body: l10n.noCategoriesBody,
              actionLabel: l10n.newCategory,
              onAction: add,
            );
          }
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ReorderableListView.builder(
                padding: withBottomBar(
                  context,
                  const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xl),
                ),
                buildDefaultDragHandles: false,
                header: Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.sm),
                  child: Text(
                    l10n.categoriesHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                itemCount: list.length,
                onReorderItem: (from, to) => _reorder(list, from, to),
                itemBuilder: (context, i) {
                  final c = list[i];
                  const r = Radius.circular(Radii.card);
                  return Column(
                    key: ValueKey(c.id),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.vertical(
                          top: i == 0 ? r : Radius.zero,
                          bottom: i == list.length - 1 ? r : Radius.zero,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsetsDirectional.only(
                            start: Gap.lg,
                            end: Gap.xs,
                          ),
                          title: Text(c.name),
                          subtitle: Text(
                            l10n.categoryProductCount(countOf(c.id)),
                          ),
                          onTap: () => _rename(c),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: l10n.delete,
                                icon: Icon(
                                  CupertinoIcons.trash,
                                  color: theme.colorScheme.error,
                                ),
                                onPressed: () => _delete(c),
                              ),
                              ReorderableDragStartListener(
                                index: i,
                                child: Tooltip(
                                  message: l10n.moveHandle,
                                  child: SizedBox.square(
                                    dimension: minTapSize,
                                    child: Icon(
                                      CupertinoIcons.line_horizontal_3,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (i < list.length - 1)
                        ColoredBox(
                          color: theme.colorScheme.surfaceContainer,
                          child: const Divider(height: 1, indent: Gap.lg),
                        ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
