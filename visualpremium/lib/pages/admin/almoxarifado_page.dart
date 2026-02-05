import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:visualpremium/data/orcamentos_repository.dart';
import 'package:visualpremium/models/orcamento_item.dart';
import '../../../theme.dart';

class AlmoxarifadoPage extends StatefulWidget {
  const AlmoxarifadoPage({super.key});

  @override
  State<AlmoxarifadoPage> createState() => _AlmoxarifadoPageState();
}

class _AlmoxarifadoPageState extends State<AlmoxarifadoPage> {
  final _api = OrcamentosApiRepository();
  bool _loading = true;
  List<OrcamentoItem> _orcamentosAprovados = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadOrcamentosAprovados();
  }

  Future<void> _loadOrcamentosAprovados() async {
    setState(() => _loading = true);
    try {
      final allOrcamentos = await _api.fetchOrcamentos();
      final aprovados = allOrcamentos.where((o) => o.status == 'Aprovado').toList();
      
      if (!mounted) return;
      setState(() {
        _orcamentosAprovados = aprovados;
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

  Future<void> _abrirOrcamento(OrcamentoItem orcamento) async {
    final resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _AlmoxarifadoEditorDialog(orcamento: orcamento);
      },
    );

    if (resultado == true) {
      // Recarregar a lista após finalizar
      await _loadOrcamentosAprovados();
    }
  }

  List<OrcamentoItem> get _filteredOrcamentos {
    if (_searchQuery.isEmpty) {
      return _orcamentosAprovados;
    }
    
    final query = _searchQuery.toLowerCase();
    return _orcamentosAprovados.where((o) {
      return o.cliente.toLowerCase().contains(query) ||
          o.numero.toString().contains(query) ||
          o.produtoNome.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final filteredOrcamentos = _filteredOrcamentos;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadOrcamentosAprovados,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2,
                        size: 32,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Almoxarifado',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: _loadOrcamentosAprovados,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Atualizar',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Registre os custos dos materiais dos orçamentos aprovados',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
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
                    hintText: 'Buscar orçamentos aprovados',
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
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                )
              else if (filteredOrcamentos.isEmpty)
                _EmptyState(
                  hasSearch: _searchQuery.isNotEmpty,
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredOrcamentos.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final orcamento = filteredOrcamentos[index];
                    return _OrcamentoCard(
                      orcamento: orcamento,
                      formattedValue: currency.format(orcamento.total),
                      onTap: () => _abrirOrcamento(orcamento),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasSearch;

  const _EmptyState({required this.hasSearch});

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
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
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
            child: Icon(Icons.inventory_2_outlined, color: theme.colorScheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nenhum orçamento aprovado',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Os orçamentos aprovados aparecerão aqui para registro de custos.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrcamentoCard extends StatelessWidget {
  final OrcamentoItem orcamento;
  final String formattedValue;
  final VoidCallback onTap;

  const _OrcamentoCard({
    required this.orcamento,
    required this.formattedValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Orçamento #${orcamento.numero}',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    orcamento.cliente,
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
                        orcamento.produtoNome,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.category_outlined,
                        size: 14,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${orcamento.materiais.length} materiais',
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
                const SizedBox(height: 2),
                Text(
                  dateFormat.format(orcamento.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlmoxarifadoEditorDialog extends StatefulWidget {
  final OrcamentoItem orcamento;

  const _AlmoxarifadoEditorDialog({required this.orcamento});

  @override
  State<_AlmoxarifadoEditorDialog> createState() => _AlmoxarifadoEditorDialogState();
}

class _AlmoxarifadoEditorDialogState extends State<_AlmoxarifadoEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final Map<int, TextEditingController> _valorControllers = {};
  final Map<int, FocusNode> _valorFocusNodes = {};
  final FocusNode _dialogFocusNode = FocusNode();
  bool _isShowingDiscardDialog = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    
    for (final focusNode in _valorFocusNodes.values) {
      focusNode.addListener(_onFieldFocusChange);
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dialogFocusNode.requestFocus();
    });
  }

  void _initializeControllers() {
    for (final material in widget.orcamento.materiais) {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      
      _valorControllers[material.materialId] = controller;
      _valorFocusNodes[material.materialId] = focusNode;
    }
  }

  void _onFieldFocusChange() {
    if (!_valorFocusNodes.values.any((node) => node.hasFocus)) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && !_isShowingDiscardDialog) {
          _dialogFocusNode.requestFocus();
        }
      });
    }
  }

  bool get _hasChanges {
    return _valorControllers.values.any((ctrl) => ctrl.text.trim().isNotEmpty);
  }

  @override
  void dispose() {
    for (final controller in _valorControllers.values) {
      controller.dispose();
    }
    for (final focusNode in _valorFocusNodes.values) {
      focusNode.dispose();
    }
    _dialogFocusNode.dispose();
    super.dispose();
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

  void _finalizar() {
    if (!_formKey.currentState!.validate()) return;

    // Aqui você pode salvar os valores no banco de dados
    // Por enquanto, apenas fechamos o diálogo
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Custos registrados com sucesso!'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
    
    Navigator.of(context).pop(true);
  }

  double _calcularTotalCustos() {
    double total = 0.0;
    
    for (final material in widget.orcamento.materiais) {
      final controller = _valorControllers[material.materialId];
      if (controller != null && controller.text.trim().isNotEmpty) {
        final valorTotal = double.tryParse(controller.text.replaceAll(',', '.')) ?? 0.0;
        total += valorTotal; // SEM multiplicar pela quantidade
      }
    }
    
    return total;
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
        child: Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: theme.dividerColor.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.inventory_2, color: Colors.green, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Orçamento #${widget.orcamento.numero}',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                widget.orcamento.cliente,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
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
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: theme.colorScheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Produto: ${widget.orcamento.produtoNome}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Registre o custo total de cada material',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...widget.orcamento.materiais.map((material) {
                            final controller = _valorControllers[material.materialId];
                            final focusNode = _valorFocusNodes[material.materialId];
                            
                            if (controller == null || focusNode == null) {
                              return const SizedBox();
                            }
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                border: Border.all(
                                  color: theme.dividerColor.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    material.materialNome,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'Custo Total do Material',
                                      isDense: true,
                                      prefixText: 'R\$ ',
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Informe o custo total';
                                      }
                                      final value = double.tryParse(v.replaceAll(',', '.'));
                                      if (value == null || value <= 0) {
                                        return 'Valor inválido';
                                      }
                                      return null;
                                    },
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ],
                              ),
                            );
                          }),
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total dos Custos',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Valor total gasto com materiais',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              currency.format(_calcularTotalCustos()),
                              style: theme.textTheme.headlineSmall?.copyWith(
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
                              child: ElevatedButton.icon(
                                onPressed: _finalizar,
                                icon: const Icon(Icons.check),
                                label: const Text('Finalizar'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
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
    );
  }
}