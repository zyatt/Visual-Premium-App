import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visualpremium/data/orcamentos_repository.dart';
import 'package:visualpremium/models/orcamento_item.dart' hide TipoOpcaoExtra;
import 'package:visualpremium/models/pedido_item.dart';
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

class PedidoFilters {
  final Set<String> status;
  final Set<int> produtoIds;
  final Set<String> clientes;
  final DateTimeRange? dateRange;

  const PedidoFilters({
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

  PedidoFilters copyWith({
    Set<String>? status,
    Set<int>? produtoIds,
    Set<String>? clientes,
    DateTimeRange? dateRange,
    bool clearDateRange = false,
  }) {
    return PedidoFilters(
      status: status ?? this.status,
      produtoIds: produtoIds ?? this.produtoIds,
      clientes: clientes ?? this.clientes,
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
    );
  }

  PedidoFilters clear() {
    return const PedidoFilters();
  }
}
class PedidosPage extends StatefulWidget {
  const PedidosPage({super.key});

  @override
  State<PedidosPage> createState() => _PedidosPageState();
}

class _PedidosPageState extends State<PedidosPage> {
  final _api = OrcamentosApiRepository();
  final _scrollController = ScrollController();
  bool _loading = true;
  List<PedidoItem> _items = const [];
  List<ProdutoItem> _allProdutos = [];
  String _searchQuery = '';
  int? _downloadingId;
  SortOption _sortOption = SortOption.newestFirst;
  PedidoFilters _filters = const PedidoFilters();
  bool _showScrollToTopButton = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadProdutos();
    
    // ✅ ADICIONAR listener
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
    _scrollController.dispose();  // ✅ ADICIONAR
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
      final items = await _api.fetchPedidos();
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
          SnackBar(content: Text('Erro ao carregar pedidos: $e')),
        );
      });
    }
  }

  Future<void> _upsert(PedidoItem item) async {
    setState(() => _loading = true);
    try {
      final updated = await _api.updatePedido(item);
      final idx = _items.indexWhere((e) => e.id == updated.id);
      final next = [..._items];
      if (idx != -1) {
        next[idx] = updated;
      }
      if (!mounted) return;
      setState(() {
        _items = next;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido salvo com sucesso'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar pedido: $e')),
        );
      });
    }
  }

  Future<void> _updateStatus(PedidoItem item, String newStatus) async {
    setState(() => _loading = true);
    try {
      final updated = await _api.updatePedidoStatus(item.id, newStatus);
      final idx = _items.indexWhere((e) => e.id == updated.id);
      if (idx != -1) {
        final next = [..._items];
        next[idx] = updated;
        if (!mounted) return;
        setState(() {
          _items = next;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar status: $e')),
        );
      });
    }
  }

  Future<void> _delete(PedidoItem item) async {
    setState(() => _loading = true);
    try {
      await _api.deletePedido(item.id);
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
          SnackBar(content: Text('Erro ao deletar pedido: $e')),
        );
      });
    }
  }

  Future<void> _downloadPdf(PedidoItem item) async {
    setState(() => _downloadingId = item.id);
    try {
      final directory = await getDownloadsDirectory() ?? 
                        await getApplicationDocumentsDirectory();
      final fileName = 'pedido_${item.numero ?? "sem_numero"}_${item.cliente.replaceAll(' ', '_')}.pdf';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      
      if (await file.exists()) {
        await file.delete();
      }
      
      final pdfBytes = await _api.downloadPedidoPdf(item.id);
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

  Future<bool?> _showConfirmDelete(String cliente, int? numero) {
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
                    Text('Excluir pedido?', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                      'Você tem certeza que deseja excluir o pedido ${numero != null ? "#$numero" : "(sem número)"} de $cliente?',
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
  
  Future<void> _showPedidoEditor(PedidoItem initial) async {
    final result = await showDialog<PedidoItem>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PedidoEditorSheet(
          initial: initial,
          existingPedidos: _items,
        );
      },
    );

    if (result != null) {
      await _upsert(result);
    }
  }

  Future<void> _showFilterDialog() async {
    final result = await showDialog<PedidoFilters>(
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

  List<PedidoItem> get _filteredAndSortedItems {
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
            (item.numero?.toString().contains(query) ?? false) ||
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
        filtered.sort((a, b) {
          if (a.numero == null && b.numero == null) return 0;
          if (a.numero == null) return -1;
          if (b.numero == null) return 1;
          return a.numero!.compareTo(b.numero!);
        });
        break;
      case SortOption.numeroDesc:
        filtered.sort((a, b) {
          if (a.numero == null && b.numero == null) return 0;
          if (a.numero == null) return 1;
          if (b.numero == null) return -1;
          return b.numero!.compareTo(a.numero!);
        });
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
                                  Icons.shopping_cart_outlined,
                                  size: 32,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Pedidos', 
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            ExcludeFocus(
                              child: IconButton(
                                onPressed: _load,
                                icon: const Icon(Icons.refresh),
                                tooltip: 'Atualizar',
                              ),
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
                                    hintText: 'Buscar pedidos',
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
                                      materiais: const [],
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
                          _EmptyPedidosState(
                            hasSearch: _searchQuery.isNotEmpty || _filters.hasActiveFilters,
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
                                return _PedidoCard(
                                  item: item,
                                  formattedValue: currency.format(item.total),
                                  onTap: () => _showPedidoEditor(item),
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
  final PedidoFilters currentFilters;
  final List<PedidoItem> allItems;

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
    return ['Em Andamento', 'Concluído', 'Cancelado'];
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
                    'Filtrar Pedidos',
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
                          PedidoFilters(
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

class _EmptyPedidosState extends StatelessWidget {
  final bool hasSearch;

  const _EmptyPedidosState({required this.hasSearch});

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
              'Nenhum pedido encontrado',
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
            child: Icon(Icons.shopping_cart_outlined, color: theme.colorScheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nenhum pedido cadastrado', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Pedidos são criados automaticamente quando um orçamento é aprovado.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.65))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PedidoCard extends StatelessWidget {
  final PedidoItem item;
  final String formattedValue;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final Function(String) onStatusChange;
  final VoidCallback onDownloadPdf;
  final bool isDownloading;

  const _PedidoCard({
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
      case 'Concluído':
        return Colors.green;
      case 'Cancelado':
        return Colors.red;
      default:
        return Colors.blue;
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
              child: Icon(Icons.shopping_cart_outlined, color: theme.colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pedido ${item.numero != null ? "#${item.numero}" : "(sem número)"}',
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
                  if (item.orcamentoNumero != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 14,
                          color: theme.colorScheme.primary.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Orçamento #${item.orcamentoNumero}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary.withValues(alpha: 0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
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
                } else if (value == 'concluir') {
                  onStatusChange('Concluído');
                } else if (value == 'cancelar') {
                  onStatusChange('Cancelado');
                } else if (value == 'andamento') {
                  onStatusChange('Em Andamento');
                }
              },
              tooltip: 'Opções',
              itemBuilder: (context) => [
                if (item.status != 'Em Andamento')
                  const PopupMenuItem(
                    value: 'andamento',
                    child: Row(
                      children: [
                        Icon(Icons.play_circle_outline, color: Colors.blue, size: 18),
                        SizedBox(width: 8),
                        Text('Em Andamento'),
                      ],
                    ),
                  ),
                if (item.status != 'Concluído')
                  const PopupMenuItem(
                    value: 'concluir',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 18),
                        SizedBox(width: 8),
                        Text('Concluir'),
                      ],
                    ),
                  ),
                if (item.status != 'Cancelado')
                  const PopupMenuItem(
                    value: 'cancelar',
                    child: Row(
                      children: [
                        Icon(Icons.cancel, color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Text('Cancelar'),
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

class PedidoEditorSheet extends StatefulWidget {
  final PedidoItem initial;
  final List<PedidoItem> existingPedidos;

  const PedidoEditorSheet({
    super.key,
    required this.initial,
    required this.existingPedidos,
  });
  
  @override
  State<PedidoEditorSheet> createState() => _PedidoEditorSheetState();
}

class _PedidoEditorSheetState extends State<PedidoEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  
  late final TextEditingController _numeroCtrl;
  final FocusNode _dialogFocusNode = FocusNode();
  final FocusNode _numeroFocusNode = FocusNode();
  
  late final String _initialNumero;
  bool _isShowingDiscardDialog = false;

  String _formatQuantity(double value) {
    if (value == value.toInt()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  String _formatUnit(String unit, double quantity) {
    if (unit.toLowerCase() == 'unidade' && quantity > 1) {
      return 'Unidades';
    }
    return unit;
  }

  @override
  void initState() {
    super.initState();
    
    _initialNumero = widget.initial.numero?.toString() ?? '';
    _numeroCtrl = TextEditingController(text: _initialNumero);
    
    _numeroFocusNode.addListener(_onFieldFocusChange);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _numeroFocusNode.requestFocus();
    });
  }

  void _onFieldFocusChange() {
    if (!_numeroFocusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && !_isShowingDiscardDialog) {
          _dialogFocusNode.requestFocus();
        }
      });
    }
  }

  bool get _hasChanges {
    return _numeroCtrl.text != _initialNumero;
  }

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _dialogFocusNode.dispose();
    _numeroFocusNode.dispose();
    super.dispose();
  }

  String? _validateNumeroPedido(String? value) {
    if (value == null || value.trim().isEmpty) {
      // Permitir vazio se o pedido já existia sem número
      if (widget.initial.numero == null) {
        return null; 
      }
      return 'Informe o número';
    }
    
    final trimmedNumero = value.trim();
    final numero = int.tryParse(trimmedNumero);
    
    if (numero == null) {
      return 'Número inválido';
    }
    
    final isDuplicate = widget.existingPedidos.any((pedido) =>
        pedido.numero == numero &&
        pedido.id != widget.initial.id);
    
    if (isDuplicate) {
      return 'Já existe um pedido\ncom este número';
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

    final numeroText = _numeroCtrl.text.trim();
    final numero = numeroText.isEmpty ? null : int.tryParse(numeroText);

    final item = widget.initial.copyWith(
      numero: numero,
    );

    Navigator.of(context).pop(item);
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
                constraints: const BoxConstraints(maxWidth: 900, maxHeight: 850),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
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
                                'Pedido',
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
                              // ✅ Informação sobre orçamento de origem
                              if (widget.initial.orcamentoNumero != null)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 20,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Pedido gerado a partir do Orçamento #${widget.initial.orcamentoNumero}',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Opacity(
                                      opacity: 0.5,
                                      child: IgnorePointer(
                                        ignoring: true,
                                        child: TextFormField(
                                          initialValue: widget.initial.cliente,
                                          enabled: false,
                                          style: const TextStyle(fontSize: 13),
                                          decoration: const InputDecoration(
                                            labelText: 'Cliente',
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          ),
                                        ),
                                      ),
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
                                        labelText: 'Nº Pedido',
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      ),
                                      validator: _validateNumeroPedido,
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // ✅ Produto (disabled)
                              Opacity(
                                opacity: 0.5,
                                child: IgnorePointer(
                                  ignoring: true,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.inventory_2_outlined,
                                              size: 20,
                                              color: theme.colorScheme.primary,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Produto',
                                                    style: theme.textTheme.bodySmall?.copyWith(
                                                      fontSize: 11,
                                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    widget.initial.produtoNome,
                                                    style: theme.textTheme.bodyMedium?.copyWith(
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      const SizedBox(height: 16),
                                      
                                      Text(
                                        'Materiais',
                                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                                      ),
                                      const SizedBox(height: 8),
                                      
                                      ...widget.initial.materiais.map((mat) {
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
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                // ✅ MODIFIQUE ESTA LINHA
                                                child: Text(
                                                  '${_formatQuantity(mat.quantidade)} ${_formatUnit(mat.materialUnidade, mat.quantidade)}',
                                                  style: theme.textTheme.bodySmall?.copyWith(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              SizedBox(
                                                width: 75,
                                                child: Text(
                                                  currency.format(mat.total),
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
                                      
                                      // ✅ Despesas Adicionais
                                      if (widget.initial.despesasAdicionais.isNotEmpty) ...[
                                        const SizedBox(height: 16),
                                        Text(
                                          'Despesas Adicionais',
                                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                                        ),
                                        const SizedBox(height: 8),
                                        ...widget.initial.despesasAdicionais.map((despesa) {
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
                                                  child: Text(
                                                    despesa.descricao,
                                                    style: theme.textTheme.bodySmall?.copyWith(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  currency.format(despesa.valor),
                                                  style: theme.textTheme.bodySmall?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: theme.colorScheme.primary,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ],
                                      
                                      // ✅ Opções Extras
                                      if (widget.initial.opcoesExtras.isNotEmpty) ...[
                                        const SizedBox(height: 16),
                                        Text(
                                          'Outros',
                                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                                        ),
                                        const SizedBox(height: 8),
                                        ...widget.initial.opcoesExtras.map((opcao) {
                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 6),
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
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
                                                        size: 16,
                                                        color: theme.colorScheme.onSecondaryContainer,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Text(
                                                        opcao.nome,
                                                        style: theme.textTheme.bodySmall?.copyWith(
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                
                                                if (opcao.tipo == TipoOpcaoExtra.stringFloat) ...[
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        flex: 2,
                                                        child: Container(
                                                          padding: const EdgeInsets.all(8),
                                                          decoration: BoxDecoration(
                                                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            opcao.valorString ?? '',
                                                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Container(
                                                          padding: const EdgeInsets.all(8),
                                                          decoration: BoxDecoration(
                                                            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            currency.format(opcao.valorFloat1 ?? 0),
                                                            style: theme.textTheme.bodySmall?.copyWith(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w600,
                                                              color: theme.colorScheme.primary,
                                                            ),
                                                            textAlign: TextAlign.right,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ]
                                                else if (opcao.tipo == TipoOpcaoExtra.floatFloat) ...[
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Container(
                                                          padding: const EdgeInsets.all(8),
                                                          decoration: BoxDecoration(
                                                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            '${_formatQuantity(opcao.valorFloat1 ?? 0)} h',
                                                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Container(
                                                          padding: const EdgeInsets.all(8),
                                                          decoration: BoxDecoration(
                                                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            '${currency.format(opcao.valorFloat2 ?? 0)}/h',
                                                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Container(
                                                          padding: const EdgeInsets.all(8),
                                                          decoration: BoxDecoration(
                                                            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            currency.format((opcao.valorFloat1 ?? 0) * (opcao.valorFloat2 ?? 0)),
                                                            style: theme.textTheme.bodySmall?.copyWith(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w600,
                                                              color: theme.colorScheme.primary,
                                                            ),
                                                            textAlign: TextAlign.right,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ]
                                                else if (opcao.tipo == TipoOpcaoExtra.percentFloat) ...[
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Container(
                                                          padding: const EdgeInsets.all(8),
                                                          decoration: BoxDecoration(
                                                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            '${_formatQuantity(opcao.valorFloat1 ?? 0)}%',
                                                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Container(
                                                          padding: const EdgeInsets.all(8),
                                                          decoration: BoxDecoration(
                                                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            currency.format(opcao.valorFloat2 ?? 0),
                                                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Container(
                                                          padding: const EdgeInsets.all(8),
                                                          decoration: BoxDecoration(
                                                            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            currency.format(((opcao.valorFloat1 ?? 0) / 100.0) * (opcao.valorFloat2 ?? 0)),
                                                            style: theme.textTheme.bodySmall?.copyWith(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w600,
                                                              color: theme.colorScheme.primary,
                                                            ),
                                                            textAlign: TextAlign.right,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          );
                                        }),
                                      ],
                                      
                                      const SizedBox(height: 16),
                                      
                                      // ✅ Forma e Condições de Pagamento
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              initialValue: widget.initial.formaPagamento,
                                              enabled: false,
                                              style: const TextStyle(fontSize: 13),
                                              decoration: const InputDecoration(
                                                labelText: 'Forma de Pagamento',
                                                isDense: true,
                                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: TextFormField(
                                              initialValue: widget.initial.condicoesPagamento,
                                              enabled: false,
                                              style: const TextStyle(fontSize: 13),
                                              decoration: const InputDecoration(
                                                labelText: 'Condições de Pagamento',
                                                isDense: true,
                                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      
                                      const SizedBox(height: 10),
                                      
                                      TextFormField(
                                        initialValue: widget.initial.prazoEntrega,
                                        enabled: false,
                                        style: const TextStyle(fontSize: 13),
                                        decoration: const InputDecoration(
                                          labelText: 'Prazo de Entrega',
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                  'Total do Pedido',
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  currency.format(widget.initial.total),
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
                                      child: const Text('Finalizar'),
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
            ),
          ),
        ),
      ),
    );
  }
}
