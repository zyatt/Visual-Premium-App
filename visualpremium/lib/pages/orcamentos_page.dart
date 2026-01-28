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

class BudgetsPage extends StatefulWidget {
  const BudgetsPage({super.key});

  @override
  State<BudgetsPage> createState() => _BudgetsPageState();
}

class _BudgetsPageState extends State<BudgetsPage> {
  final _api = OrcamentosApiRepository();
  bool _loading = true;
  List<OrcamentoItem> _items = const [];
  String _searchQuery = '';
  int? _downloadingId;
  SortOption _sortOption = SortOption.newestFirst;

  @override
  void initState() {
    super.initState();
    _load();
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
      final updated = await _api.updateStatus(item.id, newStatus);
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
      
      // Abre o PDF com o aplicativo padrão do sistema
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

  List<OrcamentoItem> get _filteredAndSortedItems {
    var filtered = _items;
    
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
      body: SingleChildScrollView(
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
                      Text('Orçamentos', style: theme.textTheme.headlineMedium),
                      ElevatedButton.icon(
                        onPressed: () => _showOrcamentoEditor(null),
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text('Novo Orçamento'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                        hintText: 'Buscar orçamentos...',
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
                    _EmptyOrcamentosState(
                      hasSearch: _searchQuery.isNotEmpty,
                      onCreate: () => _showOrcamentoEditor(null),
                    )
                  else
                    ListView.separated(
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
                ],
              ),
            ),
            const SizedBox(width: 24),
            _FilterPanel(
              sortOption: _sortOption,
              onToggleDateSort: _toggleDateSort,
              onToggleClienteSort: _toggleClienteSort,
              onToggleNumeroSort: _toggleNumeroSort,
              onToggleProdutoSort: _toggleProdutoSort,
              onToggleStatusSort: _toggleStatusSort,
              onToggleTotalSort: _toggleTotalSort,
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
                  Text(
                    item.cliente,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
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
              constraints: const BoxConstraints(),
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
  final _dialogFocusNode = FocusNode();
  final _clienteFocusNode = FocusNode();
  final _numeroFocusNode = FocusNode();
  final _freteDescFocusNode = FocusNode();
  final _freteValorFocusNode = FocusNode();
  final _munckHorasFocusNode = FocusNode();
  final _munckValorHoraFocusNode = FocusNode();
  
  late final TextEditingController _clienteCtrl;
  late final TextEditingController _numeroCtrl;
  late final TextEditingController _freteDescCtrl;
  late final TextEditingController _freteValorCtrl;
  late final TextEditingController _munckHorasCtrl;
  late final TextEditingController _munckValorHoraCtrl;

  final List<TextEditingController> _despesaDescControllers = [];
  final List<TextEditingController> _despesaValorControllers = [];
  final List<FocusNode> _despesaDescFocusNodes = [];
  final List<FocusNode> _despesaValorFocusNodes = [];

  late final String _initialCliente;
  late final String _initialNumero;
  late final String _initialFreteDesc;
  late final String _initialFreteValor;
  late final String _initialMunckHoras;
  late final String _initialMunckValorHora;
  late final bool? _initialFrete;
  late final bool? _initialCaminhaoMunck;
  late final int? _initialSelectedProdutoId;
  late final List<String> _initialDespesasDesc;
  late final List<String> _initialDespesasValor;
  late final Map<int, String> _initialQuantities;

  void _updateTotal() {
    setState(() {});
  }
  
  List<ProdutoItem> _produtos = [];
  ProdutoItem? _selectedProduto;
  final Map<int, TextEditingController> _quantityControllers = {};
  final Map<int, FocusNode> _quantityFocusNodes = {};
  bool _loading = true;
  bool _isShowingDiscardDialog = false;

  bool? _frete;
  bool? _caminhaoMunck;

  @override
  void initState() {
    super.initState();
    
    _initialCliente = widget.initial?.cliente ?? '';
    _initialNumero = widget.initial?.numero.toString() ?? '';
    _initialFreteDesc = widget.initial?.freteDesc ?? '';
    _initialFreteValor = widget.initial?.freteValor?.toStringAsFixed(2) ?? '';
    _initialMunckHoras = widget.initial?.caminhaoMunckHoras?.toStringAsFixed(1) ?? '';
    _initialMunckValorHora = widget.initial?.caminhaoMunckValorHora?.toStringAsFixed(2) ?? '';
    _initialFrete = widget.initial?.frete;
    _initialCaminhaoMunck = widget.initial?.caminhaoMunck;
    _initialSelectedProdutoId = widget.initial?.produtoId;
    
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
    
    _freteValorCtrl.addListener(_updateTotal);
    _munckHorasCtrl.addListener(_updateTotal);
    _munckValorHoraCtrl.addListener(_updateTotal);
    
    _clienteFocusNode.addListener(_onFieldFocusChange);
    _numeroFocusNode.addListener(_onFieldFocusChange);
    _freteDescFocusNode.addListener(_onFieldFocusChange);
    _freteValorFocusNode.addListener(_onFieldFocusChange);
    _munckHorasFocusNode.addListener(_onFieldFocusChange);
    _munckValorHoraFocusNode.addListener(_onFieldFocusChange);
    
    if (widget.initial != null) {
      _frete = widget.initial!.frete;
      _caminhaoMunck = widget.initial!.caminhaoMunck;
      
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
    
    _loadProdutos();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dialogFocusNode.requestFocus();
    });
  }

  void _onFieldFocusChange() {
    bool anyFieldHasFocus = _clienteFocusNode.hasFocus ||
        _numeroFocusNode.hasFocus ||
        _freteDescFocusNode.hasFocus ||
        _freteValorFocusNode.hasFocus ||
        _munckHorasFocusNode.hasFocus ||
        _munckValorHoraFocusNode.hasFocus;
    
    if (!anyFieldHasFocus) {
      for (final focusNode in _despesaDescFocusNodes) {
        if (focusNode.hasFocus) {
          anyFieldHasFocus = true;
          break;
        }
      }
    }
    
    if (!anyFieldHasFocus) {
      for (final focusNode in _despesaValorFocusNodes) {
        if (focusNode.hasFocus) {
          anyFieldHasFocus = true;
          break;
        }
      }
    }
    
    if (!anyFieldHasFocus) {
      for (final focusNode in _quantityFocusNodes.values) {
        if (focusNode.hasFocus) {
          anyFieldHasFocus = true;
          break;
        }
      }
    }
    
    if (!anyFieldHasFocus) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && !_isShowingDiscardDialog) {
          _dialogFocusNode.requestFocus();
        }
      });
    }
  }

