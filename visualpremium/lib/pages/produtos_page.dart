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

  class ProductFilters {
    final Set<int> materialIds;
    final int? minMaterials;
    final int? maxMaterials;

    const ProductFilters({
      this.materialIds = const {},
      this.minMaterials,
      this.maxMaterials,
    });

    bool get hasActiveFilters =>
        materialIds.isNotEmpty ||
        minMaterials != null ||
        maxMaterials != null;

    int get activeFilterCount {
      int count = 0;
      if (materialIds.isNotEmpty) count++;
      if (minMaterials != null || maxMaterials != null) count++;
      return count;
    }

    ProductFilters copyWith({
      Set<int>? materialIds,
      int? minMaterials,
      int? maxMaterials,
      bool clearMinMaterials = false,
      bool clearMaxMaterials = false,
    }) {
      return ProductFilters(
        materialIds: materialIds ?? this.materialIds,
        minMaterials: clearMinMaterials ? null : (minMaterials ?? this.minMaterials),
        maxMaterials: clearMaxMaterials ? null : (maxMaterials ?? this.maxMaterials),
      );
    }

    ProductFilters clear() {
      return const ProductFilters();
    }
  }

  class ProductsPage extends StatefulWidget {
    const ProductsPage({super.key});

    @override
    State<ProductsPage> createState() => _ProductsPageState();
  }

  class _ProductsPageState extends State<ProductsPage> {
    final _api = ProductsApiRepository();
    final _materialsApi = MaterialsApiRepository();
    final _scrollController = ScrollController();
    bool _loading = true;
    List<ProductItem> _items = const [];
    List<MaterialItem> _availableMaterials = const [];
    String _searchQuery = '';
    SortOption _sortOption = SortOption.newestFirst;
    ProductFilters _filters = const ProductFilters();
    bool _showScrollToTopButton = false;
    
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

    Future<void> _showFilterDialog() async {
      final result = await showDialog<ProductFilters>(
        context: context,
        builder: (dialogContext) {
          return _FilterDialog(
            currentFilters: _filters,
            allItems: _items,
            availableMaterials: _availableMaterials,
          );
        },
      );

      if (result != null) {
        setState(() {
          _filters = result;
        });
      }
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

    // ✅ ADICIONAR método
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
        final isUpdate = _items.any((e) => e.id == item.id);
        ProductItem updated;
        if (isUpdate) {
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isUpdate ? 'Produto salvo' : 'Produto cadastrado'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        });
      } catch (e) {
        if (!mounted) return;
        setState(() => _loading = false);
        
        final errorMessage = e.toString();
        
        // Verificar se é erro de opção extra em uso
        if (errorMessage.contains('Não é possível remover a opção') || 
          errorMessage.contains('está sendo usada em orçamentos ou pedidos')) {
        final match = RegExp(r'opção "([^"]+)"').firstMatch(errorMessage);
        final opcaoNome = match?.group(1) ?? 'esta opção';
        
        _showOpcaoExtraInUseDialog(opcaoNome);  // ✅ 1 parâmetro
      } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao salvar produto: $e')),
          );
        }
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

    Future<void> _showOpcaoExtraInUseDialog(String opcaoNome) {
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
                            'Opção em uso',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'A opção "$opcaoNome" não pode ser removida porque está sendo usada em um ou mais orçamentos ou pedidos.',
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
                              'Você pode editar o nome ou tipo desta opção, mas não pode removê-la enquanto estiver em uso.',
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
      
      if (_filters.materialIds.isNotEmpty) {
        filtered = filtered.where((item) {
          return item.materials.any((m) => _filters.materialIds.contains(m.materialId));
        }).toList();
      }
      
      if (_filters.minMaterials != null) {
        filtered = filtered.where((item) => item.materials.length >= _filters.minMaterials!).toList();
      }
      
      if (_filters.maxMaterials != null) {
        filtered = filtered.where((item) => item.materials.length <= _filters.maxMaterials!).toList();
      }
      
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
                                      hintText: 'Buscar por nome ou material',
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
                                  ..._filters.materialIds.map((materialId) {
                                    final material = _availableMaterials.firstWhere(
                                      (m) => m.id == materialId.toString(),
                                      orElse: () => MaterialItem(id: materialId.toString(), name: 'Material $materialId', unit: '', costCents: 0,  quantity: '0', createdAt: DateTime.now()),
                                    );
                                    return _FilterChip(
                                      label: material.name,
                                      onDeleted: () {
                                        setState(() {
                                          final newMaterials = Set<int>.from(_filters.materialIds)..remove(materialId);
                                          _filters = _filters.copyWith(materialIds: newMaterials);
                                        });
                                      },
                                    );
                                  }),
                                  if (_filters.minMaterials != null || _filters.maxMaterials != null)
                                    _FilterChip(
                                      label: _filters.minMaterials != null && _filters.maxMaterials != null
                                          ? '${_filters.minMaterials}-${_filters.maxMaterials} materiais'
                                          : _filters.minMaterials != null
                                              ? 'Mín. ${_filters.minMaterials} materiais'
                                              : 'Máx. ${_filters.maxMaterials} materiais',
                                      onDeleted: () {
                                        setState(() {
                                          _filters = _filters.copyWith(
                                            clearMinMaterials: true,
                                            clearMaxMaterials: true,
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
                            _EmptyProductsState(
                              hasSearch: _searchQuery.isNotEmpty || _filters.hasActiveFilters,
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
    final ProductFilters currentFilters;
    final List<ProductItem> allItems;
    final List<MaterialItem> availableMaterials;

    const _FilterDialog({
      required this.currentFilters,
      required this.allItems,
      required this.availableMaterials,
    });

    @override
    State<_FilterDialog> createState() => _FilterDialogState();
  }

  class _FilterDialogState extends State<_FilterDialog> {
    late Set<int> _selectedMaterialIds;
    late int? _minMaterials;
    late int? _maxMaterials;
    
    final TextEditingController _materialSearchCtrl = TextEditingController();
    final TextEditingController _minMaterialsCtrl = TextEditingController();
    final TextEditingController _maxMaterialsCtrl = TextEditingController();
    String _materialSearchQuery = '';

    @override
    void initState() {
      super.initState();
      _selectedMaterialIds = Set.from(widget.currentFilters.materialIds);
      _minMaterials = widget.currentFilters.minMaterials;
      _maxMaterials = widget.currentFilters.maxMaterials;
      
      if (_minMaterials != null) {
        _minMaterialsCtrl.text = _minMaterials.toString();
      }
      if (_maxMaterials != null) {
        _maxMaterialsCtrl.text = _maxMaterials.toString();
      }
      
      _materialSearchCtrl.addListener(() {
        setState(() {
          _materialSearchQuery = _materialSearchCtrl.text.toLowerCase();
        });
      });
    }

    @override
    void dispose() {
      _materialSearchCtrl.dispose();
      _minMaterialsCtrl.dispose();
      _maxMaterialsCtrl.dispose();
      super.dispose();
    }

    List<MaterialItem> get _filteredMaterials {
      if (_materialSearchQuery.isEmpty) {
        return [];
      }
      
      final materials = widget.availableMaterials
          .where((m) => m.name.toLowerCase().contains(_materialSearchQuery))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return materials;
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
                      'Filtrar Produtos',
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
                        'Materiais',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _materialSearchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Buscar material...',
                          isDense: true,
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _materialSearchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _materialSearchCtrl.clear();
                                  },
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_selectedMaterialIds.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedMaterialIds.map((materialId) {
                            final material = widget.availableMaterials.firstWhere(
                              (m) => m.id == materialId.toString(),
                              orElse: () => MaterialItem(
                                id: materialId.toString(),
                                name: 'Material $materialId',
                                unit: '',
                                costCents: 0,
                                quantity: '0',
                                createdAt: DateTime.now(),
                              ),
                            );
                            return FilterChip(
                              label: Text(material.name),
                              selected: true,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedMaterialIds.remove(materialId);
                                });
                              },
                              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                              selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                              checkmarkColor: theme.colorScheme.primary,
                              side: BorderSide(
                                color: theme.colorScheme.primary.withValues(alpha: 0.5),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_materialSearchQuery.isNotEmpty) ...[
                        if (_filteredMaterials.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 20,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Nenhum material encontrado',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _filteredMaterials.map((material) {
                              final materialId = int.parse(material.id);
                              final isSelected = _selectedMaterialIds.contains(materialId);
                              return FilterChip(
                                label: Text(material.name),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedMaterialIds.add(materialId);
                                    } else {
                                      _selectedMaterialIds.remove(materialId);
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
                      ] else
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 20,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Digite para buscar materiais',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                      Text(
                        'Quantidade de Materiais',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _minMaterialsCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: const InputDecoration(
                                labelText: 'Mínimo',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                hintText: 'Ex: 1',
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _minMaterials = value.isEmpty ? null : int.tryParse(value);
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _maxMaterialsCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: const InputDecoration(
                                labelText: 'Máximo',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                hintText: 'Ex: 10',
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _maxMaterials = value.isEmpty ? null : int.tryParse(value);
                                });
                              },
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
                            _selectedMaterialIds.clear();
                            _minMaterials = null;
                            _maxMaterials = null;
                            _minMaterialsCtrl.clear();
                            _maxMaterialsCtrl.clear();
                          });
                        },
                        child: const Text('Limpar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop(
                            ProductFilters(
                              materialIds: _selectedMaterialIds,
                              minMaterials: _minMaterials,
                              maxMaterials: _maxMaterials,
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
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${item.materials.length} ${item.materials.length == 1 ? 'material' : 'materiais'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        if (item.opcoesExtras.isNotEmpty) ...[
                          Text(
                            ' • ',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                          Text(
                            '${item.opcoesExtras.length} ${item.opcoesExtras.length == 1 ? 'Outro' : 'Outros'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ],
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
    final List<ProductOpcaoExtra> _opcoesExtras = [];
    final FocusNode _dialogFocusNode = FocusNode();
    final FocusNode _nameFocusNode = FocusNode();
    bool _isShowingDiscardDialog = false;
    
    late final String _initialName;
    late final Set<int> _initialMaterialIds;
    late final List<ProductOpcaoExtra> _initialOpcoesExtras;

    @override
    void initState() {
      super.initState();
      _initialName = widget.initial?.name ?? '';
      _nameCtrl = TextEditingController(text: _initialName);
      
      if (widget.initial != null) {
        for (final pm in widget.initial!.materials) {
          _selectedMaterialIds.add(pm.materialId);
        }
        _opcoesExtras.addAll(widget.initial!.opcoesExtras);
      }
      
      _initialMaterialIds = Set.from(_selectedMaterialIds);
      _initialOpcoesExtras = List.from(_opcoesExtras);
      
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
      
      if (!_selectedMaterialIds.containsAll(_initialMaterialIds) || 
          !_initialMaterialIds.containsAll(_selectedMaterialIds)) {
        return true;
      }
      
      if (_opcoesExtras.length != _initialOpcoesExtras.length) {
        return true;
      }
      
      for (int i = 0; i < _opcoesExtras.length; i++) {
        final current = _opcoesExtras[i];
        final initial = _initialOpcoesExtras.firstWhere(
          (o) => o.id == current.id,
          orElse: () => ProductOpcaoExtra(id: -1, nome: '', tipo: TipoOpcaoExtra.stringFloat),
        );
        
        if (initial.id == -1 || current.nome != initial.nome || current.tipo != initial.tipo) {
          return true;
        }
      }
      
      return false;
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

    Future<void> _showOpcaoExtraEditor([ProductOpcaoExtra? initial]) async {
      final result = await showDialog<ProductOpcaoExtra>(
        context: context,
        builder: (dialogContext) {
          return _OpcaoExtraEditorDialog(
            initial: initial,
            existingNames: _opcoesExtras
                .where((o) => initial == null || o.id != initial.id)
                .map((o) => o.nome.toLowerCase())
                .toSet(),
          );
        },
      );
      
      if (result != null) {
        setState(() {
          if (initial != null) {
            final index = _opcoesExtras.indexWhere((o) => o.id == initial.id);
            if (index != -1) {
              _opcoesExtras[index] = result;
            }
          } else {
            _opcoesExtras.add(result);
          }
        });
      }
    }

    Future<void> _removeOpcaoExtra(ProductOpcaoExtra opcao) async {
      // Se a opção é existente (tem ID real do banco), verificar se está em uso
      final isExisting = opcao.id > 0 && opcao.id < 1000000;
      
      if (isExisting && widget.initial != null) {
        // Verificar se esta opção existia originalmente
        final wasOriginal = _initialOpcoesExtras.any((o) => o.id == opcao.id);
        
        if (wasOriginal) {
          // É uma opção que existia antes - mostrar aviso
          final theme = Theme.of(context);
          final confirmed = await showDialog<bool>(
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
                                'Remover opção?',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Você tem certeza que deseja remover a opção "${opcao.nome}"?',
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
                                  'Se esta opção estiver sendo usada em orçamentos ou pedidos, a remoção falhará ao salvar.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(dialogContext).pop(false),
                                child: const Text('Cancelar'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => Navigator.of(dialogContext).pop(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.error,
                                  foregroundColor: theme.colorScheme.onError,
                                ),
                                child: const Text('Remover'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
          
          if (confirmed != true) return;
        }
      }
      
      // Remover a opção da lista local
      setState(() {
        _opcoesExtras.removeWhere((o) => o.id == opcao.id);
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
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Outros',
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  ExcludeFocus(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _showOpcaoExtraEditor(),
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text('Adicionar opção'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_opcoesExtras.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Nenhuma opção extra cadastrada',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                )
                              else
                                ExcludeFocus(
                                  child: Column(
                                    children: _opcoesExtras.map((opcao) {
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Icon(
                                                () {
                                                  switch (opcao.tipo) {
                                                    case TipoOpcaoExtra.stringFloat:
                                                      return Icons.text_fields;
                                                    case TipoOpcaoExtra.floatFloat:
                                                      return Icons.timelapse;
                                                    case TipoOpcaoExtra.percentFloat:
                                                      return Icons.percent;
                                                  }
                                                }(),
                                                size: 18,
                                                color: theme.colorScheme.onSecondaryContainer,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    opcao.nome,
                                                    style: theme.textTheme.bodyMedium?.copyWith(
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                  () {
                                                    switch (opcao.tipo) {
                                                      case TipoOpcaoExtra.stringFloat:
                                                        return 'Descrição + Valor';

                                                      case TipoOpcaoExtra.floatFloat:
                                                        return 'Tempo + Valor';

                                                      case TipoOpcaoExtra.percentFloat:
                                                        return '% + Valor';
                                                    }
                                                  }(),
                                                  style: theme.textTheme.bodySmall?.copyWith(
                                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                                  ),
                                                ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () => _showOpcaoExtraEditor(opcao),
                                              icon: const Icon(Icons.edit_outlined, size: 18),
                                              tooltip: 'Editar',
                                              color: theme.colorScheme.primary,
                                            ),
                                           IconButton(
                                            onPressed: () => _removeOpcaoExtra(opcao),
                                            icon: const Icon(Icons.delete_outline, size: 18),
                                            tooltip: 'Remover',
                                            color: theme.colorScheme.error,
                                          ),
                                          ],
                                        ),
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
                                              opcoesExtras: const [],
                                              createdAt: now,
                                            ))
                                        .copyWith(
                                      name: _nameCtrl.text.trim(),
                                      materials: validMaterials,
                                      opcoesExtras: _opcoesExtras,
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

  class _OpcaoExtraEditorDialog extends StatefulWidget {
    final ProductOpcaoExtra? initial;
    final Set<String> existingNames;

    const _OpcaoExtraEditorDialog({
      required this.initial,
      required this.existingNames,
    });

    @override
    State<_OpcaoExtraEditorDialog> createState() => _OpcaoExtraEditorDialogState();
  }

  class _OpcaoExtraEditorDialogState extends State<_OpcaoExtraEditorDialog> {
    final _formKey = GlobalKey<FormState>();
    late final TextEditingController _nomeCtrl;
    late TipoOpcaoExtra _tipo;
    final FocusNode _dialogFocusNode = FocusNode();
    final FocusNode _nomeFocusNode = FocusNode();

    @override
    void initState() {
      super.initState();
      _nomeCtrl = TextEditingController(text: widget.initial?.nome ?? '');
      _tipo = widget.initial?.tipo ?? TipoOpcaoExtra.stringFloat;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _nomeFocusNode.requestFocus();
      });
    }

    @override
    void dispose() {
      _nomeCtrl.dispose();
      _dialogFocusNode.dispose();
      _nomeFocusNode.dispose();
      super.dispose();
    }

    String? _validateNome(String? value) {
      if (value == null || value.trim().isEmpty) {
        return 'Informe o nome da opção';
      }
      
      final trimmedName = value.trim().toLowerCase();
      if (widget.existingNames.contains(trimmedName)) {
        return 'Já existe uma opção com este nome';
      }
      
      return null;
    }

    @override
    Widget build(BuildContext context) {
      final theme = Theme.of(context);

      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Focus(
            focusNode: _dialogFocusNode,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
                Navigator.of(context).pop();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.initial == null ? 'Nova opção extra' : 'Editar opção extra',
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
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nomeCtrl,
                      focusNode: _nomeFocusNode,
                      decoration: const InputDecoration(
                        labelText: 'Nome da opção',
                        hintText: 'Ex: Frete, Cor',
                      ),
                      validator: _validateNome,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Tipo de dados',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    ExcludeFocus(
                      child: Column(
                        children: [
                          RadioGroup<TipoOpcaoExtra>(
                            groupValue: _tipo,
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _tipo = value);
                            },
                            child: Column(
                              children: [
                                RadioListTile<TipoOpcaoExtra>(
                                  value: TipoOpcaoExtra.stringFloat,
                                  title: const Text('Descrição + Valor'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                                RadioListTile<TipoOpcaoExtra>(
                                  value: TipoOpcaoExtra.floatFloat,
                                  title: const Text('Tempo + Valor'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                                RadioListTile<TipoOpcaoExtra>(
                                  value: TipoOpcaoExtra.percentFloat,
                                  title: const Text('% + Valor'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
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
                              onPressed: () {
                                if (!_formKey.currentState!.validate()) return;
                                
                                final opcao = ProductOpcaoExtra(
                                  id: widget.initial?.id ?? DateTime.now().microsecondsSinceEpoch,
                                  nome: _nomeCtrl.text.trim(),
                                  tipo: _tipo,
                                );
                                
                                Navigator.of(context).pop(opcao);
                              },
                              child: Text(widget.initial == null ? 'Adicionar' : 'Salvar'),
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