import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visualpremium/data/orcamentos_repository.dart';
import 'package:visualpremium/models/orcamento_item.dart';
import '../theme.dart';

enum SortOption {
  newestFirst,
  oldestFirst,
  clienteAsc,
  clienteDesc,
  numeroAsc,
  numeroDesc,
  produtoAsc,
  produtoDesc,
  statusAsc,
  statusDesc,
  totalAsc,
  totalDesc,
}

class OrcamentoFilters {
  final Set<String> status;
  final Set<int> produtoIds;
  final Set<String> clientes;
  final DateTimeRange? dateRange;

  const OrcamentoFilters({
    this.status = const {},
    this.produtoIds = const {},
    this.clientes = const {},
    this.dateRange,
  });

  bool get hasActiveFilters =>
      status.isNotEmpty ||
      produtoIds.isNotEmpty ||
      clientes.isNotEmpty ||
      dateRange != null;

  int get activeFilterCount {
    int count = 0;
    if (status.isNotEmpty) count++;
    if (produtoIds.isNotEmpty) count++;
    if (clientes.isNotEmpty) count++;
    if (dateRange != null) count++;
    return count;
  }

  OrcamentoFilters copyWith({
    Set<String>? status,
    Set<int>? produtoIds,
    Set<String>? clientes,
    DateTimeRange? dateRange,
    bool clearDateRange = false,
  }) {
    return OrcamentoFilters(
      status: status ?? this.status,
      produtoIds: produtoIds ?? this.produtoIds,
      clientes: clientes ?? this.clientes,
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
    );
  }

  OrcamentoFilters clear() {
    return const OrcamentoFilters();
  }
}

class BudgetsPage extends StatefulWidget {
  const BudgetsPage({super.key});

  @override
  State<BudgetsPage> createState() => _BudgetsPageState();
}

class _BudgetsPageState extends State<BudgetsPage> {
  final _api = OrcamentosApiRepository();
  bool _loading = true;
  List<OrcamentoItem> _items = const [];
  List<ProdutoItem> _allProdutos = [];
  String _searchQuery = '';
  int? _downloadingId;
  SortOption _sortOption = SortOption.newestFirst;
  OrcamentoFilters _filters = const OrcamentoFilters();

  @override
  void initState() {
    super.initState();
    _load();
    _loadProdutos();
  }