  bool get _hasChanges {
    if (_clienteCtrl.text != _initialCliente) return true;
    if (_numeroCtrl.text != _initialNumero) return true;
    if (_freteDescCtrl.text != _initialFreteDesc) return true;
    if (_freteValorCtrl.text != _initialFreteValor) return true;
    if (_munckHorasCtrl.text != _initialMunckHoras) return true;
    if (_munckValorHoraCtrl.text != _initialMunckValorHora) return true;
    if (_frete != _initialFrete) return true;
    if (_caminhaoMunck != _initialCaminhaoMunck) return true;
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
        _produtos = produtos;
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
    _dialogFocusNode.dispose();
    _clienteFocusNode.dispose();
    _numeroFocusNode.dispose();
    _freteDescFocusNode.dispose();
    _freteValorFocusNode.dispose();
    _munckHorasFocusNode.dispose();
    _munckValorHoraFocusNode.dispose();
    _clienteCtrl.dispose();
    _numeroCtrl.dispose();
    _freteDescCtrl.dispose();
    _freteValorCtrl.dispose();
    _munckHorasCtrl.dispose();
    _munckValorHoraCtrl.dispose();
    
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
    
    for (final mat in _selectedProduto!.materiais) {
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
    );

    Navigator.of(context).pop(item);
  }

