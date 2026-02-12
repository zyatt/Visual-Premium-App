import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visualpremium/data/orcamentos_repository.dart';
import 'package:visualpremium/data/faixas_custo_repository.dart';
import 'package:visualpremium/models/orcamento_item.dart';
import 'package:visualpremium/widgets/clickable_ink.dart';
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
  final _scrollController = ScrollController();
  bool _loading = true;
  List<OrcamentoItem> _items = const [];
  List<ProdutoItem> _allProdutos = [];
  String _searchQuery = '';
  int? _downloadingId;
  SortOption _sortOption = SortOption.newestFirst;
  OrcamentoFilters _filters = const OrcamentoFilters();
  bool _showScrollToTopButton = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadProdutos();
    
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
            content: Text(isUpdate ? 'Orçamento "${item.numero}" salvo' : 'Orçamento "${item.numero}" cadastrado'),
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
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Orçamento $newStatus'),
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
              content: Text('PDF gerado!'),
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
                                ..._filters.produtoIds.map((produtoId) {
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
                    ClickableInk(
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
                              ClickableInk(
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
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
    
    if (endDate.isBefore(startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A data final deve ser posterior à data inicial')),
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                        ),
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
          ElevatedButton.icon(onPressed: onCreate, icon: const Icon(Icons.add, size: 18), label: const Text('Criar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
          ),
          
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClickableInk(
        onTap: onTap,
        splashColor: Colors.transparent,
        hoverColor: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.cliente,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            softWrap: true,
                          ),
                        ),
                      ],
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
                        Expanded(
                          child: Text(
                            item.produtoNome,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 10,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            softWrap: true,
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
      ),
    );
  }
}

class TimeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.toLowerCase();
    final filtered = text.replaceAll(RegExp(r'[^0-9hm,.]'), '');
    
    return TextEditingValue(
      text: filtered,
      selection: TextSelection.collapsed(offset: filtered.length),
    );
  }
  
  static double? parseToHours(String input) {
    if (input.trim().isEmpty) return null;
    
    final text = input.toLowerCase().trim();
    
    final horasMatch = RegExp(r'^(\d+[,.]?\d*)\s*h?$').firstMatch(text);
    if (horasMatch != null) {
      final valor = horasMatch.group(1)?.replaceAll(',', '.');
      return double.tryParse(valor ?? '');
    }
    
    final minutosMatch = RegExp(r'^(\d+)\s*m$').firstMatch(text);
    if (minutosMatch != null) {
      final minutos = int.tryParse(minutosMatch.group(1) ?? '');
      if (minutos != null) {
        return minutos / 60.0;
      }
    }
    
    final numero = double.tryParse(text.replaceAll(',', '.'));
    return numero;
  }
  
  static String formatHours(double hours) {
    if (hours == hours.toInt().toDouble()) {
      return '${hours.toInt()}h';
    }
    return '${hours.toStringAsFixed(1)}h';
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
  final _faixasApi = FaixasCustoRepository();

  List<Map<String, dynamic>> _faixas = [];
  Map<String, dynamic>? _valorSugeridoLocal;
  
  late final TextEditingController _clienteCtrl;
  late final TextEditingController _numeroCtrl;
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
  final FocusNode _formaPagamentoFocusNode = FocusNode();
  final FocusNode _condicoesPagamentoFocusNode = FocusNode();
  final FocusNode _condicoesPagamentoOutrasFocusNode = FocusNode();
  final FocusNode _prazoEntregaFocusNode = FocusNode();
  final FocusNode _produtoSearchFocusNode = FocusNode();
  final List<FocusNode> _despesaDescFocusNodes = [];
  final List<FocusNode> _despesaValorFocusNodes = [];
  
  late final String _initialCliente;
  late final String _initialNumero;
  late final String _initialFormaPagamento;
  late final String _initialCondicoesPagamento;
  late final String _initialPrazoEntrega;
  late final bool? _initialDespesasAdicionais;
  late final int? _initialSelectedProdutoId;
  late final List<String> _initialDespesasDesc;
  late final List<String> _initialDespesasValor;
  final Map<int, double> _initialQuantities = {};
  final Map<int, String> _initialQuantityStrings = {};
  final List<InformacaoAdicionalItem> _initialInformacoesAdicionais = [];

  final Map<int, bool?> _opcoesExtrasEnabled = {};
  final Map<int, bool?> _initialOpcoesExtrasEnabled = {};
  final Map<int, String> _initialOpcaoExtraStringValues = {};
  final Map<int, String> _initialOpcaoExtraFloat1Values = {};
  final Map<int, String> _initialOpcaoExtraFloat2Values = {};
  final Map<int, TextEditingController> _opcaoExtraStringControllers = {};
  final Map<int, TextEditingController> _opcaoExtraFloat1Controllers = {};
  final Map<int, TextEditingController> _opcaoExtraFloat2Controllers = {};
  final Map<int, FocusNode> _opcaoExtraStringFocusNodes = {};
  final Map<int, FocusNode> _opcaoExtraFloat1FocusNodes = {};
  final Map<int, FocusNode> _opcaoExtraFloat2FocusNodes = {};
  
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
    setState(() {
      _recalcularValorSugerido();
    });
  }
  void _recalcularValorSugerido() {
    if (_faixas.isEmpty) {
      _valorSugeridoLocal = null;
      return;
    }
    final custoTotal = _calculateTotal();
    if (custoTotal <= 0) {
      _valorSugeridoLocal = null;
      return;
    }

    Map<String, dynamic>? faixaAplicavel;
    for (final faixa in _faixas) {
      final dentroDoInicio = custoTotal >= (faixa['custoInicio'] as num);
      final custoFim = faixa['custoFim'] as num?;
      final dentroDoFim = custoFim == null || custoTotal <= custoFim;
      
      if (dentroDoInicio && dentroDoFim) {
        faixaAplicavel = faixa;
        break;
      }
    }

    if (faixaAplicavel == null) {
      _valorSugeridoLocal = null;
      return;
    }

    final margem = (faixaAplicavel['margem'] is int)
    ? (faixaAplicavel['margem'] as int).toDouble()
    : faixaAplicavel['margem'] as double;

    final valorSugerido = custoTotal * (1 + margem / 100);
    _valorSugeridoLocal = {
      'custoTotal': custoTotal,
      'margem': margem,
      'valorSugerido': valorSugerido,
      'faixaId': faixaAplicavel['id'],
      'custoInicio': faixaAplicavel['custoInicio'],
      'custoFim': faixaAplicavel['custoFim'],
    };
  }
  
  List<ProdutoItem> _produtos = [];
  ProdutoItem? _selectedProduto;
  final Map<int, TextEditingController> _quantityControllers = {};
  final Map<int, FocusNode> _quantityFocusNodes = {};
  final List<InformacaoAdicionalItem> _informacoesAdicionais = [];
  bool _loading = true;
  bool _faixasCarregadas = false;
  bool _produtosCarregados = false;
  bool _isShowingDiscardDialog = false;
  String _produtoSearchQuery = '';
  String? _selectedFormaPagamento;
  String? _selectedCondicaoPagamento;

  bool? _despesasAdicionais;

  String _formatQuantity(double value) {
    if (value == value.toInt()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year} ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }

  bool get _isAprovado => widget.initial?.status == 'Aprovado';

  @override
  void initState() {
    super.initState();
    
    _initialCliente = widget.initial?.cliente ?? '';
    _initialNumero = widget.initial?.numero.toString() ?? '';
    _initialFormaPagamento = widget.initial?.formaPagamento ?? '';
    _initialCondicoesPagamento = widget.initial?.condicoesPagamento ?? '';
    _initialPrazoEntrega = widget.initial?.prazoEntrega ?? '';
    _initialDespesasAdicionais = widget.initial != null 
      ? (widget.initial!.despesasAdicionais.isNotEmpty ? true : false)
      : null;
    _initialSelectedProdutoId = widget.initial?.produtoId;
    
    _initialDespesasDesc = widget.initial?.despesasAdicionais.map((d) => d.descricao).toList() ?? [];
    _initialDespesasValor = widget.initial?.despesasAdicionais.map((d) => d.valor.toStringAsFixed(2)).toList() ?? [];
    
    if (widget.initial != null && widget.initial!.informacoesAdicionais.isNotEmpty) {
      _informacoesAdicionais.addAll(widget.initial!.informacoesAdicionais);
      _initialInformacoesAdicionais.addAll(widget.initial!.informacoesAdicionais);
    }
    
    if (widget.initial != null && widget.initial!.opcoesExtras.isNotEmpty) {
      for (final opcaoValor in widget.initial!.opcoesExtras) {
        final hasValues = opcaoValor.valorString != null || 
                        opcaoValor.valorFloat1 != null || 
                        opcaoValor.valorFloat2 != null;
        
        _opcoesExtrasEnabled[opcaoValor.produtoOpcaoId] = hasValues;
        _initialOpcoesExtrasEnabled[opcaoValor.produtoOpcaoId] = hasValues;
        
        if (hasValues) {
          final stringValue = opcaoValor.valorString ?? '';
          final float1Value = opcaoValor.valorFloat1 != null ? _formatQuantity(opcaoValor.valorFloat1!) : '';
          final float2Value = opcaoValor.valorFloat2 != null ? _formatQuantity(opcaoValor.valorFloat2!) : '';
          
          _initialOpcaoExtraStringValues[opcaoValor.produtoOpcaoId] = stringValue;
          _initialOpcaoExtraFloat1Values[opcaoValor.produtoOpcaoId] = float1Value;
          _initialOpcaoExtraFloat2Values[opcaoValor.produtoOpcaoId] = float2Value;
          
          final stringCtrl = TextEditingController(text: opcaoValor.valorString ?? '');
          
          final float1Ctrl = TextEditingController(
            text: opcaoValor.valorFloat1 != null 
                ? _formatQuantity(opcaoValor.valorFloat1!) 
                : ''
          );
          final float2Ctrl = TextEditingController(
            text: opcaoValor.valorFloat2 != null 
                ? _formatQuantity(opcaoValor.valorFloat2!) 
                : ''
          );
          
          final stringFocus = FocusNode();
          final float1Focus = FocusNode();
          final float2Focus = FocusNode();
          
          stringCtrl.addListener(_updateTotal);
          float1Ctrl.addListener(_updateTotal);
          float2Ctrl.addListener(_updateTotal);
          stringFocus.addListener(_onFieldFocusChange);
          float1Focus.addListener(_onFieldFocusChange);
          float2Focus.addListener(_onFieldFocusChange);
          
          _opcaoExtraStringControllers[opcaoValor.produtoOpcaoId] = stringCtrl;
          _opcaoExtraFloat1Controllers[opcaoValor.produtoOpcaoId] = float1Ctrl;
          _opcaoExtraFloat2Controllers[opcaoValor.produtoOpcaoId] = float2Ctrl;
          _opcaoExtraStringFocusNodes[opcaoValor.produtoOpcaoId] = stringFocus;
          _opcaoExtraFloat1FocusNodes[opcaoValor.produtoOpcaoId] = float1Focus;
          _opcaoExtraFloat2FocusNodes[opcaoValor.produtoOpcaoId] = float2Focus;
        }
      }
    }

    _initialQuantities.clear();
    _initialQuantityStrings.clear();
    if (widget.initial != null) {
      for (final mat in widget.initial!.materiais) {
        _initialQuantities[mat.materialId] = mat.quantidade;
        _initialQuantityStrings[mat.materialId] = mat.quantidade > 0 ? _formatQuantity(mat.quantidade) : '';
      }
    }
    
    _clienteCtrl = TextEditingController(text: _initialCliente);
    _numeroCtrl = TextEditingController(text: _initialNumero);
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
    
    _produtoSearchCtrl.addListener(() {
      setState(() {
        _produtoSearchQuery = _produtoSearchCtrl.text.toLowerCase();
      });
    });
    
    if (widget.initial != null) {
      _despesasAdicionais = widget.initial!.despesasAdicionais.isNotEmpty ? true : false;
      
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
    _formaPagamentoFocusNode.addListener(_onFieldFocusChange);
    _condicoesPagamentoFocusNode.addListener(_onFieldFocusChange);
    _condicoesPagamentoOutrasFocusNode.addListener(_onFieldFocusChange);
    _prazoEntregaFocusNode.addListener(_onFieldFocusChange);
    _produtoSearchFocusNode.addListener(_onFieldFocusChange);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dialogFocusNode.requestFocus();
    });
    
    _loadProdutos();
    _loadFaixas();
  }

  void _onFieldFocusChange() {
    if (!_clienteFocusNode.hasFocus && 
        !_numeroFocusNode.hasFocus && 
        !_formaPagamentoFocusNode.hasFocus && 
        !_condicoesPagamentoFocusNode.hasFocus && 
        !_condicoesPagamentoOutrasFocusNode.hasFocus && 
        !_prazoEntregaFocusNode.hasFocus && 
        !_produtoSearchFocusNode.hasFocus &&
        !_despesaDescFocusNodes.any((node) => node.hasFocus) &&
        !_despesaValorFocusNodes.any((node) => node.hasFocus) &&
        !_quantityFocusNodes.values.any((node) => node.hasFocus) &&
        !_opcaoExtraStringFocusNodes.values.any((node) => node.hasFocus) &&
        !_opcaoExtraFloat1FocusNodes.values.any((node) => node.hasFocus) &&
        !_opcaoExtraFloat2FocusNodes.values.any((node) => node.hasFocus)) {
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
    
    final currentFormaPagamento = _formaPagamentoCtrl.text.trim();
    if (currentFormaPagamento != _initialFormaPagamento) return true;
    
    final currentCondicao = _selectedCondicaoPagamento == 'OUTROS' 
        ? _condicoesPagamentoOutrasCtrl.text.trim() 
        : _condicoesPagamentoCtrl.text.trim();
    if (currentCondicao != _initialCondicoesPagamento) return true;
    
    if (_prazoEntregaCtrl.text.trim() != _initialPrazoEntrega) return true;
    if (_despesasAdicionais != _initialDespesasAdicionais) return true;
    if (_selectedProduto?.id != _initialSelectedProdutoId) return true;
    
    if (_despesaDescControllers.length != _initialDespesasDesc.length) return true;
    for (int i = 0; i < _despesaDescControllers.length; i++) {
      if (i >= _initialDespesasDesc.length) return true;
      if (_despesaDescControllers[i].text != _initialDespesasDesc[i]) return true;
      if (_despesaValorControllers[i].text != _initialDespesasValor[i]) return true;
    }
    
    for (final entry in _quantityControllers.entries) {
      final initialQty = _initialQuantityStrings[entry.key] ?? '';
      if (entry.value.text != initialQty) return true;
    }
    
    for (final key in {..._opcoesExtrasEnabled.keys, ..._initialOpcoesExtrasEnabled.keys}) {
      final initialEnabled = _initialOpcoesExtrasEnabled[key];
      final currentEnabled = _opcoesExtrasEnabled[key];
      if (currentEnabled != initialEnabled) return true;
    }
    
    for (final entry in _opcaoExtraStringControllers.entries) {
      if (_opcoesExtrasEnabled[entry.key] == true) {
        final initial = _initialOpcaoExtraStringValues[entry.key] ?? '';
        if (entry.value.text != initial) return true;
      }
    }
    for (final entry in _opcaoExtraFloat1Controllers.entries) {
      if (_opcoesExtrasEnabled[entry.key] == true) {
        final initial = _initialOpcaoExtraFloat1Values[entry.key] ?? '';
        if (entry.value.text != initial) return true;
      }
    }
    for (final entry in _opcaoExtraFloat2Controllers.entries) {
      if (_opcoesExtrasEnabled[entry.key] == true) {
        final initial = _initialOpcaoExtraFloat2Values[entry.key] ?? '';
        if (entry.value.text != initial) return true;
      }
    }
    
    if (_informacoesAdicionais.length != _initialInformacoesAdicionais.length) return true;
    for (int i = 0; i < _informacoesAdicionais.length; i++) {
      if (i >= _initialInformacoesAdicionais.length) return true;
      final current = _informacoesAdicionais[i];
      final initial = _initialInformacoesAdicionais[i];
      if (current.data != initial.data || current.descricao != initial.descricao) return true;
    }
    
    return false;
  }

  Future<void> _loadFaixas() async {
    try {
      final faixas = await _faixasApi.listar();
      if (!mounted) return;
      setState(() {
        _faixas = faixas;
        _faixasCarregadas = true;
      });
      _tentarRecalcularValorInicial();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _faixasCarregadas = true;
      });
    }
  }

  Future<void> _loadProdutos() async {
    try {
      final produtos = await _api.fetchProdutos();
      if (!mounted) return;
      setState(() {
        _produtos = produtos..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
        _loading = false;
        _produtosCarregados = true;
        if (widget.initial != null) {
          _selectedProduto = produtos.firstWhere(
            (p) => p.id == widget.initial!.produtoId,
            orElse: () => produtos.first,
          );
          _initializeQuantityControllers();
        }
      });
      _tentarRecalcularValorInicial();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _produtosCarregados = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar produtos: $e')),
      );
    }
  }

  void _tentarRecalcularValorInicial() {
    if (_faixasCarregadas && _produtosCarregados && _selectedProduto != null) {
      _recalcularValorSugerido();
    }
  }

  void _initializeQuantityControllers() {
    if (_selectedProduto == null) return;
    
    for (final controller in _opcaoExtraStringControllers.values) {
      controller.dispose();
    }
    for (final controller in _opcaoExtraFloat1Controllers.values) {
      controller.dispose();
    }
    for (final controller in _opcaoExtraFloat2Controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _opcaoExtraStringFocusNodes.values) {
      focusNode.dispose();
    }
    for (final focusNode in _opcaoExtraFloat1FocusNodes.values) {
      focusNode.dispose();
    }
    for (final focusNode in _opcaoExtraFloat2FocusNodes.values) {
      focusNode.dispose();
    }
    
    _opcaoExtraStringControllers.clear();
    _opcaoExtraFloat1Controllers.clear();
    _opcaoExtraFloat2Controllers.clear();
    _opcaoExtraStringFocusNodes.clear();
    _opcaoExtraFloat1FocusNodes.clear();
    _opcaoExtraFloat2FocusNodes.clear();
    _opcoesExtrasEnabled.clear();
    
    for (final mat in _selectedProduto!.materiais) {
      final existingQty = widget.initial?.materiais
          .firstWhere((m) => m.materialId == mat.materialId,
              orElse: () => const OrcamentoMaterialItem(
                  id: 0,
                  materialId: 0,
                  materialNome: '',
                  materialUnidade: '',
                  materialCusto: 0,
                  quantidade: 0))
          .quantidade ?? 0;
      
      final controller = TextEditingController(
        text: existingQty > 0 ? _formatQuantity(existingQty) : ''
      );
      final focusNode = FocusNode();
      
      controller.addListener(_updateTotal);
      focusNode.addListener(_onFieldFocusChange);
      
      _quantityControllers[mat.materialId] = controller;
      _quantityFocusNodes[mat.materialId] = focusNode;
    }
    
    for (final opcao in _selectedProduto!.opcoesExtras) {
      final existingOpcao = widget.initial?.opcoesExtras.firstWhere(
        (o) => o.produtoOpcaoId == opcao.id,
        orElse: () => const OrcamentoOpcaoExtraItem(
          id: 0,
          produtoOpcaoId: 0,
          nome: '',
          tipo: TipoOpcaoExtra.stringFloat,
          valorString: null,
          valorFloat1: null,
          valorFloat2: null,
        ),
      );
      
      if (existingOpcao != null && existingOpcao.id != 0) {
        final hasValues = existingOpcao.valorString != null || 
                         existingOpcao.valorFloat1 != null || 
                         existingOpcao.valorFloat2 != null;
        
        _opcoesExtrasEnabled[opcao.id] = hasValues;
        
        if (hasValues) {
          final stringCtrl = TextEditingController(text: existingOpcao.valorString ?? '');
          
          final float1Ctrl = TextEditingController(
            text: existingOpcao.valorFloat1 != null 
                ? _formatQuantity(existingOpcao.valorFloat1!) 
                : ''
          );
          final float2Ctrl = TextEditingController(
            text: existingOpcao.valorFloat2 != null 
                ? _formatQuantity(existingOpcao.valorFloat2!) 
                : ''
          );
          
          final stringFocus = FocusNode();
          final float1Focus = FocusNode();
          final float2Focus = FocusNode();
          
          stringCtrl.addListener(_updateTotal);
          float1Ctrl.addListener(_updateTotal);
          float2Ctrl.addListener(_updateTotal);
          stringFocus.addListener(_onFieldFocusChange);
          float1Focus.addListener(_onFieldFocusChange);
          float2Focus.addListener(_onFieldFocusChange);
          
          _opcaoExtraStringControllers[opcao.id] = stringCtrl;
          _opcaoExtraFloat1Controllers[opcao.id] = float1Ctrl;
          _opcaoExtraFloat2Controllers[opcao.id] = float2Ctrl;
          _opcaoExtraStringFocusNodes[opcao.id] = stringFocus;
          _opcaoExtraFloat1FocusNodes[opcao.id] = float1Focus;
          _opcaoExtraFloat2FocusNodes[opcao.id] = float2Focus;
        }
      }
    }
  }

  @override
  void dispose() {
    _clienteCtrl.dispose();
    _numeroCtrl.dispose();
    _formaPagamentoCtrl.dispose();
    _condicoesPagamentoCtrl.dispose();
    _condicoesPagamentoOutrasCtrl.dispose();
    _prazoEntregaCtrl.dispose();
    _produtoSearchCtrl.dispose();
    
    _dialogFocusNode.dispose();
    _clienteFocusNode.dispose();
    _numeroFocusNode.dispose();
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
    
    for (final controller in _opcaoExtraStringControllers.values) {
      controller.dispose();
    }
    for (final controller in _opcaoExtraFloat1Controllers.values) {
      controller.dispose();
    }
    for (final controller in _opcaoExtraFloat2Controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _opcaoExtraStringFocusNodes.values) {
      focusNode.dispose();
    }
    for (final focusNode in _opcaoExtraFloat1FocusNodes.values) {
      focusNode.dispose();
    }
    for (final focusNode in _opcaoExtraFloat2FocusNodes.values) {
      focusNode.dispose();
    }
    
    super.dispose();
  }

  double _calcularBasePercentual() {
    if (_selectedProduto == null) return 0.0;

    double base = 0.0;

    for (final mat in _selectedProduto!.materiais) {
      final controller = _quantityControllers[mat.materialId];
      if (controller != null) {
        final qty = double.tryParse(controller.text.replaceAll(',', '.')) ?? 0.0;
        base += mat.materialCusto * qty;
      }
    }

    for (final valorCtrl in _despesaValorControllers) {
      final valor = double.tryParse(valorCtrl.text.replaceAll(',', '.')) ?? 0.0;
      base += valor;
    }

    for (final opcao in _selectedProduto!.opcoesExtras) {
      final isEnabled = _opcoesExtrasEnabled[opcao.id] ?? false;
      if (!isEnabled) continue;

      if (opcao.tipo == TipoOpcaoExtra.stringFloat) {
        final float1Ctrl = _opcaoExtraFloat1Controllers[opcao.id];
        if (float1Ctrl != null) {
          base += double.tryParse(float1Ctrl.text.replaceAll(',', '.')) ?? 0.0;
        }
      } else if (opcao.tipo == TipoOpcaoExtra.floatFloat) {
        final float1Ctrl = _opcaoExtraFloat1Controllers[opcao.id];
        final float2Ctrl = _opcaoExtraFloat2Controllers[opcao.id];
        if (float1Ctrl != null && float2Ctrl != null) {
          final horas = double.tryParse(float1Ctrl.text.replaceAll(',', '.')) ?? 0.0;
          final valorHora = double.tryParse(float2Ctrl.text.replaceAll(',', '.')) ?? 0.0;
          base += horas * valorHora;
        }
      }
    }

    return base;
  }

  double _calculateTotal() {
    if (_selectedProduto == null) return 0.0;

    final basePercentual = _calcularBasePercentual();

    double totalPercentuais = 0.0;
    for (final opcao in _selectedProduto!.opcoesExtras) {
      final isEnabled = _opcoesExtrasEnabled[opcao.id] ?? false;
      if (!isEnabled || opcao.tipo != TipoOpcaoExtra.percentFloat) continue;

      final float1Ctrl = _opcaoExtraFloat1Controllers[opcao.id];
      if (float1Ctrl != null) {
        final percentual = double.tryParse(float1Ctrl.text.replaceAll(',', '.')) ?? 0.0;
        totalPercentuais += (percentual / 100.0) * basePercentual;
      }
    }

    return basePercentual + totalPercentuais;
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

  Future<void> _adicionarInformacaoAdicional() async {
    final descricaoController = TextEditingController();
    final theme = Theme.of(context);

    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adicionar Informação Adicional'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: TextField(
            controller: descricaoController,
            decoration: const InputDecoration(
              labelText: 'Descrição',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            onPressed: () {
              if (descricaoController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Digite uma descrição'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );

    if (resultado == true) {
      final now = DateTime.now();
      setState(() {
        _informacoesAdicionais.add(
          InformacaoAdicionalItem(
            id: DateTime.now().millisecondsSinceEpoch,
            data: now,
            descricao: descricaoController.text.trim(),
            createdAt: now,
            updatedAt: now,
          ),
        );
      });
    }
  }

  void _removerInformacaoAdicional(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text(
          'Deseja realmente remover esta informação adicional?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _informacoesAdicionais.removeAt(index);
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  Widget _buildInformacoesAdicionaisSection() {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Informações Adicionais',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: _isAprovado 
                          ? theme.colorScheme.onSurface 
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  if (_isAprovado)
                    ExcludeFocus(
                      child: IconButton(
                        onPressed: _adicionarInformacaoAdicional,
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        tooltip: 'Adicionar informação',
                        style: IconButton.styleFrom(
                          foregroundColor: theme.colorScheme.primary,
                          padding: EdgeInsets.zero,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_informacoesAdicionais.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
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
                          _isAprovado
                              ? 'Clique no + para adicionar informações'
                              : 'Nenhuma informação adicional registrada',
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
                ...List.generate(_informacoesAdicionais.length, (index) {
                  final info = _informacoesAdicionais[index];
                  return ClickableInk(
                    onTap: _isAprovado ? () => _editarInformacaoAdicional(index) : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.event_note,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  info.descricao,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                ),
                                if (info.createdAt != null || info.updatedAt != null) ...[
                                  const SizedBox(height: 6),
                                  if (info.createdAt != null)
                                    Text(
                                      'Criado em ${_formatarData(info.createdAt!)}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontSize: 10,
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  if (info.updatedAt != null && 
                                      info.createdAt != null &&
                                      info.updatedAt!.difference(info.createdAt!).inSeconds > 1)
                                    Text(
                                      'Atualizado em ${_formatarData(info.updatedAt!)}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontSize: 10,
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ),
                          if (_isAprovado) ...[
                            const SizedBox(width: 6),
                            ExcludeFocus(
                              child: IconButton(
                                onPressed: () => _removerInformacaoAdicional(index),
                                icon: const Icon(Icons.delete_outline, size: 16),
                                color: theme.colorScheme.error,
                                tooltip: 'Remover',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editarInformacaoAdicional(int index) async {
    final info = _informacoesAdicionais[index];
    final descricaoController = TextEditingController(text: info.descricao);
    final theme = Theme.of(context);

    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Informação Adicional'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: TextField(
            controller: descricaoController,
            decoration: const InputDecoration(
              labelText: 'Descrição',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            onPressed: () {
              if (descricaoController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Digite uma descrição'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (resultado == true) {
      final now = DateTime.now();
      setState(() {
        _informacoesAdicionais[index] = InformacaoAdicionalItem(
          id: info.id,
          data: info.data,
          descricao: descricaoController.text.trim(),
          createdAt: info.createdAt ?? info.data,
          updatedAt: now,
        );
      });
    }
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
  if (_isAprovado) {
    final item = widget.initial!.copyWith(
      informacoesAdicionais: _informacoesAdicionais,
    );
    
    Navigator.of(context).pop(item);
    return;
  }
  
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
                      quantidade: 0))
              .id ??
          0,
      materialId: mat.materialId,
      materialNome: mat.materialNome,
      materialUnidade: mat.materialUnidade,
      materialCusto: mat.materialCusto,
      quantidade: qtyValue,
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

  final opcoesExtras = <OrcamentoOpcaoExtraItem>[];
  for (final opcao in _selectedProduto!.opcoesExtras) {
    final isEnabled = _opcoesExtrasEnabled[opcao.id];
    
    final existingId = widget.initial?.opcoesExtras
        .firstWhere(
          (o) => o.produtoOpcaoId == opcao.id,
          orElse: () => const OrcamentoOpcaoExtraItem(
            id: 0,
            produtoOpcaoId: 0,
            nome: '',
            tipo: TipoOpcaoExtra.stringFloat,
            valorString: null,
            valorFloat1: null,
            valorFloat2: null,
          ),
        )
        .id ?? 0;
    
    if (isEnabled == false) {
      opcoesExtras.add(OrcamentoOpcaoExtraItem(
        id: existingId,
        produtoOpcaoId: opcao.id,
        nome: opcao.nome,
        tipo: opcao.tipo,
        valorString: null,
        valorFloat1: null,
        valorFloat2: null,
      ));
      continue;
    }
    
    if (isEnabled == null) continue;
    
    final stringCtrl = _opcaoExtraStringControllers[opcao.id];
    final float1Ctrl = _opcaoExtraFloat1Controllers[opcao.id];
    final float2Ctrl = _opcaoExtraFloat2Controllers[opcao.id];
    
    String? valorString;
    double? valorFloat1;
    double? valorFloat2;
    
    if (opcao.tipo == TipoOpcaoExtra.stringFloat) {
      valorString = stringCtrl?.text.trim();
      final float1Text = float1Ctrl?.text.trim() ?? '';
      if (float1Text.isNotEmpty) {
        valorFloat1 = double.tryParse(float1Text.replaceAll(',', '.'));
      }
    } else if (opcao.tipo == TipoOpcaoExtra.floatFloat) {
      final float1Text = float1Ctrl?.text.trim() ?? '';
      final float2Text = float2Ctrl?.text.trim() ?? '';
      
      if (float1Text.isNotEmpty) {
        valorFloat1 = double.tryParse(float1Text.replaceAll(',', '.'));
      }
      if (float2Text.isNotEmpty) {
        valorFloat2 = double.tryParse(float2Text.replaceAll(',', '.'));
      }
    } else if (opcao.tipo == TipoOpcaoExtra.percentFloat) {
      final float1Text = float1Ctrl?.text.trim() ?? '';
      
      if (float1Text.isNotEmpty) {
        valorFloat1 = double.tryParse(float1Text.replaceAll(',', '.'));
      }
    }
    
    opcoesExtras.add(OrcamentoOpcaoExtraItem(
      id: existingId,
      produtoOpcaoId: opcao.id,
      nome: opcao.nome,
      tipo: opcao.tipo,
      valorString: valorString,
      valorFloat1: valorFloat1,
      valorFloat2: valorFloat2,
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
    opcoesExtras: opcoesExtras,
    informacoesAdicionais: _informacoesAdicionais,
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

  Widget _buildOpcoesExtrasSection() {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');

    if (_selectedProduto == null || _selectedProduto!.opcoesExtras.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Outros',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600, 
            fontSize: 12,
            color: _isAprovado 
                ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                : theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        ..._selectedProduto!.opcoesExtras.map((opcao) {
          final isEnabled = _opcoesExtrasEnabled[opcao.id];
          
          final avisosDaOpcao = _selectedProduto!.avisos
              .where((aviso) => aviso.opcaoExtraId == opcao.id)
              .toList();
          
          final temAviso = avisosDaOpcao.isNotEmpty;
          
          return FormField<bool>(
            initialValue: isEnabled,
            validator: (value) {
              if (value == null) {
                return 'Selecione Sim ou Não';
              }
              return null;
            },
            builder: (formFieldState) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: formFieldState.hasError
                        ? theme.colorScheme.error
                        : isEnabled == true
                            ? theme.colorScheme.primary.withValues(alpha: 0.3)
                            : theme.dividerColor.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
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
                        const SizedBox(width: 10),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      opcao.nome,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        color: _isAprovado 
                                            ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                                            : theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (temAviso) ...[
                                const SizedBox(width: 6),
                                Transform.translate(
                                  offset: const Offset(-10, 0),
                                  child: Tooltip(
                                    message: avisosDaOpcao.map((a) => a.mensagem).join('\n'),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.secondary,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    textStyle: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.surface,
                                      fontSize: 11,
                                    ),
                                    preferBelow: false,
                                    verticalOffset: 20,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Icon(
                                      Icons.info_outline,
                                      size: 16,
                                      color: theme.colorScheme.secondary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            _buildToggleButton('Não', isEnabled == false, () {
                              if (_isAprovado) return;
                              setState(() {
                                _opcoesExtrasEnabled[opcao.id] = false;
                                _opcaoExtraStringControllers[opcao.id]?.clear();
                                _opcaoExtraFloat1Controllers[opcao.id]?.clear();
                                _opcaoExtraFloat2Controllers[opcao.id]?.clear();
                              });
                              formFieldState.didChange(false);
                            }),
                            const SizedBox(width: 6),
                            _buildToggleButton('Sim', isEnabled == true, () {
                              if (_isAprovado) return;
                              setState(() {
                                _opcoesExtrasEnabled[opcao.id] = true;
                                
                                if (!_opcaoExtraStringControllers.containsKey(opcao.id)) {
                                  final stringCtrl = TextEditingController();
                                  final float1Ctrl = TextEditingController();
                                  final float2Ctrl = TextEditingController();
                                  final stringFocus = FocusNode();
                                  final float1Focus = FocusNode();
                                  final float2Focus = FocusNode();
                                  
                                  stringCtrl.addListener(_updateTotal);
                                  float1Ctrl.addListener(_updateTotal);
                                  float2Ctrl.addListener(_updateTotal);
                                  stringFocus.addListener(_onFieldFocusChange);
                                  float1Focus.addListener(_onFieldFocusChange);
                                  float2Focus.addListener(_onFieldFocusChange);
                                  
                                  _opcaoExtraStringControllers[opcao.id] = stringCtrl;
                                  _opcaoExtraFloat1Controllers[opcao.id] = float1Ctrl;
                                  _opcaoExtraFloat2Controllers[opcao.id] = float2Ctrl;
                                  _opcaoExtraStringFocusNodes[opcao.id] = stringFocus;
                                  _opcaoExtraFloat1FocusNodes[opcao.id] = float1Focus;
                                  _opcaoExtraFloat2FocusNodes[opcao.id] = float2Focus;
                                }
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
                    if (isEnabled == true) ...[
                      const SizedBox(height: 10),
                      if (opcao.tipo == TipoOpcaoExtra.stringFloat) ...[
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _opcaoExtraStringControllers[opcao.id],
                                focusNode: _opcaoExtraStringFocusNodes[opcao.id],
                                enabled: !_isAprovado,
                                style: const TextStyle(fontSize: 12),
                                decoration: const InputDecoration(
                                  labelText: 'Descrição',
                                  helperStyle: TextStyle(fontSize: 10),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) 
                                    ? 'Informe a descrição' 
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _opcaoExtraFloat1Controllers[opcao.id],
                                focusNode: _opcaoExtraFloat1FocusNodes[opcao.id],
                                enabled: !_isAprovado,
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
                                    return 'Informe o valor';
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
                        ),
                      ] else if (opcao.tipo == TipoOpcaoExtra.floatFloat) ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _opcaoExtraFloat1Controllers[opcao.id],
                                focusNode: _opcaoExtraFloat1FocusNodes[opcao.id],
                                enabled: !_isAprovado,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                                ],
                                style: const TextStyle(fontSize: 12),
                                decoration: const InputDecoration(
                                  labelText: 'Tempo',
                                  helperStyle: TextStyle(fontSize: 10),
                                  isDense: true,
                                  suffixText: 'h',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Informe o tempo';
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
                                controller: _opcaoExtraFloat2Controllers[opcao.id],
                                focusNode: _opcaoExtraFloat2FocusNodes[opcao.id],
                                enabled: !_isAprovado,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                                ],
                                style: const TextStyle(fontSize: 12),
                                decoration: const InputDecoration(
                                  labelText: 'Valor/Hora',
                                  helperStyle: TextStyle(fontSize: 10),
                                  isDense: true,
                                  prefixText: 'R\$ ',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Informe o valor/h';
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
                        ),
                      ] else if (opcao.tipo == TipoOpcaoExtra.percentFloat) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _opcaoExtraFloat1Controllers[opcao.id],
                              focusNode: _opcaoExtraFloat1FocusNodes[opcao.id],
                              enabled: !_isAprovado,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                              ],
                              style: const TextStyle(fontSize: 12),
                              decoration: const InputDecoration(
                                labelText: 'Percentual',
                                helperStyle: TextStyle(fontSize: 10),
                                isDense: true,
                                suffixText: '%',
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Informe o %';
                                }
                                final value = double.tryParse(v.replaceAll(',', '.'));
                                if (value == null || value < 0 || value > 100) {
                                  return 'Entre 0-100';
                                }
                                return null;
                              },
                            ),
                            
                            const SizedBox(height: 10),
                            
                            Builder(
                              builder: (context) {
                                final totalBase = _calcularBasePercentual();

                                final percentualCtrl = _opcaoExtraFloat1Controllers[opcao.id];
                                final percentual = percentualCtrl != null
                                    ? (double.tryParse(percentualCtrl.text.replaceAll(',', '.')) ?? 0.0)
                                    : 0.0;

                                final valorCalculado = (percentual / 100.0) * totalBase;
                                
                                return Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            size: 14,
                                            color: theme.colorScheme.primary.withValues(alpha: 0.7),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Valor total do orçamento:',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              fontSize: 10,
                                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        currency.format(totalBase),
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Valor da opção:',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              fontSize: 10,
                                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                            ),
                                          ),
                                          Text(
                                            currency.format(valorCalculado),
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              );
            },
          );
        }),
      ],
    );
  }

  Widget _buildDespesasSection() {
  final theme = Theme.of(context);
  
  return FormField<bool>(
    initialValue: _despesasAdicionais,
    validator: (value) {
      if (value == null) {
        return 'Selecione Sim ou Não';
      }
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
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600, 
                          fontSize: 12,
                          color: _isAprovado 
                              ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        _buildToggleButton('Não', _despesasAdicionais == false, () {
                          if (_isAprovado) return;
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
                          if (_isAprovado) return;
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
                      if (!_isAprovado)
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
                              _isAprovado 
                                  ? 'Nenhuma despesa adicional' 
                                  : 'Clique no + para adicionar despesas',
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
                                enabled: !_isAprovado,
                                style: const TextStyle(fontSize: 12),
                                decoration: const InputDecoration(
                                  labelText: 'Descrição',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a descrição' : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _despesaValorControllers[index],
                                focusNode: _despesaValorFocusNodes[index],
                                enabled: !_isAprovado,
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
                                    return 'Informe o valor';
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
                            if (!_isAprovado)
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
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: _isAprovado 
                                              ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                                              : theme.colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: _produtoSearchCtrl,
                                        focusNode: _produtoSearchFocusNode,
                                        enabled: !_isAprovado,
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
                                                child: ClickableInk(
                                                  onTap: _isAprovado ? null : () {
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
                                                      _recalcularValorSugerido();
                                                    });
                                                  },
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(10),
                                                    decoration: BoxDecoration(
                                                      color: isSelected
                                                          ? (_isAprovado 
                                                              ? theme.colorScheme.primary.withValues(alpha: 0.08)
                                                              : theme.colorScheme.primary.withValues(alpha: 0.15))
                                                          : (_isAprovado 
                                                              ? theme.colorScheme.surface.withValues(alpha: 0.5)
                                                              : theme.colorScheme.surface),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: isSelected
                                                            ? (_isAprovado 
                                                                ? theme.colorScheme.primary.withValues(alpha: 0.3)
                                                                : theme.colorScheme.primary.withValues(alpha: 0.5))
                                                            : (_isAprovado 
                                                                ? theme.dividerColor.withValues(alpha: 0.05)
                                                                : theme.dividerColor.withValues(alpha: 0.1)),
                                                        width: isSelected ? 2 : 1,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.all(6),
                                                          decoration: BoxDecoration(
                                                            color: isSelected
                                                                ? (_isAprovado 
                                                                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                                                                    : theme.colorScheme.primary.withValues(alpha: 0.2))
                                                                : (_isAprovado 
                                                                    ? theme.colorScheme.primary.withValues(alpha: 0.05)
                                                                    : theme.colorScheme.primary.withValues(alpha: 0.1)),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Icon(
                                                            Icons.inventory_2_outlined,
                                                            color: _isAprovado 
                                                                ? theme.colorScheme.primary.withValues(alpha: 0.4)
                                                                : theme.colorScheme.primary,
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
                                                                  color: _isAprovado 
                                                                      ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                                                                      : theme.colorScheme.onSurface,
                                                                ),
                                                                maxLines: 2,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                              Text(
                                                                '${produto.materiais.length} materiais',
                                                                style: theme.textTheme.bodySmall?.copyWith(
                                                                  color: _isAprovado 
                                                                      ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                                                                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
                                                  enabled: !_isAprovado,
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
                                                  enabled: !_isAprovado,
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
                                            Row(
                                              children: [
                                                Expanded(
                                                  flex: 2,
                                                  child: Padding(
                                                    padding: const EdgeInsets.only(left: 0),
                                                    child: Text(
                                                      'Materiais',
                                                      style: theme.textTheme.titleSmall?.copyWith(
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 12,
                                                        color: _isAprovado 
                                                            ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                                                            : theme.colorScheme.onSurface,
                                                      ),
                                                    ),
                                                  ),
                                                ),

                                                SizedBox(
                                                  width: 90,
                                                  child: Padding(
                                                    padding: const EdgeInsets.only(right: 15),
                                                    child: Text(
                                                      'Quantidade',
                                                      textAlign: TextAlign.center,
                                                      style: theme.textTheme.titleSmall?.copyWith(
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 12,
                                                        color: _isAprovado 
                                                            ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                                                            : theme.colorScheme.onSurface,
                                                      ),
                                                    ),
                                                  ),
                                                ),

                                                SizedBox(
                                                  width: 75,
                                                  child: Padding(
                                                    padding: const EdgeInsets.only(right: 15),
                                                    child: Text(
                                                      'Total',
                                                      textAlign: TextAlign.right,
                                                      style: theme.textTheme.titleSmall?.copyWith(
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 12,
                                                        color: _isAprovado 
                                                            ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                                                            : theme.colorScheme.onSurface,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
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
                                                      child: Builder(
                                                        builder: (context) {
                                                          final avisosDoMaterial = _selectedProduto!.avisos
                                                              .where((aviso) => aviso.materialId == mat.materialId)
                                                              .toList();
                                                          
                                                          final temAviso = avisosDoMaterial.isNotEmpty;
                                                          
                                                          return Row(
                                                            children: [
                                                              Expanded(
                                                                child: Column(
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                    Text(
                                                                      mat.materialNome,
                                                                      style: theme.textTheme.bodySmall?.copyWith(
                                                                        fontWeight: FontWeight.w600,
                                                                        fontSize: 11,
                                                                        color: _isAprovado 
                                                                            ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                                                                            : theme.colorScheme.onSurface,
                                                                      ),
                                                                    ),
                                                                    Text(
                                                                      '${currency.format(mat.materialCusto)} / ${mat.materialUnidade}',
                                                                      style: theme.textTheme.bodySmall?.copyWith(
                                                                        fontSize: 10,
                                                                        color: _isAprovado 
                                                                            ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                                                                            : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              if (temAviso) ...[
                                                                const SizedBox(width: 6),
                                                                Tooltip(
                                                                  message: avisosDoMaterial.map((a) => a.mensagem).join('\n'),
                                                                  decoration: BoxDecoration(
                                                                    color: theme.colorScheme.secondary,
                                                                    borderRadius: BorderRadius.circular(8),
                                                                  ),
                                                                  textStyle: theme.textTheme.bodySmall?.copyWith(
                                                                    color: theme.colorScheme.surface,
                                                                    fontSize: 11,
                                                                  ),
                                                                  preferBelow: false,
                                                                  verticalOffset: 20,
                                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                                  child: Icon(
                                                                    Icons.info_outline,
                                                                    size: 16,
                                                                    color: theme.colorScheme.secondary,
                                                                  ),
                                                                ),
                                                              ],
                                                            ],
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    SizedBox(
                                                      width: 70,
                                                      child: TextFormField(
                                                        controller: controller,
                                                        focusNode: focusNode,
                                                        enabled: !_isAprovado,
                                                        keyboardType: TextInputType.numberWithOptions(
                                                          decimal: mat.materialUnidade == 'Kg',
                                                        ),
                                                        inputFormatters: [
                                                          FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
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
                                                          color: _isAprovado 
                                                              ? theme.colorScheme.primary.withValues(alpha: 0.4)
                                                              : theme.colorScheme.primary,
                                                          fontSize: 11,
                                                        ),
                                                        textAlign: TextAlign.right,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }),
                                        
                                            const SizedBox(height: 16),

                                            _buildDespesasSection(),
                                            _buildOpcoesExtrasSection(),
 
                                            const SizedBox(height: 16),
                                            
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: DropdownButtonFormField<String>(
                                                    initialValue: _selectedFormaPagamento,
                                                    focusNode: _formaPagamentoFocusNode,
                                                    decoration: InputDecoration(
                                                      labelText: 'Forma de Pagamento',
                                                      labelStyle: _isAprovado 
                                                          ? TextStyle(
                                                              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                                            )
                                                          : null,
                                                      isDense: true,
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 13, 
                                                      color: _isAprovado 
                                                          ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                                                          : theme.colorScheme.onSurface,
                                                    ),
                                                    items: _formaPagamentoOptions.map((option) {
                                                      return DropdownMenuItem<String>(
                                                        value: option,
                                                        enabled: !_isAprovado,
                                                        child: Text(option),
                                                      );
                                                    }).toList(),
                                                    onChanged: _isAprovado ? null : (value) {
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
                                                        decoration: InputDecoration(
                                                          labelText: 'Condições de Pagamento',
                                                          labelStyle: _isAprovado 
                                                              ? TextStyle(
                                                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                                                )
                                                              : null,
                                                          isDense: true,
                                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                        ),
                                                        style: TextStyle(
                                                          fontSize: 13, 
                                                          color: _isAprovado 
                                                              ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                                                              : theme.colorScheme.onSurface,
                                                        ),
                                                        items: _condicoesPagamentoOptions.map((option) {
                                                          return DropdownMenuItem<String>(
                                                            value: option,
                                                            enabled: !_isAprovado,
                                                            child: Text(option),
                                                          );
                                                        }).toList(),
                                                        onChanged: _isAprovado ? null : (value) {
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
                                                          enabled: !_isAprovado,
                                                          style: const TextStyle(fontSize: 13),
                                                          decoration: const InputDecoration(
                                                            labelText: 'Especifique as condições',
                                                            isDense: true,
                                                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                              enabled: !_isAprovado,
                                              style: const TextStyle(fontSize: 13),
                                              decoration: const InputDecoration(
                                                labelText: 'Prazo de Entrega',
                                                isDense: true,
                                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                              ),
                                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o prazo' : null,
                                            ),
                                            
                                            _buildInformacoesAdicionaisSection(),
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
                                        if (_valorSugeridoLocal != null) ...[
                                          const SizedBox(height: 12),
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Icon(
                                                    Icons.lightbulb_outline,
                                                    size: 18,
                                                    color: theme.colorScheme.primary,
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Valor sugerido para venda',
                                                        style: theme.textTheme.bodySmall?.copyWith(
                                                          fontWeight: FontWeight.w600,
                                                          color: theme.colorScheme.primary,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                      Text(
                                                        'Margem de ${_valorSugeridoLocal!['margem']}% aplicada',
                                                        style: theme.textTheme.bodySmall?.copyWith(
                                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Text(
                                                  currency.format(_valorSugeridoLocal!['valorSugerido']),
                                                  style: theme.textTheme.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: theme.colorScheme.primary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
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
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: theme.colorScheme.primary,
                                                    foregroundColor: theme.colorScheme.onPrimary,
                                                  ),
                                                  onPressed: _save,
                                                  child: Text(
                                                    _isAprovado 
                                                        ? 'Salvar' 
                                                        : (widget.initial == null ? 'Finalizar' : 'Salvar')
                                                  ),
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

  Widget _buildToggleButton(String label, bool selected, VoidCallback onTap) {
    final theme = Theme.of(context);
    
    return ExcludeFocus(
      child: ClickableInk(
        onTap: _isAprovado ? null : onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: selected 
                ? (_isAprovado 
                    ? theme.colorScheme.primary.withValues(alpha: 0.3)
                    : theme.colorScheme.primary)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected 
                  ? (_isAprovado 
                      ? theme.colorScheme.primary.withValues(alpha: 0.3)
                      : theme.colorScheme.primary)
                  : theme.dividerColor.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: selected 
                  ? (_isAprovado 
                      ? theme.colorScheme.primary.withValues(alpha: 0.5)
                      : theme.colorScheme.onPrimary)
                  : (_isAprovado 
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                      : theme.colorScheme.onSurface),
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}