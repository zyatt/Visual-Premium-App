import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:visualpremium/data/materials_repository.dart';
import 'package:visualpremium/models/material_item.dart';
import 'package:visualpremium/theme.dart';

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

class MaterialsPage extends StatefulWidget {
  const MaterialsPage({super.key});

  @override
  State<MaterialsPage> createState() => _MaterialsPageState();
}

class _MaterialsPageState extends State<MaterialsPage> {
  final _api = MaterialsApiRepository();
  bool _loading = true;
  List<MaterialItem> _items = const [];
  String _searchQuery = '';
  SortOption _sortOption = SortOption.newestFirst;

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
      MaterialItem updated;
      if (_items.any((e) => e.id == item.id)) {
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
          SingleChildScrollView(
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
                            hintText: 'Buscar por nome',
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
                        _EmptyMaterialsState(
                          hasSearch: _searchQuery.isNotEmpty,
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
                    'Unidade: ${item.unit} • Qtd: ${item.quantity}',
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
            ElevatedButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('Cadastrar')),
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
  final FocusNode _dialogFocusNode = FocusNode();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _unitFocusNode = FocusNode();
  final FocusNode _quantityFocusNode = FocusNode();
  final FocusNode _costFocusNode = FocusNode();

  static const List<String> _unitOptions = ['Kg', 'm²', 'm', 'Unidade', 'Altura', 'Hora', '%', 'L'];
  String? _selectedUnit;
  bool _isShowingDiscardDialog = false;
  
  late final String _initialName;
  late final String? _initialUnit;
  late final String _initialQuantity;
  late final String _initialCost;

  @override
  void initState() {
    super.initState();
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    
    _initialName = widget.initial?.name ?? '';
    final initialUnit = widget.initial?.unit.trim();
    _initialUnit = (initialUnit != null && _unitOptions.contains(initialUnit)) ? initialUnit : null;
    _initialQuantity = widget.initial?.quantity ?? '';
    _initialCost = widget.initial == null ? '' : currency.format(widget.initial!.costCents / 100.0);
    
    _nameCtrl = TextEditingController(text: _initialName);
    _selectedUnit = _initialUnit;
    _quantityCtrl = TextEditingController(text: _initialQuantity);
    _costCtrl = TextEditingController(text: _initialCost);
    
    _nameFocusNode.addListener(_onFieldFocusChange);
    _unitFocusNode.addListener(_onUnitFocusChange);
    _quantityFocusNode.addListener(_onFieldFocusChange);
    _costFocusNode.addListener(_onFieldFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dialogFocusNode.requestFocus();
    });
  }

  void _onUnitFocusChange() {
    if (_unitFocusNode.hasFocus) {
      // Quando o dropdown recebe foco via TAB, não fazemos nada aqui
      // O usuário pode pressionar Enter ou Space para abrir
    } else {
      _onFieldFocusChange();
    }
  }

  void _onFieldFocusChange() {
    if (!_nameFocusNode.hasFocus && !_unitFocusNode.hasFocus && !_quantityFocusNode.hasFocus && !_costFocusNode.hasFocus) {
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
           _costCtrl.text != _initialCost;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _quantityCtrl.dispose();
    _costCtrl.dispose();
    _dialogFocusNode.dispose();
    _nameFocusNode.dispose();
    _unitFocusNode.dispose();
    _quantityFocusNode.dispose();
    _costFocusNode.dispose();
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
    
    if (_selectedUnit == 'Kg') {
      s = s.replaceAll(',', '.');
      final value = double.tryParse(s);
      if (value == null || value.isNaN || value.isInfinite || value < 0) return null;
      return value.toString();
    } else {
      final value = int.tryParse(s);
      if (value == null || value < 0) return null;
      return value.toString();
    }
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

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;
    final cents = _parseCostToCents(_costCtrl.text) ?? 0;
    final quantity = _parseQuantity(_quantityCtrl.text) ?? '0';
    final now = DateTime.now();
    final unit = (_selectedUnit ?? '').trim();
    final item = (widget.initial ??
            MaterialItem(id: now.microsecondsSinceEpoch.toString(), name: '', unit: '', costCents: 0, quantity: '0', createdAt: now))
        .copyWith(name: _nameCtrl.text.trim(), unit: unit, quantity: quantity, costCents: cents);
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
                                    keyboardType: TextInputType.numberWithOptions(decimal: _selectedUnit == 'Kg'),
                                    inputFormatters: [
                                      if (_selectedUnit == 'Kg')
                                        FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                                      else
                                        FilteringTextInputFormatter.digitsOnly
                                    ],
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(labelText: 'Quantidade'),
                                    validator: (v) => _parseQuantity(v ?? '') == null ? 'Informe uma quantidade válida' : null,
                                    onFieldSubmitted: (_) => _costFocusNode.requestFocus(),
                                  ),
                                ),
                              ],
                            ),
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
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.18)),
                      foregroundColor: theme.colorScheme.onSurface,
                    ),
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