  Widget _buildDespesasSection() {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Despesas Adicionais',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            IconButton(
              onPressed: _adicionarDespesa,
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Adicionar despesa',
              style: IconButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_despesaDescControllers.isEmpty)
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
                    'Nenhuma despesa adicional. Clique em + para adicionar.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...List.generate(_despesaDescControllers.length, (index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _despesaDescControllers[index],
                      focusNode: _despesaDescFocusNodes[index],
                      decoration: const InputDecoration(
                        labelText: 'Descrição',
                        isDense: true,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a descrição' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _despesaValorControllers[index],
                      focusNode: _despesaValorFocusNodes[index],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Valor',
                        isDense: true,
                        prefixText: 'R\$ ',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Informe o valor';
                        }
                        final value = double.tryParse(v.replaceAll(',', '.'));
                        if (value == null || value <= 0) {
                          return 'Valor inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _removerDespesa(index),
                    icon: const Icon(Icons.delete_outline),
                    color: theme.colorScheme.error,
                    tooltip: 'Remover',
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');

    return GestureDetector(
      onTap: () async {
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted && context.mounted) {
          Navigator.of(context).pop();
        }
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
                constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 700),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : Row(
                          children: [
                            Container(
                              width: 280,
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
                                    padding: const EdgeInsets.all(20),
                                    child: Text(
                                      'Produtos',
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  Expanded(
                                    child: ListView.builder(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      itemCount: _produtos.length,
                                      itemBuilder: (context, index) {
                                        final produto = _produtos[index];
                                        final isSelected = _selectedProduto?.id == produto.id;
                                        
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: InkWell(
                                            onTap: () {
                                              setState(() {
                                                _selectedProduto = produto;
                                                _quantityControllers.clear();
                                                _quantityFocusNodes.clear();
                                                _initializeQuantityControllers();
                                              });
                                            },
                                            borderRadius: BorderRadius.circular(10),
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? theme.colorScheme.primary.withValues(alpha: 0.15)
                                                    : theme.colorScheme.surface,
                                                borderRadius: BorderRadius.circular(10),
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
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: isSelected
                                                          ? theme.colorScheme.primary.withValues(alpha: 0.2)
                                                          : theme.colorScheme.primary.withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Icon(
                                                      Icons.inventory_2_outlined,
                                                      color: theme.colorScheme.primary,
                                                      size: 18,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          produto.nome,
                                                          style: theme.textTheme.bodyMedium?.copyWith(
                                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                          ),
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        Text(
                                                          '${produto.materiais.length} materiais',
                                                          style: theme.textTheme.bodySmall?.copyWith(
                                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
                                ],
                              ),
                            ),
                            Expanded(
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
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
                                          IconButton(
                                            onPressed: () async {
                                              final shouldClose = await _onWillPop();
                                              if (shouldClose && context.mounted) {
                                                Navigator.of(context).pop();
                                              }
                                            },
                                            icon: const Icon(Icons.close),
                                            tooltip: 'Fechar (Esc)',
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        padding: const EdgeInsets.all(20),
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
                                                    decoration: const InputDecoration(
                                                      labelText: 'Cliente',
                                                      isDense: true,
                                                    ),
                                                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o cliente' : null,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: TextFormField(
                                                    controller: _numeroCtrl,
                                                    focusNode: _numeroFocusNode,
                                                    keyboardType: TextInputType.number,
                                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                                    decoration: const InputDecoration(
                                                      labelText: 'Nº Orçamento',
                                                      isDense: true,
                                                    ),
                                                    validator: _validateNumeroOrcamento,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            
                                            const SizedBox(height: 20),
                                            
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
                                                              padding: const EdgeInsets.all(16),
                                                              margin: const EdgeInsets.only(bottom: 16),
                                                              decoration: BoxDecoration(
                                                                color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                                                                borderRadius: BorderRadius.circular(10),
                                                                border: Border.all(
                                                                  color: theme.colorScheme.error.withValues(alpha: 0.5),
                                                                ),
                                                              ),
                                                              child: Row(
                                                                children: [
                                                                  Icon(
                                                                    Icons.error_outline,
                                                                    color: theme.colorScheme.error,
                                                                    size: 20,
                                                                  ),
                                                                  const SizedBox(width: 12),
                                                                  Expanded(
                                                                    child: Text(
                                                                      formFieldState.errorText ?? '',
                                                                      style: theme.textTheme.bodySmall?.copyWith(
                                                                        color: theme.colorScheme.error,
                                                                        fontWeight: FontWeight.w500,
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
                                                    padding: const EdgeInsets.symmetric(vertical: 60),
                                                    child: Center(
                                                      child: Column(
                                                        children: [
                                                          Icon(
                                                            Icons.inventory_2_outlined,
                                                            size: 64,
                                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                                                          ),
                                                          const SizedBox(height: 16),
                                                          Text(
                                                            'Selecione um produto',
                                                            style: theme.textTheme.titleMedium?.copyWith(
                                                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                                            ),
                                                          ),
                                                          const SizedBox(height: 8),
                                                          Text(
                                                            'Escolha um produto na lista ao lado para começar',
                                                            style: theme.textTheme.bodySmall?.copyWith(
                                                              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
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
                                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                              ),
                                              const SizedBox(height: 12),
                                              
                                              ..._selectedProduto!.materiais.map((mat) {
                                                final controller = _quantityControllers[mat.materialId];
                                                final focusNode = _quantityFocusNodes[mat.materialId];
                                                if (controller == null || focusNode == null) return const SizedBox();
                                                
                                                final qty = double.tryParse(controller.text.replaceAll(',', '.')) ?? 0.0;
                                                final total = mat.materialCusto * qty;
                                                
                                                return Container(
                                                  margin: const EdgeInsets.only(bottom: 8),
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                                    borderRadius: BorderRadius.circular(10),
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
                                                              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                                                            ),
                                                            Text(
                                                              '${currency.format(mat.materialCusto)} / ${mat.materialUnidade}',
                                                              style: theme.textTheme.bodySmall?.copyWith(
                                                                fontSize: 11,
                                                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      SizedBox(
                                                        width: 90,
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
                                                          style: const TextStyle(fontSize: 13),
                                                          decoration: const InputDecoration(
                                                            labelText: 'Qtd',
                                                            isDense: true,
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
                                                      const SizedBox(width: 12),
                                                      SizedBox(
                                                        width: 90,
                                                        child: Text(
                                                          currency.format(total),
                                                          style: theme.textTheme.bodySmall?.copyWith(
                                                            fontWeight: FontWeight.bold,
                                                            color: theme.colorScheme.primary,
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
                                              
                                              const SizedBox(height: 16),
                                              
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
                                                              decoration: const InputDecoration(
                                                                labelText: 'Descrição',
                                                                isDense: true,
                                                              ),
                                                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a descrição' : null,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 12),
                                                          Expanded(
                                                            child: TextFormField(
                                                              controller: _freteValorCtrl,
                                                              focusNode: _freteValorFocusNode,
                                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                              inputFormatters: [
                                                                FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                                                              ],
                                                              decoration: const InputDecoration(
                                                                labelText: 'Valor',
                                                                isDense: true,
                                                                prefixText: 'R\$ ',
                                                              ),
                                                              validator: (v) {
                                                                if (v == null || v.trim().isEmpty) {
                                                                  return 'Informe o valor';
                                                                }
                                                                final value = double.tryParse(v.replaceAll(',', '.'));
                                                                if (value == null || value < 0) {
                                                                  return 'Valor inválido';
                                                                }
                                                                return null;
                                                              },
                                                            ),
                                                          ),
                                                        ],
                                                      )
                                                    : null,
                                              ),
                                              
                                              const SizedBox(height: 12),
                                              
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
                                                              decoration: const InputDecoration(
                                                                labelText: 'Horas',
                                                                isDense: true,
                                                                suffixText: 'h',
                                                              ),
                                                              validator: (v) {
                                                                if (v == null || v.trim().isEmpty) {
                                                                  return 'Informe as horas';
                                                                }
                                                                final value = double.tryParse(v.replaceAll(',', '.'));
                                                                if (value == null || value < 0) {
                                                                  return 'Horas inválidas';
                                                                }
                                                                return null;
                                                              },
                                                            ),
                                                          ),
                                                          const SizedBox(width: 12),
                                                          Expanded(
                                                            child: TextFormField(
                                                              controller: _munckValorHoraCtrl,
                                                              focusNode: _munckValorHoraFocusNode,
                                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                              inputFormatters: [
                                                                FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                                                              ],
                                                              decoration: const InputDecoration(
                                                                labelText: 'Valor/Hora',
                                                                isDense: true,
                                                                prefixText: 'R\$ ',
                                                              ),
                                                              validator: (v) {
                                                                if (v == null || v.trim().isEmpty) {
                                                                  return 'Informe o valor';
                                                                }
                                                                final value = double.tryParse(v.replaceAll(',', '.'));
                                                                if (value == null || value < 0) {
                                                                  return 'Valor inválido';
                                                                }
                                                                return null;
                                                              },
                                                            ),
                                                          ),
                                                        ],
                                                      )
                                                    : null,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                    
                                    Container(
                                      padding: const EdgeInsets.all(20),
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
                                          const SizedBox(height: 16),
                                          Row(
                                            children: [
                                              Expanded(
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
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: ElevatedButton(
                                                  onPressed: _save,
                                                  child: Text(widget.initial == null ? 'Finalizar' : 'Salvar'),
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
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
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
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
                    const SizedBox(height: 8),
                    Text(
                      formFieldState.errorText ?? '',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  if (child != null) ...[
                    const SizedBox(height: 10),
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
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
            fontSize: 12,
            color: selected 
                ? theme.colorScheme.onPrimary 
                : theme.colorScheme.onSurface,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}