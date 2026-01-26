import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:visualpremium/data/products_repository.dart';
import 'package:visualpremium/data/materials_repository.dart';
import 'package:visualpremium/models/product_item.dart';
import 'package:visualpremium/models/material_item.dart';
import 'package:visualpremium/theme.dart';

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

  Future<void> _showProductEditor(ProductItem? initial) async {
    final theme = Theme.of(context);
    final result = await showDialog<ProductItem>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: ProductEditorSheet(
              initial: initial,
              availableMaterials: _availableMaterials,
              existingProducts: _items,
            ),
          ),
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
      products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao deletar produto: $e')),
      );
    }
  }

  List<ProductItem> get _filteredItems {
    if (_searchQuery.isEmpty) return _items;
    final query = _searchQuery.toLowerCase();
    return _items.where((item) {
      return item.name.toLowerCase().contains(query) ||
          item.materials.any((m) => m.materialNome.toLowerCase().contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredItems = _filteredItems;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Produtos', style: theme.textTheme.headlineMedium),
                ElevatedButton.icon(
                  onPressed: () => _showProductEditor(null),
                  icon: const Icon(Icons.add),
                  label: const Text('Novo Produto'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
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
                  hintText: 'Buscar produtos...',
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
              ListView.separated(
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
              child: Icon(Icons.inventory_2_outlined, color: theme.colorScheme.secondary, size: 20),
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
          ElevatedButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('Cadastrar')),
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
  final List<_MaterialSelection> _selectedMaterials = [];
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initial?.name ?? '');
    _nameCtrl.addListener(() => _markChanged());
    
    if (widget.initial != null) {
      for (final pm in widget.initial!.materials) {
        _selectedMaterials.add(_MaterialSelection(
          materialId: pm.materialId,
          materialName: pm.materialNome,
        ));
      }
    }
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _addMaterial() {
    setState(() {
      _selectedMaterials.add(_MaterialSelection(
        materialId: null,
        materialName: '',
      ));
      _markChanged();
    });
  }

  void _removeMaterial(int index) {
    setState(() {
      _selectedMaterials.removeAt(index);
      _markChanged();
    });
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descartar alterações?'),
        content: const Text('Você tem alterações não salvas. Deseja descartá-las?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          context.pop();
        }
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
                  IconButton(
                    onPressed: () async {
                      final shouldClose = await _onWillPop();
                      if (shouldClose && context.mounted) {
                        context.pop();
                      }
                    },
                    icon: const Icon(Icons.close),
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
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
                        TextButton.icon(
                          onPressed: _addMaterial,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Adicionar material'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_selectedMaterials.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                        ),
                        child: Center(
                          child: Text(
                            'Nenhum material adicionado',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _selectedMaterials.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _MaterialSelectionRow(
                            selection: _selectedMaterials[index],
                            availableMaterials: widget.availableMaterials,
                            selectedMaterialIds: _selectedMaterials
                                .where((m) => m.materialId != null)
                                .map((m) => m.materialId!)
                                .toList(),
                            onChanged: (updated) {
                              setState(() {
                                _selectedMaterials[index] = updated;
                                _markChanged();
                              });
                            },
                            onRemove: () => _removeMaterial(index),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        
                        final validMaterials = _selectedMaterials
                            .where((m) => m.materialId != null)
                            .map((m) => ProductMaterial(
                                  materialId: m.materialId!,
                                  materialNome: m.materialName,
                                ))
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaterialSelection {
  final int? materialId;
  final String materialName;

  _MaterialSelection({
    required this.materialId,
    required this.materialName,
  });

  _MaterialSelection copyWith({
    int? materialId,
    String? materialName,
  }) =>
      _MaterialSelection(
        materialId: materialId ?? this.materialId,
        materialName: materialName ?? this.materialName,
      );
}

class _MaterialSelectionRow extends StatefulWidget {
  final _MaterialSelection selection;
  final List<MaterialItem> availableMaterials;
  final List<int> selectedMaterialIds;
  final ValueChanged<_MaterialSelection> onChanged;
  final VoidCallback onRemove;

  const _MaterialSelectionRow({
    required this.selection,
    required this.availableMaterials,
    required this.selectedMaterialIds,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_MaterialSelectionRow> createState() => _MaterialSelectionRowState();
}

class _MaterialSelectionRowState extends State<_MaterialSelectionRow> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: widget.selection.materialId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Material',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: widget.availableMaterials
                  .map(
                    (m) {
                      final materialId = int.parse(m.id);
                      final isAlreadySelected = widget.selectedMaterialIds.contains(materialId) &&
                          widget.selection.materialId != materialId;
                      
                      return DropdownMenuItem(
                        value: materialId,
                        enabled: !isAlreadySelected,
                        child: Text(
                          m.name,
                          overflow: TextOverflow.ellipsis,
                          style: isAlreadySelected
                              ? TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.3))
                              : null,
                        ),
                      );
                    },
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  final material = widget.availableMaterials.firstWhere((m) => m.id == value.toString());
                  widget.onChanged(widget.selection.copyWith(
                    materialId: value,
                    materialName: material.name,
                  ));
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: widget.onRemove,
            color: theme.colorScheme.error,
            iconSize: 20,
          ),
        ],
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  ),
                  child: const Text('Excluir'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}