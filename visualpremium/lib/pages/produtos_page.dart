import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:visualpremium/data/products_repository.dart';
import 'package:visualpremium/data/materials_repository.dart';
import 'package:visualpremium/models/product_item.dart';
import 'package:visualpremium/models/material_item.dart';
import 'package:visualpremium/theme.dart';

enum SortOption {
  newestFirst,
  oldestFirst,
  nameAsc,
  nameDesc,
  materialsAsc,
  materialsDesc,
}

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _api = ProductsApiRepository();
  final _materialsApi = MaterialsApiRepository();
  bool _loading = true;
  List<ProductItem> _items = const [];
  List<MaterialItem> _availableMaterials = const [];
  String _searchQuery = '';
  SortOption _sortOption = SortOption.newestFirst;

  Future<void> _showProductEditor(ProductItem? initial) async {
    final result = await showDialog<ProductItem>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return ProductEditorSheet(
          initial: initial,
          availableMaterials: _availableMaterials,
          existingProducts: _items,
        );
      },
    );

    if (result != null) {
      await _upsert(result);
    }
  }

  Future<bool?> _showConfirmDelete(String productName) {
    final theme = Theme.of(context);
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: _ConfirmDeleteSheet(productName: productName),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final products = await _api.fetchProducts();
      final materials = await _materialsApi.fetchMaterials();
      products.sort((a, b) {
        final dateA = a.updatedAt ?? a.createdAt;
        final dateB = b.updatedAt ?? b.createdAt;
        return dateB.compareTo(dateA);
      });
      if (!mounted) return;
      setState(() {
        _items = products;
        _availableMaterials = materials;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar produtos: $e')),
      );
    }
  }

  Future<void> _upsert(ProductItem item) async {
    setState(() => _loading = true);
    try {
      ProductItem updated;
      if (_items.any((e) => e.id == item.id)) {
        updated = await _api.updateProduct(item);
      } else {
        updated = await _api.createProduct(item);
      }
      final idx = _items.indexWhere((e) => e.id == updated.id);
      final next = [..._items];
      if (idx == -1) {
        next.insert(0, updated);
      } else {
        next[idx] = updated;
      }
      if (!mounted) return;
      setState(() {
        _items = next;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar produto: $e')),
      );
    }
  }

  Future<void> _delete(ProductItem item) async {
    setState(() => _loading = true);
    try {
      await _api.deleteProduct(item.id);
      final next = _items.where((e) => e.id != item.id).toList(growable: false);
      if (!mounted) return;
      setState(() {
        _items = next;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      
      final errorMessage = e.toString();
      if (errorMessage.contains('Produto em uso') || 
          errorMessage.contains('sendo usado') ||
          errorMessage.contains('orçamento')) {
        _showProductInUseDialog(item.name, errorMessage);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao deletar produto: $e')),
        );
      }
    }
  }

  Future<void> _showProductInUseDialog(String productName, String errorMessage) {
    final theme = Theme.of(context);
    return showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: theme.colorScheme.error,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Produto em uso',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'O produto "$productName" não pode ser excluído porque está sendo usado em um ou mais orçamentos.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.error.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Para excluir este produto, primeiro remova-o dos orçamentos que o utilizam.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ExcludeFocus(
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Entendi'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<ProductItem> get _filteredAndSortedItems {
    var filtered = _items;
    
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((item) {
        return item.name.toLowerCase().contains(query) ||
            item.materials.any((m) => m.materialNome.toLowerCase().contains(query));
      }).toList();
    } else {
      filtered = List.from(filtered);
    }
    
    switch (_sortOption) {
      case SortOption.newestFirst:
        filtered.sort((a, b) {
          final dateA = a.updatedAt ?? a.createdAt;
          final dateB = b.updatedAt ?? b.createdAt;
          return dateB.compareTo(dateA);
        });
        break;
      case SortOption.oldestFirst:
        filtered.sort((a, b) {
          final dateA = a.updatedAt ?? a.createdAt;
          final dateB = b.updatedAt ?? b.createdAt;
          return dateA.compareTo(dateB);
        });
        break;
      case SortOption.nameAsc:
        filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case SortOption.nameDesc:
        filtered.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case SortOption.materialsAsc:
        filtered.sort((a, b) => a.materials.length.compareTo(b.materials.length));
        break;
      case SortOption.materialsDesc:
        filtered.sort((a, b) => b.materials.length.compareTo(a.materials.length));
        break;
    }
    
    return filtered;
  }

  void _toggleDateSort() {
    setState(() {
      if (_sortOption == SortOption.newestFirst) {
        _sortOption = SortOption.oldestFirst;
      } else if (_sortOption == SortOption.oldestFirst) {
        _sortOption = SortOption.newestFirst;
      } else {
        _sortOption = SortOption.newestFirst;
      }
    });
  }

  void _toggleNameSort() {
    setState(() {
      if (_sortOption == SortOption.nameAsc) {
        _sortOption = SortOption.nameDesc;
      } else if (_sortOption == SortOption.nameDesc) {
        _sortOption = SortOption.nameAsc;
      } else {
        _sortOption = SortOption.nameAsc;
      }
    });
  }

  void _toggleMaterialsSort() {
    setState(() {
      if (_sortOption == SortOption.materialsAsc) {
        _sortOption = SortOption.materialsDesc;
      } else if (_sortOption == SortOption.materialsDesc) {
        _sortOption = SortOption.materialsAsc;
      } else {
        _sortOption = SortOption.materialsDesc;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredItems = _filteredAndSortedItems;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(32.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 32,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Produtos',
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                ExcludeFocus(
                                  child: IconButton(
                                    onPressed: _load,
                                    icon: const Icon(Icons.refresh),
                                    tooltip: 'Atualizar',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ExcludeFocus(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showProductEditor(null),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Novo Produto'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: theme.colorScheme.primary,
                                      foregroundColor: theme.colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: theme.cardTheme.color,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                          ),
                          child: TextField(
                            onChanged: (value) => setState(() => _searchQuery = value),
                            decoration: InputDecoration(
                              hintText: 'Buscar por nome ou material',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              icon: Icon(Icons.search, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_loading)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            child: Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
                              ),
                            ),
                          )
                        else if (filteredItems.isEmpty)
                          _EmptyProductsState(
                            hasSearch: _searchQuery.isNotEmpty,
                            onCreate: () => _showProductEditor(null),
                          )
                        else
                          ExcludeFocus(
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredItems.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                return _ProductCard(
                                  item: item,
                                  onTap: () => _showProductEditor(item),
                                  onDelete: () async {
                                    final ok = await _showConfirmDelete(item.name);
                                    if (ok == true) await _delete(item);
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  ExcludeFocus(
                    child: _FilterPanel(
                      sortOption: _sortOption,
                      onToggleDateSort: _toggleDateSort,
                      onToggleNameSort: _toggleNameSort,
                      onToggleMaterialsSort: _toggleMaterialsSort,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 3,
                child: LinearProgressIndicator(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  final SortOption sortOption;
  final VoidCallback onToggleDateSort;
  final VoidCallback onToggleNameSort;
  final VoidCallback onToggleMaterialsSort;

  const _FilterPanel({
    required this.sortOption,
    required this.onToggleDateSort,
    required this.onToggleNameSort,
    required this.onToggleMaterialsSort,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      width: 280,
      margin: const EdgeInsets.only(top: 67),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.sort,
                size: 34,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Ordenar por',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SortOptionWithToggle(
            label: 'Data',
            icon: Icons.schedule,
            isSelected: sortOption == SortOption.newestFirst || sortOption == SortOption.oldestFirst,
            isAscending: sortOption == SortOption.oldestFirst,
            ascendingLabel: 'Mais antigo',
            descendingLabel: 'Mais recente',
            onTap: onToggleDateSort,
          ),
          const SizedBox(height: 8),
          _SortOptionWithToggle(
            label: 'Nome',
            icon: Icons.sort_by_alpha,
            isSelected: sortOption == SortOption.nameAsc || sortOption == SortOption.nameDesc,
            isAscending: sortOption == SortOption.nameAsc,
            ascendingLabel: 'A-Z',
            descendingLabel: 'Z-A',
            onTap: onToggleNameSort,
          ),
          const SizedBox(height: 8),
          _SortOptionWithToggle(
            label: 'Nº de Materiais',
            icon: Icons.inventory_2_outlined,
            isSelected: sortOption == SortOption.materialsAsc || sortOption == SortOption.materialsDesc,
            isAscending: sortOption == SortOption.materialsAsc,
            ascendingLabel: 'Menor',
            descendingLabel: 'Maior',
            onTap: onToggleMaterialsSort,
          ),
        ],
      ),
    );
  }
}

class _SortOptionWithToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isAscending;
  final String ascendingLabel;
  final String descendingLabel;
  final VoidCallback onTap;

  const _SortOptionWithToggle({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isAscending,
    required this.ascendingLabel,
    required this.descendingLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isAscending ? ascendingLabel : descendingLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                color: theme.colorScheme.secondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${item.materials.length} ${item.materials.length == 1 ? 'material' : 'materiais'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
              onSelected: (value) {
                if (value == 'delete') {
                  onDelete();
                }
              },
              tooltip: 'Filtrar',
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Excluir'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyProductsState extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onCreate;

  const _EmptyProductsState({required this.hasSearch, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (hasSearch) {
      return Container(
        padding: const EdgeInsets.all(48),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.search_off, size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'Nenhum produto encontrado',
              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.inventory_2_outlined, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nenhum produto cadastrado', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Cadastre produtos e associe materiais a eles.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.65))),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ExcludeFocus(
            child: ElevatedButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('Cadastrar')),
          ),
        ],
      ),
    );
  }
}

class ProductEditorSheet extends StatefulWidget {
  final ProductItem? initial;
  final List<MaterialItem> availableMaterials;
  final List<ProductItem> existingProducts;

  const ProductEditorSheet({
    super.key,
    required this.initial,
    required this.availableMaterials,
    required this.existingProducts,
  });

  @override
  State<ProductEditorSheet> createState() => _ProductEditorSheetState();
}

class _ProductEditorSheetState extends State<ProductEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  final Set<int> _selectedMaterialIds = {};
  final FocusNode _dialogFocusNode = FocusNode();
  final FocusNode _nameFocusNode = FocusNode();
  bool _isShowingDiscardDialog = false;
  
  late final String _initialName;
  late final Set<int> _initialMaterialIds;

  @override
  void initState() {
    super.initState();
    _initialName = widget.initial?.name ?? '';
    _nameCtrl = TextEditingController(text: _initialName);
    
    if (widget.initial != null) {
      for (final pm in widget.initial!.materials) {
        _selectedMaterialIds.add(pm.materialId);
      }
    }
    
    _initialMaterialIds = Set.from(_selectedMaterialIds);
    
    _nameFocusNode.addListener(_onFieldFocusChange);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dialogFocusNode.requestFocus();
    });
  }

  void _onFieldFocusChange() {
    if (!_nameFocusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && !_isShowingDiscardDialog) {
          _dialogFocusNode.requestFocus();
        }
      });
    }
  }

  bool get _hasChanges {
    if (_nameCtrl.text.trim() != _initialName.trim()) {
      return true;
    }
    
    return !_selectedMaterialIds.containsAll(_initialMaterialIds) || 
           !_initialMaterialIds.containsAll(_selectedMaterialIds);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dialogFocusNode.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _showMaterialSelector() async {
    final result = await showDialog<Set<int>>(
      context: context,
      builder: (dialogContext) {
        return _MaterialSelectorDialog(
          availableMaterials: widget.availableMaterials,
          selectedMaterialIds: Set.from(_selectedMaterialIds),
        );
      },
    );
    
    if (result != null) {
      setState(() {
        _selectedMaterialIds.clear();
        _selectedMaterialIds.addAll(result);
      });
    }
  }

  void _removeMaterial(int materialId) {
    setState(() {
      _selectedMaterialIds.remove(materialId);
    });
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    
    if (_isShowingDiscardDialog) return false;
    
    _isShowingDiscardDialog = true;
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(dialogContext).pop(false);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: AlertDialog(
          title: const Text('Descartar alterações?'),
          content: const Text('Você tem alterações não salvas. Deseja descartá-las?'),
          actions: [
            ExcludeFocus(
              child: TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
            ),
            ExcludeFocus(
              child: TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Descartar'),
              ),
            ),
          ],
        ),
      ),
    );
    
    _isShowingDiscardDialog = false;
    
    if (result == false || result == null) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _dialogFocusNode.requestFocus();
        }
      });
    }
    
    return result ?? false;
  }

  String? _validateProductName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Informe o nome';
    }
    
    final trimmedName = value.trim();
    final isDuplicate = widget.existingProducts.any((product) =>
        product.name.toLowerCase() == trimmedName.toLowerCase() &&
        product.id != widget.initial?.id);
    
    if (isDuplicate) {
      return 'Já existe um produto com este nome';
    }
    
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    final selectedMaterials = widget.availableMaterials
        .where((m) => _selectedMaterialIds.contains(int.parse(m.id)))
        .toList();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final shouldPop = await _onWillPop();
            if (shouldPop && context.mounted) {
              context.pop();
            }
          },
          child: GestureDetector(
            onTap: () {
              _dialogFocusNode.requestFocus();
            },
            child: Focus(
              focusNode: _dialogFocusNode,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
                  _onWillPop().then((shouldPop) {
                    if (shouldPop && mounted && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  });
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: bottomInset),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.initial == null ? 'Novo produto' : 'Editar produto',
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          ExcludeFocus(
                            child: IconButton(
                              onPressed: () async {
                                final shouldClose = await _onWillPop();
                                if (shouldClose && context.mounted) {
                                  context.pop();
                                }
                              },
                              icon: const Icon(Icons.close),
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              tooltip: 'Fechar (Esc)',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _nameCtrl,
                              focusNode: _nameFocusNode,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(labelText: 'Nome do produto'),
                              validator: _validateProductName,
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Materiais',
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                ExcludeFocus(
                                  child: ElevatedButton.icon(
                                    onPressed: _showMaterialSelector,
                                    icon: const Icon(Icons.add, size: 18),
                                    label: Text(_selectedMaterialIds.isEmpty ? 'Selecionar materiais' : 'Editar seleção'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_selectedMaterialIds.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                                ),
                                child: Center(
                                  child: Text(
                                    'Nenhum material selecionado',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                              )
                            else
                              ExcludeFocus(
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: selectedMaterials.map((material) {
                                    final materialId = int.parse(material.id);
                                    return Chip(
                                      label: Text(material.name),
                                      deleteIcon: const Icon(Icons.close, size: 18),
                                      onDeleted: () => _removeMaterial(materialId),
                                      backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                                      labelStyle: TextStyle(
                                        color: theme.colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      deleteIconColor: theme.colorScheme.onPrimaryContainer,
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ExcludeFocus(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final shouldClose = await _onWillPop();
                                  if (shouldClose && context.mounted) {
                                    context.pop();
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                  side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.18)),
                                  foregroundColor: theme.colorScheme.onSurface,
                                ),
                                child: const Text('Cancelar'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ExcludeFocus(
                              child: ElevatedButton(
                                onPressed: () {
                                  if (!_formKey.currentState!.validate()) return;
                                  
                                  final validMaterials = _selectedMaterialIds
                                      .map((id) {
                                        final material = widget.availableMaterials.firstWhere(
                                          (m) => m.id == id.toString(),
                                        );
                                        return ProductMaterial(
                                          materialId: id,
                                          materialNome: material.name,
                                        );
                                      })
                                      .toList();

                                  final now = DateTime.now();
                                  final item = (widget.initial ??
                                          ProductItem(
                                            id: now.microsecondsSinceEpoch.toString(),
                                            name: '',
                                            materials: const [],
                                            createdAt: now,
                                          ))
                                      .copyWith(
                                    name: _nameCtrl.text.trim(),
                                    materials: validMaterials,
                                  );
                                  context.pop(item);
                                },
                                child: Text(widget.initial == null ? 'Cadastrar' : 'Salvar'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MaterialSelectorDialog extends StatefulWidget {
  final List<MaterialItem> availableMaterials;
  final Set<int> selectedMaterialIds;

  const _MaterialSelectorDialog({
    required this.availableMaterials,
    required this.selectedMaterialIds,
  });

  @override
  State<_MaterialSelectorDialog> createState() => _MaterialSelectorDialogState();
}

class _MaterialSelectorDialogState extends State<_MaterialSelectorDialog> {
  late Set<int> _tempSelectedIds;
  String _searchQuery = '';
  final FocusNode _dialogFocusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _tempSelectedIds = Set.from(widget.selectedMaterialIds);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _dialogFocusNode.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<MaterialItem> get _filteredMaterials {
    if (_searchQuery.isEmpty) {
      return widget.availableMaterials;
    }
    
    final query = _searchQuery.toLowerCase();
    return widget.availableMaterials
        .where((m) => m.name.toLowerCase().contains(query))
        .toList();
  }

  void _toggleMaterial(int materialId) {
    setState(() {
      if (_tempSelectedIds.contains(materialId)) {
        _tempSelectedIds.remove(materialId);
      } else {
        _tempSelectedIds.add(materialId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _tempSelectedIds.addAll(
        _filteredMaterials.map((m) => int.parse(m.id)),
      );
    });
  }

  void _clearAll() {
    setState(() {
      final filteredIds = _filteredMaterials.map((m) => int.parse(m.id)).toSet();
      _tempSelectedIds.removeAll(filteredIds);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredMaterials = _filteredMaterials;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Focus(
          focusNode: _dialogFocusNode,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.of(context).pop();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Selecionar materiais',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    ExcludeFocus(
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        tooltip: 'Fechar (Esc)',
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                  ),
                  child: TextField(
                    focusNode: _searchFocusNode,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Buscar material',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      icon: Icon(Icons.search, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text(
                      '${_tempSelectedIds.length} ${_tempSelectedIds.length == 1 ? 'selecionado' : 'selecionados'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    ExcludeFocus(
                      child: TextButton(
                        onPressed: filteredMaterials.isEmpty ? null : _selectAll,
                        child: const Text('Selecionar todos'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ExcludeFocus(
                      child: TextButton(
                        onPressed: _tempSelectedIds.isEmpty ? null : _clearAll,
                        child: const Text('Limpar'),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: filteredMaterials.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(48),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 48,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Nenhum material encontrado',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ExcludeFocus(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredMaterials.length,
                          itemBuilder: (context, index) {
                            final material = filteredMaterials[index];
                            final materialId = int.parse(material.id);
                            final isSelected = _tempSelectedIds.contains(materialId);

                            return CheckboxListTile(
                              value: isSelected,
                              onChanged: (value) => _toggleMaterial(materialId),
                              title: Text(material.name),
                              controlAffinity: ListTileControlAffinity.leading,
                              activeColor: theme.colorScheme.primary,
                            );
                          },
                        ),
                      ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: ExcludeFocus(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                            side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.18)),
                            foregroundColor: theme.colorScheme.onSurface,
                          ),
                          child: const Text('Cancelar'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ExcludeFocus(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(_tempSelectedIds),
                          child: const Text('Confirmar'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmDeleteSheet extends StatelessWidget {
  final String productName;

  const _ConfirmDeleteSheet({required this.productName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Excluir produto?', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Você tem certeza que deseja excluir "$productName"?',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ExcludeFocus(
                  child: OutlinedButton(
                    onPressed: () => context.pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.18)),
                      foregroundColor: theme.colorScheme.onSurface,
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ExcludeFocus(
                  child: ElevatedButton(
                    onPressed: () => context.pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                    ),
                    child: const Text('Excluir'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}