import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:visualpremium/data/orcamentos_repository.dart';
import 'package:visualpremium/models/orcamento_item.dart';
import '../theme.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar orçamentos: $e')),
      );
    }
  }

  Future<void> _upsert(OrcamentoItem item) async {
    setState(() => _loading = true);
    try {
      OrcamentoItem updated;
      if (_items.any((e) => e.id == item.id)) {
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar orçamento: $e')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar status: $e')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao deletar orçamento: $e')),
      );
    }
  }

  Future<bool?> _showConfirmDelete(String cliente, int numero) {
    final theme = Theme.of(context);
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
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
        );
      },
    );
  }

  Future<void> _showOrcamentoEditor(OrcamentoItem? initial) async {
    final theme = Theme.of(context);
    final result = await showDialog<OrcamentoItem>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 800),
            child: OrcamentoEditorSheet(initial: initial),
          ),
        );
      },
    );

    if (result != null) {
      await _upsert(result);
    }
  }

  List<OrcamentoItem> get _filteredItems {
    if (_searchQuery.isEmpty) return _items;
    final query = _searchQuery.toLowerCase();
    return _items.where((item) {
      return item.cliente.toLowerCase().contains(query) ||
          item.numero.toString().contains(query) ||
          item.produtoNome.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Orçamentos',
                      style: theme.textTheme.headlineMedium,
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showOrcamentoEditor(null),
                  icon: const Icon(Icons.add),
                  label: const Text('Novo Orçamento'),
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
                separatorBuilder: (context, index) => const SizedBox(height: 16),
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
                  );
                },
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
            child: Icon(Icons.description_outlined, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nenhum orçamento cadastrado', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Crie orçamentos para seus clientes com produtos e materiais.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.65))),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('Criar Orçamento')),
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

  const _OrcamentoCard({
    required this.item,
    required this.formattedValue,
    required this.onTap,
    required this.onDelete,
    required this.onStatusChange,
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
        padding: const EdgeInsets.all(24),
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
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.description_outlined,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Orçamento #${item.numero}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    item.cliente,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    item.produtoNome,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
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
            const SizedBox(width: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withValues(alpha: 0.2)),
              ),
              child: Text(
                item.status,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 16),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
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
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
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
                        Icon(Icons.cancel, color: Colors.red, size: 20),
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
                        Icon(Icons.schedule, color: Colors.orange, size: 20),
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

class OrcamentoEditorSheet extends StatefulWidget {
  final OrcamentoItem? initial;

  const OrcamentoEditorSheet({super.key, required this.initial});

  @override
  State<OrcamentoEditorSheet> createState() => _OrcamentoEditorSheetState();
}

class _OrcamentoEditorSheetState extends State<OrcamentoEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _api = OrcamentosApiRepository();
  late final TextEditingController _clienteCtrl;
  late final TextEditingController _numeroCtrl;
  
  List<ProdutoItem> _produtos = [];
  ProdutoItem? _selectedProduto;
  final Map<int, String> _quantities = {};
  bool _loading = true;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _clienteCtrl = TextEditingController(text: widget.initial?.cliente ?? '');
    _numeroCtrl = TextEditingController(text: widget.initial?.numero.toString() ?? '');
    
    _clienteCtrl.addListener(() => _markChanged());
    _numeroCtrl.addListener(() => _markChanged());
    
    if (widget.initial != null) {
      for (final mat in widget.initial!.materiais) {
        _quantities[mat.materialId] = mat.quantidade;
      }
    }
    
    _loadProdutos();
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
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

  @override
  void dispose() {
    _clienteCtrl.dispose();
    _numeroCtrl.dispose();
    super.dispose();
  }

  double _calculateTotal() {
    if (_selectedProduto == null) return 0.0;
    double total = 0.0;
    for (final mat in _selectedProduto!.materiais) {
      final qtyStr = _quantities[mat.materialId] ?? '0';
      final qty = double.tryParse(qtyStr) ?? 0.0;
      total += mat.materialCusto * qty;
    }
    return total;
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

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProduto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um produto')),
      );
      return;
    }

    final materiais = <OrcamentoMaterialItem>[];
    for (final mat in _selectedProduto!.materiais) {
    final qtyStr = _quantities[mat.materialId] ?? '0';
    if (qtyStr.isNotEmpty && qtyStr != '0') {
      // Valida se é um número válido
      final qtyTest = double.tryParse(qtyStr.replaceAll(',', '.'));
      if (qtyTest != null && qtyTest > 0) {
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
          quantidade: qtyStr.replaceAll(',', '.'), // Normaliza vírgula para ponto
        ));
      }
    }
  }

    if (materiais.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione pelo menos um material com quantidade')),
      );
      return;
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
      numero: int.parse(_numeroCtrl.text),
      produtoId: _selectedProduto!.id,
      produtoNome: _selectedProduto!.nome,
      materiais: materiais,
    );

    context.pop(item);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          context.pop();
        }
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                              context.pop();
                            }
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _clienteCtrl,
                            decoration: const InputDecoration(labelText: 'Cliente'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o cliente' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _numeroCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(labelText: 'Número do Orçamento'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o número' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<ProdutoItem>(
                      initialValue: _selectedProduto,
                      decoration: const InputDecoration(labelText: 'Produto'),
                      items: _produtos
                          .map((p) => DropdownMenuItem(
                                value: p,
                                child: Text(p.nome),
                              ))
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedProduto = v;
                          _markChanged();
                        });
                      },
                      validator: (v) => v == null ? 'Selecione um produto' : null,
                    ),
                    if (_selectedProduto != null) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Materiais do Produto',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      ..._selectedProduto!.materiais.map((mat) {
                        final qtyStr = _quantities[mat.materialId] ?? '0';
                        final qty = double.tryParse(qtyStr.replaceAll(',', '.')) ?? 0.0;
                        final total = mat.materialCusto * qty;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
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
                                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      '${currency.format(mat.materialCusto)} / ${mat.materialUnidade}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 120,
                                child: TextFormField(
                                  initialValue: _quantities[mat.materialId] ?? '',
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
                                  decoration: const InputDecoration(
                                    labelText: 'Quantidade',
                                    isDense: true,
                                  ),
                                  onChanged: (v) {
                                    setState(() {
                                      _quantities[mat.materialId] = v.trim();
                                      _markChanged();
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 120,
                                child: Text(
                                  currency.format(total),
                                  style: theme.textTheme.titleMedium?.copyWith(
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
                      const Divider(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total do Orçamento',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
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
                    ],
                    const SizedBox(height: 24),
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
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _save,
                            child: Text(widget.initial == null ? 'Finalizar Orçamento' : 'Salvar'),
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