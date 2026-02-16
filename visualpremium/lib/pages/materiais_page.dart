import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:visualpremium/data/materials_repository.dart';
import 'package:visualpremium/models/material_item.dart';
import 'package:visualpremium/theme.dart';
import 'package:visualpremium/widgets/clickable_ink.dart';

enum SortOption {
  newestFirst,
  oldestFirst,
  nameAsc,
  nameDesc,
  unitAsc,
  unitDesc,
  quantityAsc,
  quantityDesc,
  priceAsc,
  priceDesc,
}

class MaterialFilters {
  final Set<String> units;
  final double? minPrice;
  final double? maxPrice;
  final double? minQuantity;
  final double? maxQuantity;

  const MaterialFilters({
    this.units = const {},
    this.minPrice,
    this.maxPrice,
    this.minQuantity,
    this.maxQuantity,
  });

  bool get hasActiveFilters =>
      units.isNotEmpty ||
      minPrice != null ||
      maxPrice != null ||
      minQuantity != null ||
      maxQuantity != null;

  int get activeFilterCount {
    int count = 0;
    if (units.isNotEmpty) count++;
    if (minPrice != null || maxPrice != null) count++;
    if (minQuantity != null || maxQuantity != null) count++;
    return count;
  }

  MaterialFilters copyWith({
    Set<String>? units,
    double? minPrice,
    double? maxPrice,
    double? minQuantity,
    double? maxQuantity,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
    bool clearMinQuantity = false,
    bool clearMaxQuantity = false,
  }) {
    return MaterialFilters(
      units: units ?? this.units,
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      minQuantity: clearMinQuantity ? null : (minQuantity ?? this.minQuantity),
      maxQuantity: clearMaxQuantity ? null : (maxQuantity ?? this.maxQuantity),
    );
  }

  MaterialFilters clear() {
    return const MaterialFilters();
  }
}

class MaterialsPage extends StatefulWidget {
  const MaterialsPage({super.key});

  @override
  State<MaterialsPage> createState() => _MaterialsPageState();
}

class _MaterialsPageState extends State<MaterialsPage> {
  final _api = MaterialsApiRepository();
  final _scrollController = ScrollController();
  bool _loading = true;
  List<MaterialItem> _items = const [];
  String _searchQuery = '';
  SortOption _sortOption = SortOption.newestFirst;
  MaterialFilters _filters = const MaterialFilters();
  bool _showScrollToTopButton = false;