   Future<void> _loadProdutos() async {
    try {
      final produtos = await _api.fetchProdutos();
      if (!mounted) return;
      setState(() {
        _allProdutos = produtos;
      });
    } catch (e) {
      //
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _api.fetchOrcamentos();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar orçamentos: $e')),
        );
      });
    }
  }

  Future<void> _upsert(OrcamentoItem item) async {
    setState(() => _loading = true);
    try {
      final isUpdate = _items.any((e) => e.id == item.id);
      OrcamentoItem updated;
      if (isUpdate) {
        updated = await _api.updateOrcamento(item);
      } else {
        updated = await _api.createOrcamento(item);
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
            content: Text(isUpdate ? 'Orçamento salvo' : 'Orçamento cadastrado'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar orçamento: $e')),
        );
      });
    }
  }


  Future<void> _updateStatus(OrcamentoItem item, String newStatus) async {
    setState(() => _loading = true);
    try {
      // ✅ MUDANÇA: Agora passa o item completo, não apenas o ID
      final updated = await _api.updateStatus(item, newStatus);
      
      final idx = _items.indexWhere((e) => e.id == item.id);
      
      if (!mounted) return;
      final next = [..._items];
      if (idx != -1) {
        next[idx] = updated;
      } else {
        next.insert(0, updated);
      }
      
      setState(() {
        _items = next;
        _loading = false;
      });
      
      // Adicionar feedback de sucesso
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Orçamento: $newStatus'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
      
    } catch (e) {
      // Adicionar tratamento de erro
      if (!mounted) return;
      setState(() => _loading = false);
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar status: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      });
    }
  }

  Future<void> _delete(OrcamentoItem item) async {
    setState(() => _loading = true);
    try {
      await _api.deleteOrcamento(item.id);
      final next = _items.where((e) => e.id != item.id).toList(growable: false);
      if (!mounted) return;
      setState(() {
        _items = next;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao deletar orçamento: $e')),
        );
      });
    }
  }

  Future<void> _downloadPdf(OrcamentoItem item) async {
    setState(() => _downloadingId = item.id);
    try {
      final directory = await getDownloadsDirectory() ?? 
                        await getApplicationDocumentsDirectory();
      final fileName = 'orcamento_${item.numero}_${item.cliente.replaceAll(' ', '_')}.pdf';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      
      if (await file.exists()) {
        await file.delete();
      }
      
      final pdfBytes = await _api.downloadOrcamentoPdf(item.id);
      await file.writeAsBytes(pdfBytes);
      
      if (!mounted) return;
      setState(() => _downloadingId = null);
      
      final uri = Uri.file(filePath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF gerado e aberto com sucesso!'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        });
      } else {
        throw Exception('Não foi possível abrir o PDF');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _downloadingId = null);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar PDF: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      });
    }
  }

  Future<bool?> _showConfirmDelete(String cliente, int numero) {
    final theme = Theme.of(context);
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.of(dialogContext).pop(false);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            backgroundColor: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Excluir orçamento?', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                      'Você tem certeza que deseja excluir o orçamento #$numero de $cliente?',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
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
                            child: const Text('Excluir'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showOrcamentoEditor(OrcamentoItem? initial) async {
    final result = await showDialog<OrcamentoItem>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return OrcamentoEditorSheet(
          initial: initial,
          existingOrcamentos: _items,
        );
      },
    );

    if (result != null) {
      await _upsert(result);
    }
  }

  Future<void> _showFilterDialog() async {
    final result = await showDialog<OrcamentoFilters>(
      context: context,
      builder: (dialogContext) {
        return _FilterDialog(
          currentFilters: _filters,
          allItems: _items,
        );
      },
    );

    if (result != null) {
      setState(() {
        _filters = result;
      });
    }
  }

  List<OrcamentoItem> get _filteredAndSortedItems {
    var filtered = _items;
    
    if (_filters.status.isNotEmpty) {
      filtered = filtered.where((item) => _filters.status.contains(item.status)).toList();
    }
    
    if (_filters.produtoIds.isNotEmpty) {
      filtered = filtered.where((item) => _filters.produtoIds.contains(item.produtoId)).toList();
    }
    
    if (_filters.clientes.isNotEmpty) {
      filtered = filtered.where((item) => _filters.clientes.contains(item.cliente)).toList();
    }
    
    if (_filters.dateRange != null) {
      final start = _filters.dateRange!.start;
      final end = _filters.dateRange!.end;
      filtered = filtered.where((item) {
        final itemDate = DateTime(item.createdAt.year, item.createdAt.month, item.createdAt.day);
        final startDate = DateTime(start.year, start.month, start.day);
        final endDate = DateTime(end.year, end.month, end.day);
        return (itemDate.isAtSameMomentAs(startDate) || itemDate.isAfter(startDate)) &&
               (itemDate.isAtSameMomentAs(endDate) || itemDate.isBefore(endDate));
      }).toList();
    }
    
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((item) {
        return item.cliente.toLowerCase().contains(query) ||
            item.numero.toString().contains(query) ||
            item.produtoNome.toLowerCase().contains(query);
      }).toList();
    } else {
      filtered = List.from(filtered);
    }
    
    switch (_sortOption) {
      case SortOption.newestFirst:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.oldestFirst:
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case SortOption.clienteAsc:
        filtered.sort((a, b) => a.cliente.toLowerCase().compareTo(b.cliente.toLowerCase()));
        break;
      case SortOption.clienteDesc:
        filtered.sort((a, b) => b.cliente.toLowerCase().compareTo(a.cliente.toLowerCase()));
        break;
      case SortOption.numeroAsc:
        filtered.sort((a, b) => a.numero.compareTo(b.numero));
        break;
      case SortOption.numeroDesc:
        filtered.sort((a, b) => b.numero.compareTo(a.numero));
        break;
      case SortOption.produtoAsc:
        filtered.sort((a, b) => a.produtoNome.toLowerCase().compareTo(b.produtoNome.toLowerCase()));
        break;
      case SortOption.produtoDesc:
        filtered.sort((a, b) => b.produtoNome.toLowerCase().compareTo(a.produtoNome.toLowerCase()));
        break;
      case SortOption.statusAsc:
        filtered.sort((a, b) => a.status.compareTo(b.status));
        break;
      case SortOption.statusDesc:
        filtered.sort((a, b) => b.status.compareTo(a.status));
        break;
      case SortOption.totalAsc:
        filtered.sort((a, b) => a.total.compareTo(b.total));
        break;
      case SortOption.totalDesc:
        filtered.sort((a, b) => b.total.compareTo(a.total));
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

  void _toggleClienteSort() {
    setState(() {
      if (_sortOption == SortOption.clienteAsc) {
        _sortOption = SortOption.clienteDesc;
      } else if (_sortOption == SortOption.clienteDesc) {
        _sortOption = SortOption.clienteAsc;
      } else {
        _sortOption = SortOption.clienteAsc;
      }
    });
  }

  void _toggleNumeroSort() {
    setState(() {
      if (_sortOption == SortOption.numeroAsc) {
        _sortOption = SortOption.numeroDesc;
      } else if (_sortOption == SortOption.numeroDesc) {
        _sortOption = SortOption.numeroAsc;
      } else {
        _sortOption = SortOption.numeroDesc;
      }
    });
  }

  void _toggleProdutoSort() {
    setState(() {
      if (_sortOption == SortOption.produtoAsc) {
        _sortOption = SortOption.produtoDesc;
      } else if (_sortOption == SortOption.produtoDesc) {
        _sortOption = SortOption.produtoAsc;
      } else {
        _sortOption = SortOption.produtoAsc;
      }
    });
  }

  void _toggleStatusSort() {
    setState(() {
      if (_sortOption == SortOption.statusAsc) {
        _sortOption = SortOption.statusDesc;
      } else if (_sortOption == SortOption.statusDesc) {
        _sortOption = SortOption.statusAsc;
      } else {
        _sortOption = SortOption.statusAsc;
      }
    });
  }

  void _toggleTotalSort() {
    setState(() {
      if (_sortOption == SortOption.totalAsc) {
        _sortOption = SortOption.totalDesc;
      } else if (_sortOption == SortOption.totalDesc) {
        _sortOption = SortOption.totalAsc;
      } else {
        _sortOption = SortOption.totalDesc;
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
                                  Icons.attach_money_rounded,
                                  size: 32,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Orçamentos',
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
                                    onPressed: () => _showOrcamentoEditor(null),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Novo Orçamento'),
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
                                    hintText: 'Buscar orçamentos',
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
                                ..._filters.status.map((status) => _FilterChip(
                                      label: status,
                                      onDeleted: () {
                                        setState(() {
                                          final newStatus = Set<String>.from(_filters.status)..remove(status);
                                          _filters = _filters.copyWith(status: newStatus);
                                        });
                                      },
                                    )),
                                // ✅ CORRIGIR esta parte
                                ..._filters.produtoIds.map((produtoId) {
                                  // Busca na lista de todos os produtos ao invés dos orçamentos
                                  final produto = _allProdutos.firstWhere(
                                    (p) => p.id == produtoId,
                                    orElse: () => ProdutoItem(
                                      id: produtoId,
                                      nome: 'Produto #$produtoId',
                                      materiais: [],
                                    ),
                                  );
                                  return _FilterChip(
                                    label: produto.nome,
                                    onDeleted: () {
                                      setState(() {
                                        final newProdutos = Set<int>.from(_filters.produtoIds)..remove(produtoId);
                                        _filters = _filters.copyWith(produtoIds: newProdutos);
                                      });
                                    },
                                  );
                                }),
                                ..._filters.clientes.map((cliente) => _FilterChip(
                                      label: cliente,
                                      onDeleted: () {
                                        setState(() {
                                          final newClientes = Set<String>.from(_filters.clientes)..remove(cliente);
                                          _filters = _filters.copyWith(clientes: newClientes);
                                        });
                                      },
                                    )),
                                if (_filters.dateRange != null)
                                  _FilterChip(
                                    label: '${DateFormat('dd/MM/yy').format(_filters.dateRange!.start)} - ${DateFormat('dd/MM/yy').format(_filters.dateRange!.end)}',
                                    onDeleted: () {
                                      setState(() {
                                        _filters = _filters.copyWith(clearDateRange: true);
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
                          _EmptyOrcamentosState(
                            hasSearch: _searchQuery.isNotEmpty || _filters.hasActiveFilters,
                            onCreate: () => _showOrcamentoEditor(null),
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
                                return _OrcamentoCard(
                                  item: item,
                                  formattedValue: currency.format(item.total),
                                  onTap: () => _showOrcamentoEditor(item),
                                  onDelete: () async {
                                    final ok = await _showConfirmDelete(item.cliente, item.numero);
                                    if (ok == true) await _delete(item);
                                  },
                                  onStatusChange: (newStatus) => _updateStatus(item, newStatus),
                                  onDownloadPdf: () => _downloadPdf(item),
                                  isDownloading: _downloadingId == item.id,
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
                      onToggleClienteSort: _toggleClienteSort,
                      onToggleNumeroSort: _toggleNumeroSort,
                      onToggleProdutoSort: _toggleProdutoSort,
                      onToggleStatusSort: _toggleStatusSort,
                      onToggleTotalSort: _toggleTotalSort,
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
  final OrcamentoFilters currentFilters;
  final List<OrcamentoItem> allItems;

  const _FilterDialog({
    required this.currentFilters,
    required this.allItems,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  final _api = OrcamentosApiRepository();
  late Set<String> _selectedStatus;
  late Set<int> _selectedProdutoIds;
  late Set<String> _selectedClientes;
  late DateTimeRange? _selectedDateRange;
  List<ProdutoItem> _allProdutos = [];
  bool _loadingProdutos = true;
  
  final TextEditingController _produtoSearchCtrl = TextEditingController();
  final TextEditingController _clienteSearchCtrl = TextEditingController();
  String _produtoSearchQuery = '';
  String _clienteSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedStatus = Set.from(widget.currentFilters.status);
    _selectedProdutoIds = Set.from(widget.currentFilters.produtoIds);
    _selectedClientes = Set.from(widget.currentFilters.clientes);
    _selectedDateRange = widget.currentFilters.dateRange;
    _loadProdutos();
    
    _produtoSearchCtrl.addListener(() {
      setState(() {
        _produtoSearchQuery = _produtoSearchCtrl.text.toLowerCase();
      });
    });
    
    _clienteSearchCtrl.addListener(() {
      setState(() {
        _clienteSearchQuery = _clienteSearchCtrl.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _produtoSearchCtrl.dispose();
    _clienteSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProdutos() async {
    try {
      final produtos = await _api.fetchProdutos();
      if (!mounted) return;
      setState(() {
        _allProdutos = produtos;
        _loadingProdutos = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingProdutos = false;
      });
    }
  }

  List<String> get _availableStatus {
    return ['Pendente', 'Aprovado', 'Não Aprovado'];
  }

  List<MapEntry<int, String>> get _filteredProdutos {
    if (_produtoSearchQuery.isEmpty) {
      return [];
    }
    
    final entries = _allProdutos
        .where((p) => p.nome.toLowerCase().contains(_produtoSearchQuery))
        .map((p) => MapEntry(p.id, p.nome))
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return entries;
  }

  List<String> get _filteredClientes {
    if (_clienteSearchQuery.isEmpty) {
      return [];
    }
    
    final clientes = widget.allItems
        .map((item) => item.cliente)
        .toSet()
        .where((cliente) => cliente.toLowerCase().contains(_clienteSearchQuery))
        .toList()
      ..sort();
    return clientes;
  }

  Future<void> _selectDateRange() async {
    final result = await showDialog<DateTimeRange>(
      context: context,
      builder: (dialogContext) => _DateRangeInputDialog(
        initialDateRange: _selectedDateRange,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedDateRange = result;
      });
    }
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
                    'Filtrar Orçamentos',
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
                      'Status',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableStatus.map((status) {
                        final isSelected = _selectedStatus.contains(status);
                        return FilterChip(
                          label: Text(status),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedStatus.add(status);
                              } else {
                                _selectedStatus.remove(status);
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
                      'Produto',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    if (_loadingProdutos)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else ...[
                      TextField(
                        controller: _produtoSearchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Buscar produto...',
                          isDense: true,
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _produtoSearchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _produtoSearchCtrl.clear();
                                  },
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_selectedProdutoIds.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedProdutoIds.map((produtoId) {
                            final produto = _allProdutos.firstWhere((p) => p.id == produtoId);
                            return FilterChip(
                              label: Text(produto.nome),
                              selected: true,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedProdutoIds.remove(produtoId);
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
                      if (_produtoSearchQuery.isNotEmpty) ...[
                        if (_filteredProdutos.isEmpty)
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
                                    'Nenhum produto encontrado',
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
                            children: _filteredProdutos.map((entry) {
                              final isSelected = _selectedProdutoIds.contains(entry.key);
                              return FilterChip(
                                label: Text(entry.value),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedProdutoIds.add(entry.key);
                                    } else {
                                      _selectedProdutoIds.remove(entry.key);
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
                                  'Digite para buscar produtos',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      'Cliente',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _clienteSearchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Buscar cliente...',
                        isDense: true,
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _clienteSearchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _clienteSearchCtrl.clear();
                                },
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_selectedClientes.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedClientes.map((cliente) {
                          return FilterChip(
                            label: Text(cliente),
                            selected: true,
                            onSelected: (selected) {
                              setState(() {
                                _selectedClientes.remove(cliente);
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
                    if (_clienteSearchQuery.isNotEmpty) ...[
                      if (_filteredClientes.isEmpty)
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
                                  'Nenhum cliente encontrado',
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
                          children: _filteredClientes.map((cliente) {
                            final isSelected = _selectedClientes.contains(cliente);
                            return FilterChip(
                              label: Text(cliente),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedClientes.add(cliente);
                                  } else {
                                    _selectedClientes.remove(cliente);
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
                                'Digite para buscar clientes',
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
                      'Período',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _selectDateRange,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _selectedDateRange != null
                              ? theme.colorScheme.primary.withValues(alpha: 0.1)
                              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: _selectedDateRange != null
                                ? theme.colorScheme.primary.withValues(alpha: 0.3)
                                : theme.dividerColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 18,
                              color: _selectedDateRange != null
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _selectedDateRange != null
                                  ? '${DateFormat('dd/MM/yy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yy').format(_selectedDateRange!.end)}'
                                  : 'Selecionar período',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _selectedDateRange != null
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                fontWeight: _selectedDateRange != null ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            if (_selectedDateRange != null) ...[
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedDateRange = null;
                                  });
                                },
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
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
                          _selectedStatus.clear();
                          _selectedProdutoIds.clear();
                          _selectedClientes.clear();
                          _selectedDateRange = null;
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
                          OrcamentoFilters(
                            status: _selectedStatus,
                            produtoIds: _selectedProdutoIds,
                            clientes: _selectedClientes,
                            dateRange: _selectedDateRange,
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

class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final oldText = oldValue.text;
    
    String digitsOnly = text.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (digitsOnly.length > 8) {
      digitsOnly = digitsOnly.substring(0, 8);
    }
    
    String formatted = '';
    int cursorPosition = newValue.selection.end;
    
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i == 2 || i == 4) {
        formatted += '/';
        if (oldText.length < text.length && cursorPosition == formatted.length) {
          cursorPosition++;
        }
      }
      formatted += digitsOnly[i];
    }
    
    int newCursorPosition = cursorPosition;
    
    if (oldText.length < formatted.length) {
      if (formatted.length == 3 && oldText.length == 2) {
        newCursorPosition = 3;
      } else if (formatted.length == 6 && oldText.length == 5) {
        newCursorPosition = 6;
      } else {
        newCursorPosition = formatted.length;
      }
    } else if (oldText.length > formatted.length) {
      newCursorPosition = cursorPosition;
      if (newCursorPosition > formatted.length) {
        newCursorPosition = formatted.length;
      }
    }
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursorPosition),
    );
  }
}

class _DateRangeInputDialog extends StatefulWidget {
  final DateTimeRange? initialDateRange;

  const _DateRangeInputDialog({
    this.initialDateRange,
  });

  @override
  State<_DateRangeInputDialog> createState() => _DateRangeInputDialogState();
}

class _DateRangeInputDialogState extends State<_DateRangeInputDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _startDateCtrl;
  late final TextEditingController _endDateCtrl;

  @override
  void initState() {
    super.initState();
    _startDateCtrl = TextEditingController(
      text: widget.initialDateRange != null
          ? DateFormat('dd/MM/yyyy').format(widget.initialDateRange!.start)
          : '',
    );
    _endDateCtrl = TextEditingController(
      text: widget.initialDateRange != null
          ? DateFormat('dd/MM/yyyy').format(widget.initialDateRange!.end)
          : '',
    );
  }

  @override
  void dispose() {
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    super.dispose();
  }

  DateTime? _parseDate(String text) {
    try {
      final parts = text.split('/');
      if (parts.length != 3) return null;
      
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      
      if (day == null || month == null || year == null) return null;
      if (day < 1 || day > 31) return null;
      if (month < 1 || month > 12) return null;
      if (year < 1900 || year > 2100) return null;
      
      return DateTime(year, month, day);
    } catch (e) {
      return null;
    }
  }

  String? _validateDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Informe a data';
    }
    
    final date = _parseDate(value);
    if (date == null) {
      return 'Data inválida';
    }
    
    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    
    final startDate = _parseDate(_startDateCtrl.text);
    final endDate = _parseDate(_endDateCtrl.text);
    
    if (startDate == null || endDate == null) return;
    
    if (startDate.isAfter(endDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A data inicial deve ser anterior à data final'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    Navigator.of(context).pop(DateTimeRange(start: startDate, end: endDate));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Selecionar Período',
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
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data Inicial',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _startDateCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        DateInputFormatter(),
                      ],
                      decoration: const InputDecoration(
                        hintText: 'dd/mm/aaaa',
                        isDense: true,
                        prefixIcon: Icon(Icons.event),
                      ),
                      validator: _validateDate,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Data Final',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _endDateCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        DateInputFormatter(),
                      ],
                      decoration: const InputDecoration(
                        hintText: 'dd/mm/aaaa',
                        isDense: true,
                        prefixIcon: Icon(Icons.event),
                      ),
                      validator: _validateDate,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _save,
                        child: const Text('Aplicar'),
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

class _FilterPanel extends StatelessWidget {
  final SortOption sortOption;
  final VoidCallback onToggleDateSort;
  final VoidCallback onToggleClienteSort;
  final VoidCallback onToggleNumeroSort;
  final VoidCallback onToggleProdutoSort;
  final VoidCallback onToggleStatusSort;
  final VoidCallback onToggleTotalSort;

  const _FilterPanel({
    required this.sortOption,
    required this.onToggleDateSort,
    required this.onToggleClienteSort,
    required this.onToggleNumeroSort,
    required this.onToggleProdutoSort,
    required this.onToggleStatusSort,
    required this.onToggleTotalSort,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      width: 280,
      margin: const EdgeInsets.only(top: 72),
      padding:const EdgeInsets.all(20),
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
            label: 'Cliente',
            icon: Icons.person_outline,
            isSelected: sortOption == SortOption.clienteAsc || sortOption == SortOption.clienteDesc,
            isAscending: sortOption == SortOption.clienteAsc,
            ascendingLabel: 'A-Z',
            descendingLabel: 'Z-A',
            onTap: onToggleClienteSort,
          ),
          const SizedBox(height: 8),
          _SortOptionWithToggle(
            label: 'Número',
            icon: Icons.tag,
            isSelected: sortOption == SortOption.numeroAsc || sortOption == SortOption.numeroDesc,
            isAscending: sortOption == SortOption.numeroAsc,
            ascendingLabel: 'Menor',
            descendingLabel: 'Maior',
            onTap: onToggleNumeroSort,
          ),
          const SizedBox(height: 8),
          _SortOptionWithToggle(
            label: 'Produto',
            icon: Icons.inventory_2_outlined,
            isSelected: sortOption == SortOption.produtoAsc || sortOption == SortOption.produtoDesc,
            isAscending: sortOption == SortOption.produtoAsc,
            ascendingLabel: 'A-Z',
            descendingLabel: 'Z-A',
            onTap: onToggleProdutoSort,
          ),
          const SizedBox(height: 8),
          _SortOptionWithToggle(
            label: 'Status',
            icon: Icons.info_outline,
            isSelected: sortOption == SortOption.statusAsc || sortOption == SortOption.statusDesc,
            isAscending: sortOption == SortOption.statusAsc,
            ascendingLabel: 'A-Z',
            descendingLabel: 'Z-A',
            onTap: onToggleStatusSort,
          ),
          const SizedBox(height: 8),
          _SortOptionWithToggle(
            label: 'Valor Total',
            icon: Icons.attach_money,
            isSelected: sortOption == SortOption.totalAsc || sortOption == SortOption.totalDesc,
            isAscending: sortOption == SortOption.totalAsc,
            ascendingLabel: 'Menor',
            descendingLabel: 'Maior',
            onTap: onToggleTotalSort,
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

class _EmptyOrcamentosState extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onCreate;

  const _EmptyOrcamentosState({required this.hasSearch, required this.onCreate});

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
              'Nenhum orçamento encontrado',
              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.description_outlined, color: theme.colorScheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nenhum orçamento cadastrado', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Crie orçamentos para seus clientes com produtos e materiais.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.65))),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(onPressed: onCreate, icon: const Icon(Icons.add, size: 18), label: const Text('Criar')),
        ],
      ),
    );
  }
}

class _OrcamentoCard extends StatelessWidget {
  final OrcamentoItem item;
  final String formattedValue;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final Function(String) onStatusChange;
  final VoidCallback onDownloadPdf;
  final bool isDownloading;

  const _OrcamentoCard({
    required this.item,
    required this.formattedValue,
    required this.onTap,
    required this.onDelete,
    required this.onStatusChange,
    required this.onDownloadPdf,
    required this.isDownloading,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Aprovado':
        return Colors.green;
      case 'Não Aprovado':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(item.status);
    final dateFormat = DateFormat('dd/MM/yyyy');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.description_outlined, color: theme.colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Orçamento #${item.numero}',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.cliente,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 14,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.produtoNome,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formattedValue,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  dateFormat.format(item.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withValues(alpha: 0.2)),
              ),
              child: Text(
                item.status,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: isDownloading ? null : onDownloadPdf,
              icon: isDownloading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : Icon(Icons.picture_as_pdf, color: theme.colorScheme.primary, size: 20),
              tooltip: 'Baixar PDF',
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurface.withValues(alpha: 0.4), size: 20),
              padding: EdgeInsets.zero,
              onSelected: (value) {
                if (value == 'delete') {
                  onDelete();
                } else if (value == 'approve') {
                  onStatusChange('Aprovado');
                } else if (value == 'reject') {
                  onStatusChange('Não Aprovado');
                } else if (value == 'pending') {
                  onStatusChange('Pendente');
                }
              },
              tooltip: 'Opções',
              itemBuilder: (context) => [
                if (item.status != 'Aprovado')
                  const PopupMenuItem(
                    value: 'approve',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 18),
                        SizedBox(width: 8),
                        Text('Aprovar'),
                      ],
                    ),
                  ),
                if (item.status != 'Não Aprovado')
                  const PopupMenuItem(
                    value: 'reject',
                    child: Row(
                      children: [
                        Icon(Icons.cancel, color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Text('Não Aprovar'),
                      ],
                    ),
                  ),
                if (item.status != 'Pendente')
                  const PopupMenuItem(
                    value: 'pending',
                    child: Row(
                      children: [
                        Icon(Icons.schedule, color: Colors.orange, size: 18),
                        SizedBox(width: 8),
                        Text('Pendente'),
                      ],
                    ),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 18),
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

class OrcamentoEditorSheet extends StatefulWidget {
  final OrcamentoItem? initial;
  final List<OrcamentoItem> existingOrcamentos;

  const OrcamentoEditorSheet({
    super.key,
    required this.initial,
    required this.existingOrcamentos,
  });
  
  @override
  State<OrcamentoEditorSheet> createState() => _OrcamentoEditorSheetState();
}

class _OrcamentoEditorSheetState extends State<OrcamentoEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _api = OrcamentosApiRepository();
  
  late final TextEditingController _clienteCtrl;
  late final TextEditingController _numeroCtrl;
  late final TextEditingController _freteDescCtrl;
  late final TextEditingController _freteValorCtrl;
  late final TextEditingController _munckHorasCtrl;
  late final TextEditingController _munckValorHoraCtrl;
  late final TextEditingController _formaPagamentoCtrl;
  late final TextEditingController _condicoesPagamentoCtrl;
  late final TextEditingController _condicoesPagamentoOutrasCtrl;
  late final TextEditingController _prazoEntregaCtrl;
  final TextEditingController _produtoSearchCtrl = TextEditingController();

  final List<TextEditingController> _despesaDescControllers = [];
  final List<TextEditingController> _despesaValorControllers = [];

  final FocusNode _dialogFocusNode = FocusNode();
  final FocusNode _clienteFocusNode = FocusNode();
  final FocusNode _numeroFocusNode = FocusNode();
  final FocusNode _freteDescFocusNode = FocusNode();
  final FocusNode _freteValorFocusNode = FocusNode();
  final FocusNode _munckHorasFocusNode = FocusNode();
  final FocusNode _munckValorHoraFocusNode = FocusNode();
  final FocusNode _formaPagamentoFocusNode = FocusNode();
  final FocusNode _condicoesPagamentoFocusNode = FocusNode();
  final FocusNode _condicoesPagamentoOutrasFocusNode = FocusNode();
  final FocusNode _prazoEntregaFocusNode = FocusNode();
  final FocusNode _produtoSearchFocusNode = FocusNode();
  
  final List<FocusNode> _despesaDescFocusNodes = [];
  final List<FocusNode> _despesaValorFocusNodes = [];

  late final String _initialCliente;
  late final String _initialNumero;
  late final String _initialFreteDesc;
  late final String _initialFreteValor;
  late final String _initialMunckHoras;
  late final String _initialMunckValorHora;
  late final String _initialFormaPagamento;
  late final String _initialCondicoesPagamento;
  late final String _initialPrazoEntrega;
  late final bool? _initialFrete;
  late final bool? _initialCaminhaoMunck;
  late final bool? _initialDespesasAdicionais;
  late final int? _initialSelectedProdutoId;
  late final List<String> _initialDespesasDesc;
  late final List<String> _initialDespesasValor;
  late final Map<int, String> _initialQuantities;

  final List<String> _formaPagamentoOptions = [
    'A COMBINAR',
    'BOLETO',
    'CARTÃO CRÉDITO',
    'CARTÃO DÉBITO',
    'CHEQUE',
    'DEPÓSITO',
    'DINHEIRO',
    'PERMUTA',
    'PIX',
    'SEM VALOR',
  ];

  final List<String> _condicoesPagamentoOptions = [
    '1+1',
    '10 + 30 + 60 DIAS',
    '10 DIAS',
    '10X NO BOLETO',
    '10X NO CARTÃO DE CRÉDITO',
    '120 DIAS',
    '12x NO CARTÃO COM JUROS',
    '14 DIAS',
    '14 E 28 DIAS',
    '14, 21 E 28 DIAS',
    '14, 28 E 56 DIAS',
    '14, 28, 42, 56, 70 E 84 DIAS',
    '14/28/42/56',
    '15 DIAS',
    '15/30/45 DIAS',
    '20 DIAS',
    '20, 40, 60, 80, 100 e 120 DIAS',
    '21 DIAS',
    '28 DIAS',
    '28 E 42 DIAS',
    '28 E 56 DIAS',
    '28, 42 E 56 DO PEDIDO',
    '28, 56 E 84 DIAS DIRETO',
    '2X NO CARTÃO DE CRÉDITO',
    '30 + 60 DIAS',
    '30 DIAS',
    '30/45/60',
    '35 DIAS',
    '3X NO CARTÃO DE CRÉDITO',
    '4 DIAS',
    '45 DIAS',
    '4X NO CARTÃO DE CRÉDITO',
    '50% DE ENTRADA NO PEDIDO + 25% NA ENTREGA + 25% PARA 28',
    '50% DE ENTRADA NO PEDIDO + 50% NA ENTREGA / INSTALAÇÃO',
    '50% DE ENTRADA NO PEDIDO + 50% NA RETIRADA',
    '5X NO CARTÃO DE CRÉDITO',
    '60 DIAS',
    '60% PAGAMENTO VIA PIX E 40% PERMUTA',
    '6X NO CARTÃO DE CRÉDITO',
    '7 DIAS',
    '7, 14 E 28 DIAS',
    '7x CARTÃO DE CREDITO',
    '8x',
    '90 DIAS',
    'À VISTA',
    'BOLETO 14, 28 e 42 DIAS',
    'CRÉDITO À VISTA',
    'ENTRADA + 15 + 30 DIAS',
    'ENTRADA + 24 + 42 + 56',
    'ENTRADA + 28 DIAS',
    'ENTRADA + 28, 42 E 56 DIAS',
    'ENTRADA + 28, 56, 84 E 112 DO PEDIDO',
    'ENTRADA + 28/42 DIAS',
    'ENTRADA + 28/56 DIAS',
    'ENTRADA + 28/56/84 dias',
    'ENTRADA + 30 + 60 DIAS',
    'ENTRADA + 42 + 56 DIAS',
    'ENTRADA + 4X NO CARTÃO SEM JUROS',
    'ENTRADA + 5X',
    'ENTRADA + MEDIÇÕES + 5% PARA 28 DIAS APÓS TÉRMINO',
    'ENTRADA DE 30% + 28, 42, 56 E 70 DIAS DO PEDIDO',
    'ENTRADA DE 30% + MEDIÇÕES',
    'ENTRADA de 35% + BOLETO 14, 28 E 42 DIAS',
    'SEM VALOR',
    'OUTROS',
  ];

  void _updateTotal() {
    setState(() {});
  }
  
  List<ProdutoItem> _produtos = [];
  ProdutoItem? _selectedProduto;
  final Map<int, TextEditingController> _quantityControllers = {};
  final Map<int, FocusNode> _quantityFocusNodes = {};
  bool _loading = true;
  bool _isShowingDiscardDialog = false;
  String _produtoSearchQuery = '';
  String? _selectedFormaPagamento;
  String? _selectedCondicaoPagamento;

  bool? _frete;
  bool? _caminhaoMunck;
  bool? _despesasAdicionais;

  @override
  void initState() {
    super.initState();
    
    _initialCliente = widget.initial?.cliente ?? '';
    _initialNumero = widget.initial?.numero.toString() ?? '';
    _initialFreteDesc = widget.initial?.freteDesc ?? '';
    _initialFreteValor = widget.initial?.freteValor?.toStringAsFixed(2) ?? '';
    _initialMunckHoras = widget.initial?.caminhaoMunckHoras?.toStringAsFixed(1) ?? '';
    _initialMunckValorHora = widget.initial?.caminhaoMunckValorHora?.toStringAsFixed(2) ?? '';
    _initialFormaPagamento = widget.initial?.formaPagamento ?? '';
    _initialCondicoesPagamento = widget.initial?.condicoesPagamento ?? '';
    _initialPrazoEntrega = widget.initial?.prazoEntrega ?? '';
    _initialFrete = widget.initial?.frete;
    _initialCaminhaoMunck = widget.initial?.caminhaoMunck;
    _initialDespesasAdicionais = widget.initial != null 
      ? (widget.initial!.despesasAdicionais.isNotEmpty ? true : false)
      : null;    _initialSelectedProdutoId = widget.initial?.produtoId;
    
    _initialDespesasDesc = widget.initial?.despesasAdicionais.map((d) => d.descricao).toList() ?? [];
    _initialDespesasValor = widget.initial?.despesasAdicionais.map((d) => d.valor.toStringAsFixed(2)).toList() ?? [];
    
    _initialQuantities = {};
    if (widget.initial != null) {
      for (final mat in widget.initial!.materiais) {
        _initialQuantities[mat.materialId] = mat.quantidade;
      }
    }
    
    _clienteCtrl = TextEditingController(text: _initialCliente);
    _numeroCtrl = TextEditingController(text: _initialNumero);
    _freteDescCtrl = TextEditingController(text: _initialFreteDesc);
    _freteValorCtrl = TextEditingController(text: _initialFreteValor);
    _munckHorasCtrl = TextEditingController(text: _initialMunckHoras);
    _munckValorHoraCtrl = TextEditingController(text: _initialMunckValorHora);
    _prazoEntregaCtrl = TextEditingController(text: _initialPrazoEntrega);
    
    if (_initialFormaPagamento.isNotEmpty) {
      if (_formaPagamentoOptions.contains(_initialFormaPagamento)) {
        _selectedFormaPagamento = _initialFormaPagamento;
        _formaPagamentoCtrl = TextEditingController(text: _initialFormaPagamento);
      } else {
        _formaPagamentoCtrl = TextEditingController(text: _initialFormaPagamento);
      }
    } else {
      _formaPagamentoCtrl = TextEditingController();
    }
    
    if (_initialCondicoesPagamento.isNotEmpty) {
      if (_condicoesPagamentoOptions.contains(_initialCondicoesPagamento)) {
        _selectedCondicaoPagamento = _initialCondicoesPagamento;
        _condicoesPagamentoCtrl = TextEditingController(text: _initialCondicoesPagamento);
        _condicoesPagamentoOutrasCtrl = TextEditingController();
      } else {
        _selectedCondicaoPagamento = 'OUTROS';
        _condicoesPagamentoCtrl = TextEditingController(text: 'OUTROS');
        _condicoesPagamentoOutrasCtrl = TextEditingController(text: _initialCondicoesPagamento);
      }
    } else {
      _condicoesPagamentoCtrl = TextEditingController();
      _condicoesPagamentoOutrasCtrl = TextEditingController();
    }
    
    _freteValorCtrl.addListener(_updateTotal);
    _munckHorasCtrl.addListener(_updateTotal);
    _munckValorHoraCtrl.addListener(_updateTotal);
    
    _produtoSearchCtrl.addListener(() {
      setState(() {
        _produtoSearchQuery = _produtoSearchCtrl.text.toLowerCase();
      });
    });
    
    if (widget.initial != null) {
      _frete = widget.initial!.frete;
      _caminhaoMunck = widget.initial!.caminhaoMunck;
      _despesasAdicionais = widget.initial != null
          ? (widget.initial!.despesasAdicionais.isNotEmpty ? true : false)
          : null;      
      if (widget.initial!.despesasAdicionais.isNotEmpty) {
        for (final despesa in widget.initial!.despesasAdicionais) {
          final descCtrl = TextEditingController(text: despesa.descricao);
          final valorCtrl = TextEditingController(text: despesa.valor.toStringAsFixed(2));
          final descFocus = FocusNode();
          final valorFocus = FocusNode();
          
          descCtrl.addListener(_updateTotal);
          valorCtrl.addListener(_updateTotal);
          descFocus.addListener(_onFieldFocusChange);
          valorFocus.addListener(_onFieldFocusChange);
          
          _despesaDescControllers.add(descCtrl);
          _despesaValorControllers.add(valorCtrl);
          _despesaDescFocusNodes.add(descFocus);
          _despesaValorFocusNodes.add(valorFocus);
        }
      }
    }
    
    _clienteFocusNode.addListener(_onFieldFocusChange);
    _numeroFocusNode.addListener(_onFieldFocusChange);
    _freteDescFocusNode.addListener(_onFieldFocusChange);
    _freteValorFocusNode.addListener(_onFieldFocusChange);
    _munckHorasFocusNode.addListener(_onFieldFocusChange);
    _munckValorHoraFocusNode.addListener(_onFieldFocusChange);
    _formaPagamentoFocusNode.addListener(_onFieldFocusChange);
    _condicoesPagamentoFocusNode.addListener(_onFieldFocusChange);
    _condicoesPagamentoOutrasFocusNode.addListener(_onFieldFocusChange);
    _prazoEntregaFocusNode.addListener(_onFieldFocusChange);
    _produtoSearchFocusNode.addListener(_onFieldFocusChange);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dialogFocusNode.requestFocus();
    });
    
    _loadProdutos();
  }

  void _onFieldFocusChange() {
    if (!_clienteFocusNode.hasFocus && 
        !_numeroFocusNode.hasFocus && 
        !_freteDescFocusNode.hasFocus && 
        !_freteValorFocusNode.hasFocus && 
        !_munckHorasFocusNode.hasFocus && 
        !_munckValorHoraFocusNode.hasFocus && 
        !_formaPagamentoFocusNode.hasFocus && 
        !_condicoesPagamentoFocusNode.hasFocus && 
        !_condicoesPagamentoOutrasFocusNode.hasFocus && 
        !_prazoEntregaFocusNode.hasFocus && 
        !_produtoSearchFocusNode.hasFocus &&
        !_despesaDescFocusNodes.any((node) => node.hasFocus) &&
        !_despesaValorFocusNodes.any((node) => node.hasFocus) &&
        !_quantityFocusNodes.values.any((node) => node.hasFocus)) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && !_isShowingDiscardDialog) {
          _dialogFocusNode.requestFocus();
        }
      });
    }
  }

  bool get _hasChanges {
    if (_clienteCtrl.text.trim() != _initialCliente) return true;
    if (_numeroCtrl.text != _initialNumero) return true;
    if (_freteDescCtrl.text.trim() != _initialFreteDesc) return true;
    if (_freteValorCtrl.text != _initialFreteValor) return true;
    if (_munckHorasCtrl.text != _initialMunckHoras) return true;
    if (_munckValorHoraCtrl.text != _initialMunckValorHora) return true;
    
    final currentFormaPagamento = _formaPagamentoCtrl.text.trim();
    if (currentFormaPagamento != _initialFormaPagamento) return true;
    
    final currentCondicao = _selectedCondicaoPagamento == 'OUTROS' 
        ? _condicoesPagamentoOutrasCtrl.text.trim() 
        : _condicoesPagamentoCtrl.text.trim();
    if (currentCondicao != _initialCondicoesPagamento) return true;
    
    if (_prazoEntregaCtrl.text.trim() != _initialPrazoEntrega) return true;
    if (_frete != _initialFrete) return true;
    if (_caminhaoMunck != _initialCaminhaoMunck) return true;
    if (_despesasAdicionais != _initialDespesasAdicionais) return true;
    if (_selectedProduto?.id != _initialSelectedProdutoId) return true;
    
    if (_despesaDescControllers.length != _initialDespesasDesc.length) return true;
    for (int i = 0; i < _despesaDescControllers.length; i++) {
      if (i >= _initialDespesasDesc.length) return true;
      if (_despesaDescControllers[i].text != _initialDespesasDesc[i]) return true;
      if (_despesaValorControllers[i].text != _initialDespesasValor[i]) return true;
    }
    
    for (final entry in _quantityControllers.entries) {
      final initialQty = _initialQuantities[entry.key] ?? '';
      if (entry.value.text != initialQty) return true;
    }
    
    return false;
  }

  Future<void> _loadProdutos() async {
    try {
      final produtos = await _api.fetchProdutos();
      if (!mounted) return;
      setState(() {
        _produtos = produtos..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
        _loading = false;
        if (widget.initial != null) {
          _selectedProduto = produtos.firstWhere(
            (p) => p.id == widget.initial!.produtoId,
            orElse: () => produtos.first,
          );
          _initializeQuantityControllers();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar produtos: $e')),
      );
    }
  }

  void _initializeQuantityControllers() {
    if (_selectedProduto == null) return;
    
    for (final mat in _selectedProduto!.materiais) {
      final existingQty = widget.initial?.materiais
          .firstWhere((m) => m.materialId == mat.materialId,
              orElse: () => const OrcamentoMaterialItem(
                  id: 0,
                  materialId: 0,
                  materialNome: '',
                  materialUnidade: '',
                  materialCusto: 0,
                  quantidade: ''))
          .quantidade ?? '';
      
      final controller = TextEditingController(text: existingQty);
      final focusNode = FocusNode();
      
      controller.addListener(_updateTotal);
      focusNode.addListener(_onFieldFocusChange);
      
      _quantityControllers[mat.materialId] = controller;
      _quantityFocusNodes[mat.materialId] = focusNode;
    }
  }

  @override
  void dispose() {
    _clienteCtrl.dispose();
    _numeroCtrl.dispose();
    _freteDescCtrl.dispose();
    _freteValorCtrl.dispose();
    _munckHorasCtrl.dispose();
    _munckValorHoraCtrl.dispose();
    _formaPagamentoCtrl.dispose();
    _condicoesPagamentoCtrl.dispose();
    _condicoesPagamentoOutrasCtrl.dispose();
    _prazoEntregaCtrl.dispose();
    _produtoSearchCtrl.dispose();
    
    _dialogFocusNode.dispose();
    _clienteFocusNode.dispose();
    _numeroFocusNode.dispose();
    _freteDescFocusNode.dispose();
    _freteValorFocusNode.dispose();
    _munckHorasFocusNode.dispose();
    _munckValorHoraFocusNode.dispose();
    _formaPagamentoFocusNode.dispose();
    _condicoesPagamentoFocusNode.dispose();
    _condicoesPagamentoOutrasFocusNode.dispose();
    _prazoEntregaFocusNode.dispose();
    _produtoSearchFocusNode.dispose();
    
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
    for (final focusNode in _quantityFocusNodes.values) {
      focusNode.dispose();
    }
    
    for (final controller in _despesaDescControllers) {
      controller.dispose();
    }
    for (final controller in _despesaValorControllers) {
      controller.dispose();
    }
    for (final focusNode in _despesaDescFocusNodes) {
      focusNode.dispose();
    }
    for (final focusNode in _despesaValorFocusNodes) {
      focusNode.dispose();
    }
    
    super.dispose();
  }

  double _calculateTotal() {
    if (_selectedProduto == null) return 0.0;
    double total = 0.0;
    
    for (final mat in _selectedProduto!.materiais) {
      final controller = _quantityControllers[mat.materialId];
      if (controller != null) {
        final qty = double.tryParse(controller.text.replaceAll(',', '.')) ?? 0.0;
        total += mat.materialCusto * qty;
      }
    }
    
    for (final valorCtrl in _despesaValorControllers) {
      final valor = double.tryParse(valorCtrl.text.replaceAll(',', '.')) ?? 0.0;
      total += valor;
    }
    
    if (_frete == true) {
      final valor = double.tryParse(_freteValorCtrl.text.replaceAll(',', '.')) ?? 0.0;
      total += valor;
    }
    
    if (_caminhaoMunck == true) {
      final horas = double.tryParse(_munckHorasCtrl.text.replaceAll(',', '.')) ?? 0.0;
      final valorHora = double.tryParse(_munckValorHoraCtrl.text.replaceAll(',', '.')) ?? 150.0;
      total += horas * valorHora;
    }
    
    return total;
  }

  void _adicionarDespesa() {
    final descCtrl = TextEditingController();
    final valorCtrl = TextEditingController();
    final descFocus = FocusNode();
    final valorFocus = FocusNode();
    
    descCtrl.addListener(_updateTotal);
    valorCtrl.addListener(_updateTotal);
    descFocus.addListener(_onFieldFocusChange);
    valorFocus.addListener(_onFieldFocusChange);
    
    setState(() {
      _despesaDescControllers.add(descCtrl);
      _despesaValorControllers.add(valorCtrl);
      _despesaDescFocusNodes.add(descFocus);
      _despesaValorFocusNodes.add(valorFocus);
    });
  }

  void _removerDespesa(int index) {
    _despesaDescControllers[index].dispose();
    _despesaValorControllers[index].dispose();
    _despesaDescFocusNodes[index].dispose();
    _despesaValorFocusNodes[index].dispose();
    
    setState(() {
      _despesaDescControllers.removeAt(index);
      _despesaValorControllers.removeAt(index);
      _despesaDescFocusNodes.removeAt(index);
      _despesaValorFocusNodes.removeAt(index);
    });
  }

  String? _validateNumeroOrcamento(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Informe o número';
    }
    
    final trimmedNumero = value.trim();
    final numero = int.tryParse(trimmedNumero);
    
    if (numero == null) {
      return 'Número inválido';
    }
    
    final isDuplicate = widget.existingOrcamentos.any((orcamento) =>
        orcamento.numero == numero &&
        orcamento.id != widget.initial?.id);
    
    if (isDuplicate) {
      return 'Já existe um orçamento\ncom este número';
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

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final materiais = <OrcamentoMaterialItem>[];
    
    for(final mat in _selectedProduto!.materiais) {
      final controller = _quantityControllers[mat.materialId];
      if (controller == null) continue;
      
      final qty = controller.text.trim();
      if (qty.isEmpty) continue;
      
      final qtyValue = double.tryParse(qty.replaceAll(',', '.'));
      if (qtyValue == null || qtyValue < 0) continue;
      
      materiais.add(OrcamentoMaterialItem(
        id: widget.initial?.materiais
                .firstWhere((m) => m.materialId == mat.materialId,
                    orElse: () => const OrcamentoMaterialItem(
                        id: 0,
                        materialId: 0,
                        materialNome: '',
                        materialUnidade: '',
                        materialCusto: 0,
                        quantidade: '0'))
                .id ??
            0,
        materialId: mat.materialId,
        materialNome: mat.materialNome,
        materialUnidade: mat.materialUnidade,
        materialCusto: mat.materialCusto,
        quantidade: qty.replaceAll(',', '.'),
      ));
    }

    final despesas = <DespesaAdicionalItem>[];
    for (int i = 0; i < _despesaDescControllers.length; i++) {
      final desc = _despesaDescControllers[i].text.trim();
      final valorText = _despesaValorControllers[i].text.trim();
      
      if (desc.isEmpty || valorText.isEmpty) continue;
      
      final valor = double.tryParse(valorText.replaceAll(',', '.'));
      if (valor == null || valor <= 0) continue;
      
      despesas.add(DespesaAdicionalItem(
        id: widget.initial != null && i < widget.initial!.despesasAdicionais.length 
            ? widget.initial!.despesasAdicionais[i].id 
            : 0,
        descricao: desc,
        valor: valor,
      ));
    }

    final formaPagamento = _formaPagamentoCtrl.text.trim();
    final condicoesPagamento = _selectedCondicaoPagamento == 'OUTROS'
        ? _condicoesPagamentoOutrasCtrl.text.trim()
        : _condicoesPagamentoCtrl.text.trim();

    final now = DateTime.now();
    final item = (widget.initial ??
            OrcamentoItem(
              id: 0,
              cliente: '',
              numero: 0,
              status: 'Pendente',
              produtoId: 0,
              produtoNome: '',
              materiais: [],
              formaPagamento: '',
              condicoesPagamento: '',
              prazoEntrega: '',
              createdAt: now,
              updatedAt: now,
            ))
        .copyWith(
      cliente: _clienteCtrl.text.trim(),
      numero: int.parse(_numeroCtrl.text.trim()),
      produtoId: _selectedProduto!.id,
      produtoNome: _selectedProduto!.nome,
      materiais: materiais,
      despesasAdicionais: despesas,
      frete: _frete ?? false,
      freteDesc: _frete == true ? _freteDescCtrl.text.trim() : null,
      freteValor: _frete == true 
          ? double.tryParse(_freteValorCtrl.text.replaceAll(',', '.'))
          : null,
      caminhaoMunck: _caminhaoMunck ?? false,
      caminhaoMunckHoras: _caminhaoMunck == true 
          ? double.tryParse(_munckHorasCtrl.text.replaceAll(',', '.'))
          : null,
      caminhaoMunckValorHora: _caminhaoMunck == true 
          ? double.tryParse(_munckValorHoraCtrl.text.replaceAll(',', '.'))
          : null,
      formaPagamento: formaPagamento,
      condicoesPagamento: condicoesPagamento,
      prazoEntrega: _prazoEntregaCtrl.text.trim(),
    );

    Navigator.of(context).pop(item);
  }

  List<ProdutoItem> get _filteredProdutos {
    if (_produtoSearchQuery.isEmpty) {
      return _produtos;
    }
    return _produtos
        .where((p) => p.nome.toLowerCase().contains(_produtoSearchQuery))
        .toList();
  }

  Widget _buildDespesasSection() {
    final theme = Theme.of(context);
    
    return FormField<bool>(
      initialValue: _despesasAdicionais,
      validator: (value) {
        if (value == null) {
          return 'Selecione Sim ou Não';
        }
        // Validação adicional: se escolheu "Sim", deve ter pelo menos uma despesa
        if (value == true && _despesaDescControllers.isEmpty) {
          return 'Adicione pelo menos uma despesa';
        }
        return null;
      },
      builder: (formFieldState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: formFieldState.hasError
                      ? theme.colorScheme.error
                      : _despesasAdicionais == true
                          ? theme.colorScheme.primary.withValues(alpha: 0.3)
                          : theme.dividerColor.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Despesas Adicionais',
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ),
                      Row(
                        children: [
                          _buildToggleButton('Não', _despesasAdicionais == false, () {
                            setState(() {
                              _despesasAdicionais = false;
                              for (final controller in _despesaDescControllers) {
                                controller.dispose();
                              }
                              for (final controller in _despesaValorControllers) {
                                controller.dispose();
                              }
                              for (final focusNode in _despesaDescFocusNodes) {
                                focusNode.dispose();
                              }
                              for (final focusNode in _despesaValorFocusNodes) {
                                focusNode.dispose();
                              }
                              _despesaDescControllers.clear();
                              _despesaValorControllers.clear();
                              _despesaDescFocusNodes.clear();
                              _despesaValorFocusNodes.clear();
                            });
                            formFieldState.didChange(false);
                          }),
                          const SizedBox(width: 6),
                          _buildToggleButton('Sim', _despesasAdicionais == true, () {
                            setState(() {
                              _despesasAdicionais = true;
                            });
                            formFieldState.didChange(true);
                          }),
                        ],
                      ),
                    ],
                  ),
                  if (formFieldState.hasError) ...[
                    const SizedBox(height: 6),
                    Text(
                      formFieldState.errorText ?? '',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontSize: 10,
                      ),
                    ),
                  ],
                  if (_despesasAdicionais == true) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Lista de Despesas',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        ExcludeFocus(
                          child: IconButton(
                            onPressed: _adicionarDespesa,
                            icon: const Icon(Icons.add_circle_outline, size: 18),
                            tooltip: 'Adicionar despesa',
                            style: IconButton.styleFrom(
                              foregroundColor: theme.colorScheme.primary,
                              padding: EdgeInsets.zero,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (_despesaDescControllers.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Clique no + para adicionar despesas',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...List.generate(_despesaDescControllers.length, (index) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _despesaDescControllers[index],
                                  focusNode: _despesaDescFocusNodes[index],
                                  style: const TextStyle(fontSize: 12),
                                  decoration: const InputDecoration(
                                    labelText: 'Descrição',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe' : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _despesaValorControllers[index],
                                  focusNode: _despesaValorFocusNodes[index],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                                  ],
                                  style: const TextStyle(fontSize: 12),
                                  decoration: const InputDecoration(
                                    labelText: 'Valor',
                                    isDense: true,
                                    prefixText: 'R\$ ',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Informe';
                                    }
                                    final value = double.tryParse(v.replaceAll(',', '.'));
                                    if (value == null || value <= 0) {
                                      return 'Inválido';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              ExcludeFocus(
                                child: IconButton(
                                  onPressed: () => _removerDespesa(index),
                                  icon: const Icon(Icons.delete_outline, size: 16),
                                  color: theme.colorScheme.error,
                                  tooltip: 'Remover',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');

    return GestureDetector(
      onTap: () {
        _dialogFocusNode.requestFocus();
      },
      child: Dialog(
        insetPadding: const EdgeInsets.all(20),
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () {},
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;
              final shouldPop = await _onWillPop();
              if (shouldPop && mounted && context.mounted) {
                Navigator.of(context).pop();
              }
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
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1400, maxHeight: 850),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : Row(
                        children: [
                          Container(
                            width: 240,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Produtos',
                                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: _produtoSearchCtrl,
                                        focusNode: _produtoSearchFocusNode,
                                        decoration: InputDecoration(
                                          hintText: 'Buscar...',
                                          isDense: true,
                                          prefixIcon: const Icon(Icons.search, size: 18),
                                          suffixIcon: _produtoSearchQuery.isNotEmpty
                                              ? IconButton(
                                                  icon: const Icon(Icons.clear, size: 16),
                                                  onPressed: () {
                                                    _produtoSearchCtrl.clear();
                                                  },
                                                )
                                              : null,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: ExcludeFocus(
                                    child: _filteredProdutos.isEmpty
                                        ? Center(
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Text(
                                                'Nenhum produto encontrado',
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          )
                                        : ListView.builder(
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            itemCount: _filteredProdutos.length,
                                            itemBuilder: (context, index) {
                                              final produto = _filteredProdutos[index];
                                              final isSelected = _selectedProduto?.id == produto.id;
                                              
                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: 6),
                                                child: InkWell(
                                                  onTap: () {
                                                    setState(() {
                                                      _selectedProduto = produto;
                                                      for (final controller in _quantityControllers.values) {
                                                        controller.dispose();
                                                      }
                                                      for (final focusNode in _quantityFocusNodes.values) {
                                                        focusNode.dispose();
                                                      }
                                                      _quantityControllers.clear();
                                                      _quantityFocusNodes.clear();
                                                      _initializeQuantityControllers();
                                                    });
                                                  },
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(10),
                                                    decoration: BoxDecoration(
                                                      color: isSelected
                                                          ? theme.colorScheme.primary.withValues(alpha: 0.15)
                                                          : theme.colorScheme.surface,
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: isSelected
                                                            ? theme.colorScheme.primary.withValues(alpha: 0.5)
                                                            : theme.dividerColor.withValues(alpha: 0.1),
                                                        width: isSelected ? 2 : 1,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.all(6),
                                                          decoration: BoxDecoration(
                                                            color: isSelected
                                                                ? theme.colorScheme.primary.withValues(alpha: 0.2)
                                                                : theme.colorScheme.primary.withValues(alpha: 0.1),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Icon(
                                                            Icons.inventory_2_outlined,
                                                            color: theme.colorScheme.primary,
                                                            size: 16,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(produto.nome,
                                                                style: theme.textTheme.bodySmall?.copyWith(
                                                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                                  fontSize: 12,
                                                                ),
                                                                maxLines: 2,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                              Text(
                                                                '${produto.materiais.length} materiais',
                                                                style: theme.textTheme.bodySmall?.copyWith(
                                                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                                                  fontSize: 10,
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
                                            },
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: theme.dividerColor.withValues(alpha: 0.1),
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            widget.initial == null ? 'Novo Orçamento' : 'Editar Orçamento',
                                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                        ExcludeFocus(
                                          child: IconButton(
                                            onPressed: () async {
                                              final shouldClose = await _onWillPop();
                                              if (shouldClose && context.mounted) {
                                                Navigator.of(context).pop();
                                              }
                                            },
                                            icon: const Icon(Icons.close),
                                            tooltip: 'Fechar (Esc)',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                flex: 2,
                                                child: TextFormField(
                                                  controller: _clienteCtrl,
                                                  focusNode: _clienteFocusNode,
                                                  style: const TextStyle(fontSize: 13),
                                                  decoration: const InputDecoration(
                                                    labelText: 'Cliente',
                                                    isDense: true,
                                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                  ),
                                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o cliente' : null,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: TextFormField(
                                                  controller: _numeroCtrl,
                                                  focusNode: _numeroFocusNode,
                                                  keyboardType: TextInputType.number,
                                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                                  style: const TextStyle(fontSize: 13),
                                                  decoration: const InputDecoration(
                                                    labelText: 'Nº Orçamento',
                                                    isDense: true,
                                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                  ),
                                                  validator: _validateNumeroOrcamento,
                                                ),
                                              ),
                                            ],
                                          ),
                                          
                                          const SizedBox(height: 16),
                                          
                                          if (_selectedProduto == null)
                                            Column(
                                              children: [
                                                FormField<bool>(
                                                  initialValue: false,
                                                  validator: (_) => _selectedProduto == null ? 'Selecione um produto' : null,
                                                  builder: (formFieldState) {
                                                    return Column(
                                                      children: [
                                                        if (formFieldState.hasError)
                                                          Container(
                                                            padding: const EdgeInsets.all(12),
                                                            margin: const EdgeInsets.only(bottom: 12),
                                                            decoration: BoxDecoration(
                                                              color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                                                              borderRadius: BorderRadius.circular(8),
                                                              border: Border.all(
                                                                color: theme.colorScheme.error.withValues(alpha: 0.5),
                                                              ),
                                                            ),
                                                            child: Row(
                                                              children: [
                                                                Icon(
                                                                  Icons.error_outline,
                                                                  color: theme.colorScheme.error,
                                                                  size: 18,
                                                                ),
                                                                const SizedBox(width: 10),
                                                                Expanded(
                                                                  child: Text(
                                                                    formFieldState.errorText ?? '',
                                                                    style: theme.textTheme.bodySmall?.copyWith(
                                                                      color: theme.colorScheme.error,
                                                                      fontWeight: FontWeight.w500,
                                                                      fontSize: 12,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 40),
                                                  child: Center(
                                                    child: Column(
                                                      children: [
                                                        Icon(
                                                          Icons.inventory_2_outlined,
                                                          size: 48,
                                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                                                        ),
                                                        const SizedBox(height: 12),
                                                        Text(
                                                          'Selecione um produto',
                                                          style: theme.textTheme.titleMedium?.copyWith(
                                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                                          ),
                                                        ),
                                                        const SizedBox(height: 6),
                                                        Text(
                                                          'Escolha um produto na lista ao lado',
                                                          style: theme.textTheme.bodySmall?.copyWith(
                                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            )
                                          else ...[
                                            Text(
                                              'Materiais',
                                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                                            ),
                                            const SizedBox(height: 8),
                                            
                                            ..._selectedProduto!.materiais.map((mat) {
                                              final controller = _quantityControllers[mat.materialId];
                                              final focusNode = _quantityFocusNodes[mat.materialId];
                                              if (controller == null || focusNode == null) return const SizedBox();
                                              
                                              final qty = double.tryParse(controller.text.replaceAll(',', '.')) ?? 0.0;
                                              final total = mat.materialCusto * qty;
                                              
                                              return Container(
                                                margin: const EdgeInsets.only(bottom: 6),
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      flex: 2,
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            mat.materialNome,
                                                            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 11),
                                                          ),
                                                          Text(
                                                            '${currency.format(mat.materialCusto)} / ${mat.materialUnidade}',
                                                            style: theme.textTheme.bodySmall?.copyWith(
                                                              fontSize: 10,
                                                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    SizedBox(
                                                      width: 70,
                                                      child: TextFormField(
                                                        controller: controller,
                                                        focusNode: focusNode,
                                                        keyboardType: TextInputType.numberWithOptions(
                                                          decimal: mat.materialUnidade == 'Kg',
                                                        ),
                                                        inputFormatters: [
                                                          if (mat.materialUnidade == 'Kg')
                                                            FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                                                          else
                                                            FilteringTextInputFormatter.digitsOnly
                                                        ],
                                                        textAlign: TextAlign.center,
                                                        style: const TextStyle(fontSize: 12),
                                                        decoration: const InputDecoration(
                                                          labelText: 'Qtd',
                                                          isDense: true,
                                                          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                                        ),
                                                        validator: (v) {
                                                          if (v == null || v.trim().isEmpty) {
                                                            return 'Informe';
                                                          }
                                                          final value = double.tryParse(v.replaceAll(',', '.'));
                                                          if (value == null || value < 0) {
                                                            return 'Inválido';
                                                          }
                                                          return null;
                                                        },
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    SizedBox(
                                                      width: 75,
                                                      child: Text(
                                                        currency.format(total),
                                                        style: theme.textTheme.bodySmall?.copyWith(
                                                          fontWeight: FontWeight.bold,
                                                          color: theme.colorScheme.primary,
                                                          fontSize: 11,
                                                        ),
                                                        textAlign: TextAlign.right,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }),
                                            
                                            const SizedBox(height: 12),
                                            
                                            _buildDespesasSection(),
                                            
                                            const SizedBox(height: 12),
                                            
                                            _buildToggleSection(
                                              title: 'Frete',
                                              value: _frete,
                                              onChanged: (v) {
                                                setState(() {
                                                  _frete = v;
                                                });
                                              },
                                              child: _frete == true
                                                  ? Row(
                                                      children: [
                                                        Expanded(
                                                          flex: 2,
                                                          child: TextFormField(
                                                            controller: _freteDescCtrl,
                                                            focusNode: _freteDescFocusNode,
                                                            style: const TextStyle(fontSize: 12),
                                                            decoration: const InputDecoration(
                                                              labelText: 'Descrição',
                                                              isDense: true,
                                                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                            ),
                                                            validator: (v)=> (v == null || v.trim().isEmpty) ? 'Informe' : null,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: TextFormField(
                                                            controller: _freteValorCtrl,
                                                            focusNode: _freteValorFocusNode,
                                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                            inputFormatters: [
                                                              FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                                                            ],
                                                            style: const TextStyle(fontSize: 12),
                                                            decoration: const InputDecoration(
                                                              labelText: 'Valor',
                                                              isDense: true,
                                                              prefixText: 'R\$ ',
                                                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                            ),
                                                            validator: (v) {
                                                              if (v == null || v.trim().isEmpty) {
                                                                return 'Informe';
                                                              }
                                                              final value = double.tryParse(v.replaceAll(',', '.'));
                                                              if (value == null || value <= 0) {
                                                                return 'Inválido';
                                                              }
                                                              return null;
                                                            },
                                                          ),
                                                        ),
                                                      ],
                                                    )
                                                  : null,
                                            ),
                                            
                                            const SizedBox(height: 8),
                                            
                                            _buildToggleSection(
                                              title: 'Caminhão Munck',
                                              value: _caminhaoMunck,
                                              onChanged: (v) {
                                                setState(() {
                                                  _caminhaoMunck = v;
                                                });
                                              },
                                              child: _caminhaoMunck == true
                                                  ? Row(
                                                      children: [
                                                        Expanded(
                                                          child: TextFormField(
                                                            controller: _munckHorasCtrl,
                                                            focusNode: _munckHorasFocusNode,
                                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                            inputFormatters: [
                                                              FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                                                            ],
                                                            style: const TextStyle(fontSize: 12),
                                                            decoration: const InputDecoration(
                                                              labelText: 'Horas',
                                                              isDense: true,
                                                              suffixText: 'h',
                                                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                            ),
                                                            validator: (v) {
                                                              if (v == null || v.trim().isEmpty) {
                                                                return 'Informe';
                                                              }
                                                              final value = double.tryParse(v.replaceAll(',', '.'));
                                                              if (value == null || value < 0) {
                                                                return 'Inválido';
                                                              }
                                                              return null;
                                                            },
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: TextFormField(
                                                            controller: _munckValorHoraCtrl,
                                                            focusNode: _munckValorHoraFocusNode,
                                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                            inputFormatters: [
                                                              FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                                                            ],
                                                            style: const TextStyle(fontSize: 12),
                                                            decoration: const InputDecoration(
                                                              labelText: 'Valor/Hora',
                                                              isDense: true,
                                                              prefixText: 'R\$ ',
                                                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                            ),
                                                            validator: (v) {
                                                              if (v == null || v.trim().isEmpty) {
                                                                return 'Informe';
                                                              }
                                                              final value = double.tryParse(v.replaceAll(',', '.'));
                                                              if (value == null || value < 0) {
                                                                return 'Inválido';
                                                              }
                                                              return null;
                                                            },
                                                          ),
                                                        ),
                                                      ],
                                                    )
                                                  : null,
                                            ),
                                            
                                            const SizedBox(height: 16),
                                            
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: DropdownButtonFormField<String>(
                                                    initialValue: _selectedFormaPagamento,
                                                    focusNode: _formaPagamentoFocusNode,
                                                    decoration: const InputDecoration(
                                                      labelText: 'Forma de Pagamento',
                                                      isDense: true,
                                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                    ),
                                                    style: const TextStyle(fontSize: 13),
                                                    items: _formaPagamentoOptions.map((option) {
                                                      return DropdownMenuItem<String>(
                                                        value: option,
                                                        child: Text(option),
                                                      );
                                                    }).toList(),
                                                    onChanged: (value) {
                                                      setState(() {
                                                        _selectedFormaPagamento = value;
                                                        if (value != null) {
                                                          _formaPagamentoCtrl.text = value;
                                                        }
                                                      });
                                                    },
                                                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Selecione' : null,
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      DropdownButtonFormField<String>(
                                                        initialValue: _selectedCondicaoPagamento,
                                                        focusNode: _condicoesPagamentoFocusNode,
                                                        decoration: const InputDecoration(
                                                          labelText: 'Condições de Pagamento',
                                                          isDense: true,
                                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                        ),
                                                        style: const TextStyle(fontSize: 13),
                                                        items: _condicoesPagamentoOptions.map((option) {
                                                          return DropdownMenuItem<String>(
                                                            value: option,
                                                            child: Text(option),
                                                          );
                                                        }).toList(),
                                                        onChanged: (value) {
                                                          setState(() {
                                                            _selectedCondicaoPagamento = value;
                                                            if (value != null && value != 'OUTROS') {
                                                              _condicoesPagamentoCtrl.text = value;
                                                              _condicoesPagamentoOutrasCtrl.clear();
                                                            } else if (value == 'OUTROS') {
                                                              _condicoesPagamentoCtrl.text = 'OUTROS';
                                                            }
                                                          });
                                                        },
                                                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Selecione' : null,
                                                      ),
                                                      if (_selectedCondicaoPagamento == 'OUTROS') ...[
                                                        const SizedBox(height: 10),
                                                        TextFormField(
                                                          controller: _condicoesPagamentoOutrasCtrl,
                                                          focusNode: _condicoesPagamentoOutrasFocusNode,
                                                          style: const TextStyle(fontSize: 13),
                                                          decoration: const InputDecoration(
                                                            labelText: 'Especifique as condições',
                                                            isDense: true,
                                                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                            hintText: 'Ex: 15/30/45 dias',
                                                          ),
                                                          validator: (v) => (v == null || v.trim().isEmpty) 
                                                              ? 'Informe as condições' 
                                                              : null,
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            
                                            const SizedBox(height: 10),
                                            
                                            TextFormField(
                                              controller: _prazoEntregaCtrl,
                                              focusNode: _prazoEntregaFocusNode,
                                              style: const TextStyle(fontSize: 13),
                                              decoration: const InputDecoration(
                                                labelText: 'Prazo de Entrega',
                                                isDense: true,
                                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                              ),
                                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o prazo' : null,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                  
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                      border: Border(
                                        top: BorderSide(
                                          color: theme.dividerColor.withValues(alpha: 0.1),
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Total do Orçamento',
                                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                            ),
                                            Text(
                                              currency.format(_calculateTotal()),
                                              style: theme.textTheme.titleLarge?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: theme.colorScheme.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ExcludeFocus(
                                                child: OutlinedButton(
                                                  onPressed: () async {
                                                    final shouldClose = await _onWillPop();
                                                    if (shouldClose && context.mounted) {
                                                      Navigator.of(context).pop();
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
                                                  onPressed: _save,
                                                  child: Text(widget.initial == null ? 'Finalizar' : 'Salvar'),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleSection({
    required String title,
    required bool? value,
    required ValueChanged<bool?> onChanged,
    Widget? child,
  }) {
    final theme = Theme.of(context);
    
    return FormField<bool>(
      initialValue: value,
      validator: (_) => value == null ? 'Selecione Sim ou Não' : null,
      builder: (formFieldState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: formFieldState.hasError
                      ? theme.colorScheme.error
                      : value == true
                          ? theme.colorScheme.primary.withValues(alpha: 0.3)
                          : theme.dividerColor.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ),
                      Row(
                        children: [
                          _buildToggleButton('Não', value == false, () {
                            onChanged(false);
                            formFieldState.didChange(false);
                          }),
                          const SizedBox(width: 6),
                          _buildToggleButton('Sim', value == true, () {
                            onChanged(true);
                            formFieldState.didChange(true);
                          }),
                        ],
                      ),
                    ],
                  ),
                  if (formFieldState.hasError) ...[
                    const SizedBox(height: 6),
                    Text(
                      formFieldState.errorText ?? '',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontSize: 10,
                      ),
                    ),
                  ],
                  if (child != null) ...[
                    const SizedBox(height: 8),
                    child,
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildToggleButton(String label, bool selected, VoidCallback onTap) {
    final theme = Theme.of(context);
    
    return ExcludeFocus(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: selected 
                ? theme.colorScheme.primary 
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected 
                  ? theme.colorScheme.primary 
                  : theme.dividerColor.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: selected 
                  ? theme.colorScheme.onPrimary 
                  : theme.colorScheme.onSurface,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}