  Future<void> _showMaterialEditor(MaterialItem? initial) async {
    final result = await showDialog<MaterialItem>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return MaterialEditorSheet(
          initial: initial,
          existingMaterials: _items,
        );
      },
    );

    if (result != null) {
      await _upsert(result);
    }
  }

  Future<void> _showFilterDialog() async {
    final result = await showDialog<MaterialFilters>(
      context: context,
      builder: (dialogContext) {
        return _FilterDialog(
          currentFilters: _filters,
        );
      },
    );

    if (result != null) {
      setState(() {
        _filters = result;
      });
    }
  }

  Future<bool?> _showConfirmDelete(String materialName) {
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
            child: _ConfirmDeleteSheet(materialName: materialName),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
    
    _scrollController.addListener(() {
      if (_scrollController.offset >= 300 && !_showScrollToTopButton) {
        setState(() {
          _showScrollToTopButton = true;
        });
      } else if (_scrollController.offset < 300 && _showScrollToTopButton) {
        setState(() {
          _showScrollToTopButton = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _api.fetchMaterials();
      items.sort((a, b) {
        final dateA = a.updatedAt ?? a.createdAt;
        final dateB = b.updatedAt ?? b.createdAt;
        return dateB.compareTo(dateA);
      });
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });

    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar materiais: $e')),
      );
    }
  }

  Future<void> _upsert(MaterialItem item) async {
    setState(() => _loading = true);
    try {
      final isUpdate = _items.any((e) => e.id == item.id);
      MaterialItem updated;
      if (isUpdate) {
        updated = await _api.updateMaterial(item);
      } else {
        updated = await _api.createMaterial(item);
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isUpdate ? 'Material "${item.name}" salvo' : 'Material "${item.name}" cadastrado'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar material: $e')),
      );
    }
  }

  Future<void> _delete(MaterialItem item) async {
    setState(() => _loading = true);
    try {
      await _api.deleteMaterial(item.id);
      final next = _items.where((e) => e.id != item.id).toList(growable: false);
      if (!mounted) return;
      setState(() {
        _items = next;
        _loading = false;
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Material "${item.name}" excluído'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      
      final errorMessage = e.toString();
      if (errorMessage.contains('Material em uso')) {
        _showMaterialInUseDialog(item.name, errorMessage);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao deletar material: $e')),
        );
      }
    }
  }

  Future<void> _showMaterialInUseDialog(String materialName, String errorMessage) {
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
                          'Material em uso',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'O material "$materialName" não pode ser excluído porque está sendo usado em um ou mais produtos.',
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
                            'Para excluir este material, primeiro remova-o dos produtos que o utilizam.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Entendi'),
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

  List<MaterialItem> get _filteredAndSortedItems {
    var filtered = _items;
    
    if (_filters.units.isNotEmpty) {
      filtered = filtered.where((item) => _filters.units.contains(item.unit)).toList();
    }
    
    if (_filters.minPrice != null || _filters.maxPrice != null) {
      filtered = filtered.where((item) {
        final price = item.costCents / 100.0;
        if (_filters.minPrice != null && price < _filters.minPrice!) return false;
        if (_filters.maxPrice != null && price > _filters.maxPrice!) return false;
        return true;
      }).toList();
    }
    
    if (_filters.minQuantity != null || _filters.maxQuantity != null) {
      filtered = filtered.where((item) {
        final qty = double.tryParse(item.quantity) ?? 0;
        if (_filters.minQuantity != null && qty < _filters.minQuantity!) return false;
        if (_filters.maxQuantity != null && qty > _filters.maxQuantity!) return false;
        return true;
      }).toList();
    }
    
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((item) {
        return item.name.toLowerCase().contains(query);
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
      case SortOption.unitAsc:
        filtered.sort((a, b) => a.unit.compareTo(b.unit));
        break;
      case SortOption.unitDesc:
        filtered.sort((a, b) => b.unit.compareTo(a.unit));
        break;
      case SortOption.quantityAsc:
        filtered.sort((a, b) {
          final qtyA = double.tryParse(a.quantity) ?? 0;
          final qtyB = double.tryParse(b.quantity) ?? 0;
          return qtyA.compareTo(qtyB);
        });
        break;
      case SortOption.quantityDesc:
        filtered.sort((a, b) {
          final qtyA = double.tryParse(a.quantity) ?? 0;
          final qtyB = double.tryParse(b.quantity) ?? 0;
          return qtyB.compareTo(qtyA);
        });
        break;
      case SortOption.priceAsc:
        filtered.sort((a, b) => a.costCents.compareTo(b.costCents));
        break;
      case SortOption.priceDesc:
        filtered.sort((a, b) => b.costCents.compareTo(a.costCents));
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

  void _toggleUnitSort() {
    setState(() {
      if (_sortOption == SortOption.unitAsc) {
        _sortOption = SortOption.unitDesc;
      } else if (_sortOption == SortOption.unitDesc) {
        _sortOption = SortOption.unitAsc;
      } else {
        _sortOption = SortOption.unitAsc;
      }
    });
  }

  void _toggleQuantitySort() {
    setState(() {
      if (_sortOption == SortOption.quantityAsc) {
        _sortOption = SortOption.quantityDesc;
      } else if (_sortOption == SortOption.quantityDesc) {
        _sortOption = SortOption.quantityAsc;
      } else {
        _sortOption = SortOption.quantityDesc;
      }
    });
  }

  void _togglePriceSort() {
    setState(() {
      if (_sortOption == SortOption.priceAsc) {
        _sortOption = SortOption.priceDesc;
      } else if (_sortOption == SortOption.priceDesc) {
        _sortOption = SortOption.priceAsc;
      } else {
        _sortOption = SortOption.priceDesc;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final filteredItems = _filteredAndSortedItems;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _load,
            child: SingleChildScrollView(
              controller: _scrollController,
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
                                  Icons.construction,
                                  size: 32,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Materiais',
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
                                    onPressed: () => _showMaterialEditor(null),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Novo Material'),
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
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: theme.cardTheme.color,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                                ),
                                child: TextField(
                                  onChanged: (value) => setState(() => _searchQuery = value),
                                  decoration: InputDecoration(
                                    hintText: 'Buscar por nome',
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    icon: Icon(Icons.search, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ExcludeFocus(
                              child: Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: _filters.hasActiveFilters
                                          ? theme.colorScheme.primary.withValues(alpha: 0.1)
                                          : theme.cardTheme.color,
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                      border: Border.all(
                                        color: _filters.hasActiveFilters
                                            ? theme.colorScheme.primary.withValues(alpha: 0.3)
                                            : theme.dividerColor.withValues(alpha: 0.1),
                                      ),
                                    ),
                                    child: IconButton(
                                      onPressed: _showFilterDialog,
                                      icon: Icon(
                                        Icons.filter_list,
                                        color: _filters.hasActiveFilters
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                      tooltip: 'Filtrar',
                                    ),
                                  ),
                                  if (_filters.hasActiveFilters)
                                    Positioned(
                                      right: 6,
                                      top: 6,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 18,
                                          minHeight: 18,
                                        ),
                                        child: Text(
                                          '${_filters.activeFilterCount}',
                                          style: TextStyle(
                                            color: theme.colorScheme.onPrimary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_filters.hasActiveFilters) ...[
                          const SizedBox(height: 12),
                          ExcludeFocus(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ..._filters.units.map((unit) => _FilterChip(
                                      label: unit,
                                      onDeleted: () {
                                        setState(() {
                                          final newUnits = Set<String>.from(_filters.units)..remove(unit);
                                          _filters = _filters.copyWith(units: newUnits);
                                        });
                                      },
                                    )),
                                if (_filters.minPrice != null || _filters.maxPrice != null)
                                  _FilterChip(
                                    label: _filters.minPrice != null && _filters.maxPrice != null
                                        ? 'R\$ ${_filters.minPrice!.toStringAsFixed(2)} - R\$ ${_filters.maxPrice!.toStringAsFixed(2)}'
                                        : _filters.minPrice != null
                                            ? 'Preço ≥ R\$ ${_filters.minPrice!.toStringAsFixed(2)}'
                                            : 'Preço ≤ R\$ ${_filters.maxPrice!.toStringAsFixed(2)}',
                                    onDeleted: () {
                                      setState(() {
                                        _filters = _filters.copyWith(
                                          clearMinPrice: true,
                                          clearMaxPrice: true,
                                        );
                                      });
                                    },
                                  ),
                                if (_filters.minQuantity != null || _filters.maxQuantity != null)
                                  _FilterChip(
                                    label: _filters.minQuantity != null && _filters.maxQuantity != null
                                        ? 'Qtd: ${_filters.minQuantity!.toStringAsFixed(0)} - ${_filters.maxQuantity!.toStringAsFixed(0)}'
                                        : _filters.minQuantity != null
                                            ? 'Qtd ≥ ${_filters.minQuantity!.toStringAsFixed(0)}'
                                            : 'Qtd ≤ ${_filters.maxQuantity!.toStringAsFixed(0)}',
                                    onDeleted: () {
                                      setState(() {
                                        _filters = _filters.copyWith(
                                          clearMinQuantity: true,
                                          clearMaxQuantity: true,
                                        );
                                      });
                                    },
                                  ),
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _filters = _filters.clear();
                                    });
                                  },
                                  icon: const Icon(Icons.clear_all, size: 16),
                                  label: const Text('Limpar filtros'),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
                          _EmptyMaterialsState(
                            hasSearch: _searchQuery.isNotEmpty || _filters.hasActiveFilters,
                            onCreate: () => _showMaterialEditor(null),
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
                                return _MaterialCard(
                                  item: item,
                                  formattedCost: currency.format(item.costCents / 100.0),
                                  onTap: () => _showMaterialEditor(item),
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
                      onToggleUnitSort: _toggleUnitSort,
                      onToggleQuantitySort: _toggleQuantitySort,
                      onTogglePriceSort: _togglePriceSort,
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
            if (_showScrollToTopButton)
            Positioned(
              right: 32,
              bottom: 32,
              child: AnimatedOpacity(
                opacity: _showScrollToTopButton ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: FloatingActionButton(
                  onPressed: _scrollToTop,
                  tooltip: 'Voltar ao topo',
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  elevation: 4,
                  child: const Icon(Icons.arrow_upward),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onDeleted;

  const _FilterChip({
    required this.label,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Chip(
      label: Text(label),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: onDeleted,
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
      side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
      labelStyle: TextStyle(
        color: theme.colorScheme.primary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _FilterDialog extends StatefulWidget {
  final MaterialFilters currentFilters;

  const _FilterDialog({
    required this.currentFilters,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late Set<String> _selectedUnits;
  late TextEditingController _minPriceCtrl;
  late TextEditingController _maxPriceCtrl;
  late TextEditingController _minQuantityCtrl;
  late TextEditingController _maxQuantityCtrl;

  static const List<String> _unitOptions = ['m²', 'm/l', 'Unidade', 'L'];

  @override
  void initState() {
    super.initState();
    _selectedUnits = Set.from(widget.currentFilters.units);
    _minPriceCtrl = TextEditingController(
      text: widget.currentFilters.minPrice?.toStringAsFixed(2) ?? '',
    );
    _maxPriceCtrl = TextEditingController(
      text: widget.currentFilters.maxPrice?.toStringAsFixed(2) ?? '',
    );
    _minQuantityCtrl = TextEditingController(
      text: widget.currentFilters.minQuantity?.toStringAsFixed(0) ?? '',
    );
    _maxQuantityCtrl = TextEditingController(
      text: widget.currentFilters.maxQuantity?.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    _minQuantityCtrl.dispose();
    _maxQuantityCtrl.dispose();
    super.dispose();
  }

  double? _parsePrice(String text) {
    if (text.trim().isEmpty) return null;
    final value = double.tryParse(text.replaceAll(',', '.'));
    if (value == null || value < 0) return null;
    return value;
  }

  double? _parseQuantity(String text) {
    if (text.trim().isEmpty) return null;
    final value = double.tryParse(text.replaceAll(',', '.'));
    if (value == null || value < 0) return null;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.filter_list, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    'Filtrar Materiais',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unidade de Medida',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _unitOptions.map((unit) {
                        final isSelected = _selectedUnits.contains(unit);
                        return FilterChip(
                          label: Text(unit),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedUnits.add(unit);
                              } else {
                                _selectedUnits.remove(unit);
                              }
                            });
                          },
                          backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                          checkmarkColor: theme.colorScheme.primary,
                          side: BorderSide(
                            color: isSelected
                                ? theme.colorScheme.primary.withValues(alpha: 0.5)
                                : theme.dividerColor.withValues(alpha: 0.2),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Faixa de Preço (R\$)',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minPriceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Mínimo',
                              isDense: true,
                              prefixText: 'R\$ ',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _maxPriceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Máximo',
                              isDense: true,
                              prefixText: 'R\$ ',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Faixa de Quantidade',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minQuantityCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Mínimo',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _maxQuantityCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Máximo',
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _selectedUnits.clear();
                          _minPriceCtrl.clear();
                          _maxPriceCtrl.clear();
                          _minQuantityCtrl.clear();
                          _maxQuantityCtrl.clear();
                        });
                      },
                      child: const Text('Limpar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                      onPressed: () {
                        final minPrice = _parsePrice(_minPriceCtrl.text);
                        final maxPrice = _parsePrice(_maxPriceCtrl.text);
                        final minQuantity = _parseQuantity(_minQuantityCtrl.text);
                        final maxQuantity = _parseQuantity(_maxQuantityCtrl.text);

                        if (minPrice != null && maxPrice != null && minPrice > maxPrice) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('O preço mínimo não pode ser maior que o máximo'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          return;
                        }

                        if (minQuantity != null && maxQuantity != null && minQuantity > maxQuantity) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('A quantidade mínima não pode ser maior que a máxima'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          return;
                        }

                        Navigator.of(context).pop(
                          MaterialFilters(
                            units: _selectedUnits,
                            minPrice: minPrice,
                            maxPrice: maxPrice,
                            minQuantity: minQuantity,
                            maxQuantity: maxQuantity,
                          ),
                        );
                      },
                      child: const Text('Aplicar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  final SortOption sortOption;
  final VoidCallback onToggleDateSort;
  final VoidCallback onToggleNameSort;
  final VoidCallback onToggleUnitSort;
  final VoidCallback onToggleQuantitySort;
  final VoidCallback onTogglePriceSort;

  const _FilterPanel({
    required this.sortOption,
    required this.onToggleDateSort,
    required this.onToggleNameSort,
    required this.onToggleUnitSort,
    required this.onToggleQuantitySort,
    required this.onTogglePriceSort,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      width: 280,
      margin: const EdgeInsets.only(top: 72),
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
            label: 'Unidade',
            icon: Icons.straighten,
            isSelected: sortOption == SortOption.unitAsc || sortOption == SortOption.unitDesc,
            isAscending: sortOption == SortOption.unitAsc,
            ascendingLabel: 'A-Z',
            descendingLabel: 'Z-A',
            onTap: onToggleUnitSort,
          ),
          const SizedBox(height: 8),
          _SortOptionWithToggle(
            label: 'Quantidade',
            icon: Icons.inventory_2_outlined,
            isSelected: sortOption == SortOption.quantityAsc || sortOption == SortOption.quantityDesc,
            isAscending: sortOption == SortOption.quantityAsc,
            ascendingLabel: 'Menor',
            descendingLabel: 'Maior',
            onTap: onToggleQuantitySort,
          ),
          const SizedBox(height: 8),
          _SortOptionWithToggle(
            label: 'Preço',
            icon: Icons.attach_money,
            isSelected: sortOption == SortOption.priceAsc || sortOption == SortOption.priceDesc,
            isAscending: sortOption == SortOption.priceAsc,
            ascendingLabel: 'Menor',
            descendingLabel: 'Maior',
            onTap: onTogglePriceSort,
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
    
    return ClickableInk(
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


String _formatQuantityDisplay(String quantity) {
  final num = double.tryParse(quantity);
  if (num == null) return quantity;
  
  if (num == num.truncate()) {
    return num.truncate().toString();
  }
  
  return num.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
}

class _MaterialCard extends StatelessWidget {
  final MaterialItem item;
  final String formattedCost;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _MaterialCard({
    required this.item,
    required this.formattedCost,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClickableInk(
        onTap: onTap,
        splashColor: Colors.transparent,
        hoverColor: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.construction,
                  color: theme.colorScheme.tertiary,
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
                      '${item.unit} • Qtd: ${_formatQuantityDisplay(item.quantity)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  formattedCost,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                onSelected: (value) {
                  if (value == 'delete') {
                    onDelete();
                  }
                },
                tooltip: 'Opções',
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
      ),
    );
  }
}

class _EmptyMaterialsState extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onCreate;

  const _EmptyMaterialsState({required this.hasSearch, required this.onCreate});

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
              'Nenhum material encontrado',
              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      );
    }

    return ExcludeFocus(
      child: Container(
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
                  Text('Nenhum material cadastrado', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Cadastre nome, unidade, quantidade e custo (R\$) para começar.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.65))),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
              onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('Cadastrar')),
          ],
        ),
      ),
    );
  }
}

class MaterialEditorSheet extends StatefulWidget {
  final MaterialItem? initial;
  final List<MaterialItem> existingMaterials;

  const MaterialEditorSheet({
    super.key,
    required this.initial,
    required this.existingMaterials,
  });

  @override
  State<MaterialEditorSheet>createState() => _MaterialEditorSheetState();
}

class _MaterialEditorSheetState extends State<MaterialEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _costCtrl;
  // NOVOS CONTROLLERS
  late final TextEditingController _alturaCtrl;
  late final TextEditingController _larguraCtrl;
  late final TextEditingController _comprimentoCtrl;  // NOVO
  
  final FocusNode _dialogFocusNode = FocusNode();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _unitFocusNode = FocusNode();
  final FocusNode _quantityFocusNode = FocusNode();
  final FocusNode _costFocusNode = FocusNode();
  // NOVOS FOCUS NODES
  final FocusNode _alturaFocusNode = FocusNode();
  final FocusNode _larguraFocusNode = FocusNode();
  final FocusNode _comprimentoFocusNode = FocusNode();  // NOVO

  static const List<String> _unitOptions = ['m²', 'm/l', 'Unidade', 'L'];
  String? _selectedUnit;
  bool _isShowingDiscardDialog = false;
  
  late final String _initialName;
  late final String? _initialUnit;
  late final String _initialQuantity;
  late final String _initialCost;
  // NOVOS INICIAIS
  late final String _initialAltura;
  late final String _initialLargura;
  late final String _initialComprimento;  // NOVO

  @override
  void initState() {
    super.initState();
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    
    _initialName = widget.initial?.name ?? '';
    final initialUnit = widget.initial?.unit.trim();
    _initialUnit = (initialUnit != null && _unitOptions.contains(initialUnit)) ? initialUnit : null;
    _initialQuantity = widget.initial?.quantity ?? '';
    _initialCost = widget.initial == null ? '' : currency.format(widget.initial!.costCents / 100.0);
    // NOVOS INICIAIS
    _initialAltura = widget.initial?.altura?.toString() ?? '';
    _initialLargura = widget.initial?.largura?.toString() ?? '';
    _initialComprimento = widget.initial?.comprimento?.toString() ?? '';  // NOVO
    
    _nameCtrl = TextEditingController(text: _initialName);
    _selectedUnit = _initialUnit;
    _quantityCtrl = TextEditingController(text: _initialQuantity);
    _costCtrl = TextEditingController(text: _initialCost);
    // NOVOS CONTROLLERS
    _alturaCtrl = TextEditingController(text: _initialAltura);
    _larguraCtrl = TextEditingController(text: _initialLargura);
    _comprimentoCtrl = TextEditingController(text: _initialComprimento);  // NOVO
    
    _nameFocusNode.addListener(_onFieldFocusChange);
    _unitFocusNode.addListener(_onUnitFocusChange);
    _quantityFocusNode.addListener(_onFieldFocusChange);
    _costFocusNode.addListener(_onFieldFocusChange);
    // NOVOS LISTENERS
    _alturaFocusNode.addListener(_onFieldFocusChange);
    _larguraFocusNode.addListener(_onFieldFocusChange);
    _comprimentoFocusNode.addListener(_onFieldFocusChange);  // NOVO
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dialogFocusNode.requestFocus();
    });
  }

  void _onUnitFocusChange() {
    if (_unitFocusNode.hasFocus) {
    } else {
      _onFieldFocusChange();
    }
  }

  void _onFieldFocusChange() {
    if (!_nameFocusNode.hasFocus && 
        !_unitFocusNode.hasFocus && 
        !_quantityFocusNode.hasFocus && 
        !_costFocusNode.hasFocus &&
        !_alturaFocusNode.hasFocus &&
        !_larguraFocusNode.hasFocus &&
        !_comprimentoFocusNode.hasFocus) {  // NOVO
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && !_isShowingDiscardDialog) {
          _dialogFocusNode.requestFocus();
        }
      });
    }
  }

  bool get _hasChanges {
    return _nameCtrl.text != _initialName ||
           _selectedUnit != _initialUnit ||
           _quantityCtrl.text != _initialQuantity ||
           _costCtrl.text != _initialCost ||
           _alturaCtrl.text != _initialAltura ||
           _larguraCtrl.text != _initialLargura ||
           _comprimentoCtrl.text != _initialComprimento;  // NOVO
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _quantityCtrl.dispose();
    _costCtrl.dispose();
    _alturaCtrl.dispose();
    _larguraCtrl.dispose();
    _comprimentoCtrl.dispose();  // NOVO
    _dialogFocusNode.dispose();
    _nameFocusNode.dispose();
    _unitFocusNode.dispose();
    _quantityFocusNode.dispose();
    _costFocusNode.dispose();
    _alturaFocusNode.dispose();
    _larguraFocusNode.dispose();
    _comprimentoFocusNode.dispose();  // NOVO
    super.dispose();
  }

  int? _parseCostToCents(String input) {
    var s = input.trim();
    if (s.isEmpty) return null;
    s = s.replaceAll('R\$', '').replaceAll(' ', '');
    s = s.replaceAll('.', '').replaceAll(',', '.');
    final value = double.tryParse(s);
    if (value == null || value.isNaN || value.isInfinite || value < 0) return null;
    return (value * 100).round();
  }

  String? _parseQuantity(String input) {
    var s = input.trim();
    if (s.isEmpty) return null;
    
    s = s.replaceAll(',', '.');
    final value = double.tryParse(s);
    if (value == null || value.isNaN || value.isInfinite || value < 0) return null;
    return value.toString();
  }

  // NOVA FUNÇÃO
  double? _parseDimension(String input) {
    var s = input.trim();
    if (s.isEmpty) return null;
    
    s = s.replaceAll(',', '.');
    final value = double.tryParse(s);
    if (value == null || value.isNaN || value.isInfinite || value <= 0) return null;
    return value;
  }

  String? _validateMaterialName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Informe o nome';
    }
    
    final trimmedName = value.trim();
    final isDuplicate = widget.existingMaterials.any((material) =>
        material.name.toLowerCase() == trimmedName.toLowerCase() &&
        material.id != widget.initial?.id);
    
    if (isDuplicate) {
      return 'Já existe um material com este nome';
    }
    
    return null;
  }

  // ... (métodos _onWillPop permanecem iguais)

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;
    
    final cents = _parseCostToCents(_costCtrl.text) ?? 0;
    final quantity = _parseQuantity(_quantityCtrl.text) ?? '0';
    final now = DateTime.now();
    final unit = (_selectedUnit ?? '').trim();
    
    // NOVA LÓGICA PARA ALTURA, LARGURA E COMPRIMENTO
    double? altura;
    double? largura;
    double? comprimento;
    
    if (unit == 'm²') {
      altura = _parseDimension(_alturaCtrl.text);
      largura = _parseDimension(_larguraCtrl.text);
    } else if (unit == 'm/l') {
      comprimento = _parseDimension(_comprimentoCtrl.text);
    }
    
    final item = (widget.initial ??
            MaterialItem(
              id: now.microsecondsSinceEpoch.toString(), 
              name: '', 
              unit: '', 
              costCents: 0, 
              quantity: '0', 
              createdAt: now
            ))
        .copyWith(
          name: _nameCtrl.text.trim(), 
          unit: unit, 
          quantity: quantity, 
          costCents: cents,
          altura: altura,
          largura: largura,
          comprimento: comprimento,  // NOVO
        );
    context.pop(item);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
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
                              widget.initial == null ? 'Novo material' : 'Editar material',
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
                          children: [
                            TextFormField(
                              controller: _nameCtrl,
                              focusNode: _nameFocusNode,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(labelText: 'Nome do material'),
                              validator: _validateMaterialName,
                              onFieldSubmitted: (_) => _unitFocusNode.requestFocus(),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedUnit,
                                    focusNode: _unitFocusNode,
                                    isExpanded: true,
                                    decoration: const InputDecoration(labelText: 'Unidade de medida'),
                                    items: _unitOptions
                                        .map(
                                          (u) => DropdownMenuItem(
                                            value: u,
                                            child: Text(u, overflow: TextOverflow.ellipsis),
                                          ),
                                        )
                                        .toList(growable: false),
                                    onChanged: (v) {
                                      setState(() {
                                        _selectedUnit = v;
                                        // Limpa os campos baseado na unidade
                                        if (v != 'm²') {
                                          _alturaCtrl.clear();
                                          _larguraCtrl.clear();
                                        }
                                        if (v != 'm/l') {
                                          _comprimentoCtrl.clear();
                                        }
                                      });
                                    },
                                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a unidade' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _quantityCtrl,
                                    focusNode: _quantityFocusNode,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                                    ],
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(labelText: 'Quantidade'),
                                    validator: (v) => _parseQuantity(v ?? '') == null ? 'Informe uma quantidade válida' : null,
                                    onFieldSubmitted: (_) {
                                      if (_selectedUnit == 'm²') {
                                        _alturaFocusNode.requestFocus();
                                      } else if (_selectedUnit == 'm/l') {
                                        _comprimentoFocusNode.requestFocus();
                                      } else {
                                        _costFocusNode.requestFocus();
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            
                            // ====== CAMPOS CONDICIONAIS PARA m² ======
                            if (_selectedUnit == 'm²') ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _alturaCtrl,
                                      focusNode: _alturaFocusNode,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                                      ],
                                      textInputAction: TextInputAction.next,
                                      decoration: InputDecoration(
                                        labelText: 'Altura (mm)',
                                        hintText: 'Ex: 2500',
                                        prefixIcon: Icon(
                                          Icons.height,
                                          color: theme.colorScheme.primary.withValues(alpha: 0.7),
                                        ),
                                      ),
                                      validator: (v) {
                                        if (_selectedUnit == 'm²') {
                                          final value = _parseDimension(v ?? '');
                                          if (value == null) {
                                            return 'Altura obrigatória para m²';
                                          }
                                        }
                                        return null;
                                      },
                                      onFieldSubmitted: (_) => _larguraFocusNode.requestFocus(),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _larguraCtrl,
                                      focusNode: _larguraFocusNode,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                                      ],
                                      textInputAction: TextInputAction.next,
                                      decoration: InputDecoration(
                                        labelText: 'Largura (mm)',
                                        hintText: 'Ex: 1200',
                                        prefixIcon: Icon(
                                          Icons.straighten,
                                          color: theme.colorScheme.primary.withValues(alpha: 0.7),
                                        ),
                                      ),
                                      validator: (v) {
                                        if (_selectedUnit == 'm²') {
                                          final value = _parseDimension(v ?? '');
                                          if (value == null) {
                                            return 'Largura obrigatória para m²';
                                          }
                                        }
                                        return null;
                                      },
                                      onFieldSubmitted: (_) => _costFocusNode.requestFocus(),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            // ====== FIM DOS CAMPOS CONDICIONAIS m² ======
                            
                            // ====== CAMPOS CONDICIONAIS PARA m/l ======
                            if (_selectedUnit == 'm/l') ...[
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _comprimentoCtrl,
                                focusNode: _comprimentoFocusNode,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                                ],
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'Comprimento (mm)',
                                  hintText: 'Ex: 3000',
                                  prefixIcon: Icon(
                                    Icons.straighten,
                                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                                  ),
                                ),
                                validator: (v) {
                                  if (_selectedUnit == 'm/l') {
                                    final value = _parseDimension(v ?? '');
                                    if (value == null) {
                                      return 'Comprimento obrigatório para m/l';
                                    }
                                  }
                                  return null;
                                },
                                onFieldSubmitted: (_) => _costFocusNode.requestFocus(),
                              ),
                            ],
                            // ====== FIM DOS CAMPOS CONDICIONAIS ======
                            
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _costCtrl,
                              focusNode: _costFocusNode,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9R\$\s\.,]'))],
                              decoration: const InputDecoration(labelText: 'Custo (R\$)'),
                              validator: (v) => _parseCostToCents(v ?? '') == null ? 'Informe um custo válido' : null,
                              onFieldSubmitted: (_) => _handleSave(),
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
                                child: const Text('Cancelar'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ExcludeFocus(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: theme.colorScheme.onPrimary,
                                ),
                                onPressed: _handleSave,
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

  // _onWillPop permanece o mesmo
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
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Descartar'),
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
}

class _ConfirmDeleteSheet extends StatelessWidget {
  final String materialName;

  const _ConfirmDeleteSheet({required this.materialName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Excluir material?', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Você tem certeza que deseja excluir "$materialName"?', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.pop(false),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => context.pop(true),
                    style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.error, foregroundColor: theme.colorScheme.onError),
                    child: const Text('Excluir'),
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