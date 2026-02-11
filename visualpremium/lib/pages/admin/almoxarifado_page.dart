import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  Map<int, String> _statusAlmoxarifado = {};
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
      
      final statusMap = <int, String>{};
      for (final orc in aprovados) {
        try {
          final almox = await _api.fetchAlmoxarifadoPorOrcamento(orc.id);
          if (almox != null) {
            statusMap[orc.id] = almox['status'] as String? ?? 'Não Realizado';
          } else {
            statusMap[orc.id] = 'Não Realizado';
          }
        } catch (e) {
          statusMap[orc.id] = 'Não Realizado';
        }
      }
      
      if (!mounted) return;
      setState(() {
        _orcamentosAprovados = aprovados;
        _statusAlmoxarifado = statusMap;
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
    final status = _statusAlmoxarifado[orcamento.id] ?? 'Não Realizado';
    final isRealizado = status == 'Realizado';

    final resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _AlmoxarifadoEditorDialog(
          orcamento: orcamento,
          isRealizado: isRealizado,
        );
      },
    );

    if (resultado == true) {
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
                  ExcludeFocus(
                    child: IconButton(
                      onPressed: _loadOrcamentosAprovados,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Atualizar',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Registre os custos efetivos dos materiais e despesas',
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
                  onClearSearch: () => setState(() => _searchQuery = ''),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredOrcamentos.length,
                  itemBuilder: (context, index) {
                    final orcamento = filteredOrcamentos[index];
                    final status = _statusAlmoxarifado[orcamento.id] ?? 'Não Realizado';
                    
                    return _OrcamentoCard(
                      orcamento: orcamento,
                      status: status,
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
  final VoidCallback? onClearSearch;

  const _EmptyState({
    this.hasSearch = false,
    this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasSearch ? Icons.search_off : Icons.inventory_2_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch
                  ? 'Nenhum orçamento encontrado'
                  : 'Nenhum orçamento aprovado',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            if (hasSearch) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onClearSearch,
                child: const Text('Limpar busca'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrcamentoCard extends StatelessWidget {
  final OrcamentoItem orcamento;
  final String status;
  final VoidCallback onTap;

  const _OrcamentoCard({
    required this.orcamento,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'Realizado':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Orçamento #${orcamento.numero}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                statusIcon,
                                size: 14,
                                color: statusColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                status,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      orcamento.cliente,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      orcamento.produtoNome,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlmoxarifadoEditorDialog extends StatefulWidget {
  final OrcamentoItem orcamento;
  final bool isRealizado;

  const _AlmoxarifadoEditorDialog({
    required this.orcamento,
    this.isRealizado = false,
  });

  @override
  State<_AlmoxarifadoEditorDialog> createState() => _AlmoxarifadoEditorDialogState();
}

class _AlmoxarifadoEditorDialogState extends State<_AlmoxarifadoEditorDialog> {
  final _api = OrcamentosApiRepository();
  final _formKey = GlobalKey<FormState>();
  final FocusNode _dialogFocusNode = FocusNode();
  
  final Map<int, TextEditingController> _materialControllers = {};
  final Map<int, FocusNode> _materialFocusNodes = {};
  
  final Map<int, TextEditingController> _despesaControllers = {};
  final Map<int, FocusNode> _despesaFocusNodes = {};
  
  final Map<int, Map<String, TextEditingController>> _opcaoExtraControllers = {};
  final Map<int, Map<String, FocusNode>> _opcaoExtraFocusNodes = {};
  
  bool _saving = false;
  bool _hasChanges = false;
  bool _isShowingDiscardDialog = false;
  bool _loadingData = false;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadAlmoxarifadoData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dialogFocusNode.requestFocus();
    });
  }

  void _initControllers() {
    for (var i = 0; i < widget.orcamento.materiais.length; i++) {
      _materialControllers[i] = TextEditingController();
      _materialFocusNodes[i] = FocusNode();
    }

    for (var i = 0; i < widget.orcamento.despesasAdicionais.length; i++) {
      _despesaControllers[i] = TextEditingController();
      _despesaFocusNodes[i] = FocusNode();
    }


    for (var i = 0; i < widget.orcamento.opcoesExtras.length; i++) {
      final opcao = widget.orcamento.opcoesExtras[i];
      
      // Pular opções extras que foram marcadas como "Não" (todos os valores são null)
      final isNaoSelection = opcao.valorString == null && 
                             opcao.valorFloat1 == null && 
                             opcao.valorFloat2 == null;
      
      if (isNaoSelection) {
        continue;
      }
      
      _opcaoExtraControllers[i] = {};
      _opcaoExtraFocusNodes[i] = {};

      switch (opcao.tipo) {
        case TipoOpcaoExtra.stringFloat:
          _opcaoExtraControllers[i]!['valorFloat1'] = TextEditingController();
          _opcaoExtraFocusNodes[i]!['valorFloat1'] = FocusNode();
          break;
        
        case TipoOpcaoExtra.floatFloat:
        case TipoOpcaoExtra.percentFloat:
          _opcaoExtraControllers[i]!['valorFloat1'] = TextEditingController();
          _opcaoExtraFocusNodes[i]!['valorFloat1'] = FocusNode();
          
          _opcaoExtraControllers[i]!['valorFloat2'] = TextEditingController();
          _opcaoExtraFocusNodes[i]!['valorFloat2'] = FocusNode();
          break;
      }
    }
  }

  Future<void> _loadAlmoxarifadoData() async {
    setState(() => _loadingData = true);
    
    try {
      final almoxData = await _api.fetchAlmoxarifadoPorOrcamento(widget.orcamento.id);
      
      if (almoxData == null) {
        setState(() => _loadingData = false);
        return;
      }

      // Carregar materiais
      final materiais = almoxData['materiais'] as List?;
      if (materiais != null) {
        for (var i = 0; i < widget.orcamento.materiais.length; i++) {
          final material = widget.orcamento.materiais[i];
          final materialData = materiais.firstWhere(
            (m) => m['materialId'] == material.materialId,
            orElse: () => null,
          );
          
          if (materialData != null && _materialControllers[i] != null) {
            final custo = materialData['custoRealizado'];
            if (custo != null) {
              _materialControllers[i]!.text = custo.toString().replaceAll('.', ',');
            }
          }
        }
      }

      // Carregar despesas
      final despesas = almoxData['despesasAdicionais'] as List?;
      if (despesas != null) {
        for (var i = 0; i < widget.orcamento.despesasAdicionais.length; i++) {
          final despesa = widget.orcamento.despesasAdicionais[i];
          final despesaData = despesas.firstWhere(
            (d) => d['descricao'] == despesa.descricao,
            orElse: () => null,
          );
          
          if (despesaData != null && _despesaControllers[i] != null) {
            final valor = despesaData['valorRealizado'];
            if (valor != null) {
              _despesaControllers[i]!.text = valor.toString().replaceAll('.', ',');
            }
          }
        }
      }

      // Carregar opções extras
      final opcoesExtras = almoxData['opcoesExtras'] as List?;
      if (opcoesExtras != null) {
        for (var i = 0; i < widget.orcamento.opcoesExtras.length; i++) {
          final opcao = widget.orcamento.opcoesExtras[i];
          final opcaoData = opcoesExtras.firstWhere(
            (o) => o['produtoOpcaoId'] == opcao.produtoOpcaoId,
            orElse: () => null,
          );
          
          if (opcaoData != null && _opcaoExtraControllers[i] != null) {
            final controllers = _opcaoExtraControllers[i]!;
            
            final valorFloat1 = opcaoData['valorFloat1'];
            if (valorFloat1 != null && controllers['valorFloat1'] != null) {
              controllers['valorFloat1']!.text = valorFloat1.toString().replaceAll('.', ',');
            }
            
            final valorFloat2 = opcaoData['valorFloat2'];
            if (valorFloat2 != null && controllers['valorFloat2'] != null) {
              controllers['valorFloat2']!.text = valorFloat2.toString().replaceAll('.', ',');
            }
          }
        }
      }

      if (mounted) {
        setState(() => _loadingData = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingData = false);
      }
    }
  }

  @override
  void dispose() {
    _materialControllers.forEach((_, controller) => controller.dispose());
    _materialFocusNodes.forEach((_, node) => node.dispose());
    _despesaControllers.forEach((_, controller) => controller.dispose());
    _despesaFocusNodes.forEach((_, node) => node.dispose());
    
    _opcaoExtraControllers.forEach((_, controllers) {
      controllers.forEach((_, controller) => controller.dispose());
    });
    _opcaoExtraFocusNodes.forEach((_, nodes) {
      nodes.forEach((_, node) => node.dispose());
    });
    
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

  // Verifica se todos os campos obrigatórios estão preenchidos
  bool _todosOsCamposPreenchidos() {
    // Verificar materiais
    for (var i = 0; i < widget.orcamento.materiais.length; i++) {
      final controller = _materialControllers[i];
      if (controller == null || controller.text.trim().isEmpty) {
        return false;
      }
      final valor = double.tryParse(controller.text.replaceAll(',', '.'));
      if (valor == null || valor < 0) {
        return false;
      }
    }

    // Verificar despesas
    for (var i = 0; i < widget.orcamento.despesasAdicionais.length; i++) {
      final controller = _despesaControllers[i];
      if (controller == null || controller.text.trim().isEmpty) {
        return false;
      }
      final valor = double.tryParse(controller.text.replaceAll(',', '.'));
      if (valor == null || valor < 0) {
        return false;
      }
    }

    // Verificar opções extras
    for (var i = 0; i < widget.orcamento.opcoesExtras.length; i++) {
      final opcao = widget.orcamento.opcoesExtras[i];
      
      // Pular opções extras que foram marcadas como "Não"
      final isNaoSelection = opcao.valorString == null && 
                             opcao.valorFloat1 == null && 
                             opcao.valorFloat2 == null;
      
      if (isNaoSelection) {
        continue;
      }
      
      final controllers = _opcaoExtraControllers[i];
      if (controllers == null || controllers.isEmpty) {
        return false;
      }

      switch (opcao.tipo) {
        case TipoOpcaoExtra.stringFloat:
          final controller = controllers['valorFloat1'];
          if (controller == null || controller.text.trim().isEmpty) {
            return false;
          }
          final valor = double.tryParse(controller.text.replaceAll(',', '.'));
          if (valor == null || valor < 0) {
            return false;
          }
          break;
        
        case TipoOpcaoExtra.floatFloat:
        case TipoOpcaoExtra.percentFloat:
          final controller1 = controllers['valorFloat1'];
          final controller2 = controllers['valorFloat2'];
          
          if (controller1 == null || controller1.text.trim().isEmpty ||
              controller2 == null || controller2.text.trim().isEmpty) {
            return false;
          }
          
          final valor1 = double.tryParse(controller1.text.replaceAll(',', '.'));
          final valor2 = double.tryParse(controller2.text.replaceAll(',', '.'));
          
          if (valor1 == null || valor1 < 0 || valor2 == null || valor2 < 0) {
            return false;
          }
          break;
      }
    }

    return true;
  }

  Future<void> _salvar() async {
    setState(() => _saving = true);

    try {
      final materiais = <Map<String, dynamic>>[];
      for (var i = 0; i < widget.orcamento.materiais.length; i++) {
        final material = widget.orcamento.materiais[i];
        final controller = _materialControllers[i];
        if (controller != null && controller.text.isNotEmpty) {
          final valor = double.tryParse(controller.text.replaceAll(',', '.'));
          if (valor != null) {
            materiais.add({
              'materialId': material.materialId,
              'custoRealizado': valor,
            });
          }
        }
      }

      final despesas = <Map<String, dynamic>>[];
      for (var i = 0; i < widget.orcamento.despesasAdicionais.length; i++) {
        final despesa = widget.orcamento.despesasAdicionais[i];
        final controller = _despesaControllers[i];
        if (controller != null && controller.text.isNotEmpty) {
          final valor = double.tryParse(controller.text.replaceAll(',', '.'));
          if (valor != null) {
            despesas.add({
              'descricao': despesa.descricao,
              'valorRealizado': valor,
            });
          }
        }
      }

      final opcoesExtras = <Map<String, dynamic>>[];
      for (var i = 0; i < widget.orcamento.opcoesExtras.length; i++) {
        final opcao = widget.orcamento.opcoesExtras[i];
        
        // Pular opções extras que foram marcadas como "Não"
        final isNaoSelection = opcao.valorString == null && 
                               opcao.valorFloat1 == null && 
                               opcao.valorFloat2 == null;
        
        if (isNaoSelection) {
          continue;
        }
        
        final controllers = _opcaoExtraControllers[i];
        
        if (controllers == null || controllers.isEmpty) continue;

        final opcaoData = <String, dynamic>{
          'produtoOpcaoId': opcao.produtoOpcaoId,
        };

        bool hasValue = false;

        switch (opcao.tipo) {
          case TipoOpcaoExtra.stringFloat:
            final valorFloat1Controller = controllers['valorFloat1'];
            if (valorFloat1Controller != null && valorFloat1Controller.text.isNotEmpty) {
              opcaoData['valorFloat1'] = double.parse(valorFloat1Controller.text.replaceAll(',', '.'));
              hasValue = true;
            }
            opcaoData['valorString'] = opcao.valorString;
            break;
          
          case TipoOpcaoExtra.floatFloat:
          case TipoOpcaoExtra.percentFloat:
            final valorFloat1Controller = controllers['valorFloat1'];
            final valorFloat2Controller = controllers['valorFloat2'];
            
            if (valorFloat1Controller != null && valorFloat1Controller.text.isNotEmpty) {
              opcaoData['valorFloat1'] = double.parse(valorFloat1Controller.text.replaceAll(',', '.'));
              hasValue = true;
            }
            
            if (valorFloat2Controller != null && valorFloat2Controller.text.isNotEmpty) {
              opcaoData['valorFloat2'] = double.parse(valorFloat2Controller.text.replaceAll(',', '.'));
              hasValue = true;
            }
            break;
        }

        // Só adiciona a opção extra se o usuário preencheu algum valor
        if (hasValue) {
          opcoesExtras.add(opcaoData);
        }
      }

      await _api.salvarAlmoxarifado(
        widget.orcamento.id,
        materiais,
        despesas,
        opcoesExtras,
      );

      if (!mounted) return;

      setState(() {
        _hasChanges = false;
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dados salvos com sucesso!'),
          backgroundColor: Colors.blue,
        ),
      );

      // Recarregar os dados salvos
      await _loadAlmoxarifadoData();
    } catch (e) {
      if (!mounted) return;

      setState(() => _saving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e')),
      );
    }
  }

  Future<void> _finalizar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);

    try {
      final materiais = <Map<String, dynamic>>[];
      for (var i = 0; i < widget.orcamento.materiais.length; i++) {
        final material = widget.orcamento.materiais[i];
        final controller = _materialControllers[i];
        if (controller != null && controller.text.isNotEmpty) {
          final valor = double.parse(controller.text.replaceAll(',', '.'));
          materiais.add({
            'materialId': material.materialId,
            'custoRealizado': valor,
          });
        }
      }

      final despesas = <Map<String, dynamic>>[];
      for (var i = 0; i < widget.orcamento.despesasAdicionais.length; i++) {
        final despesa = widget.orcamento.despesasAdicionais[i];
        final controller = _despesaControllers[i];
        if (controller != null && controller.text.isNotEmpty) {
          final valor = double.parse(controller.text.replaceAll(',', '.'));
          despesas.add({
            'descricao': despesa.descricao,
            'valorRealizado': valor,
          });
        }
      }


      final opcoesExtras = <Map<String, dynamic>>[];
      for (var i = 0; i < widget.orcamento.opcoesExtras.length; i++) {
        final opcao = widget.orcamento.opcoesExtras[i];
        
        // Pular opções extras que foram marcadas como "Não"
        final isNaoSelection = opcao.valorString == null && 
                               opcao.valorFloat1 == null && 
                               opcao.valorFloat2 == null;
        
        if (isNaoSelection) {
          continue;
        }
        
        final controllers = _opcaoExtraControllers[i];
        
        if (controllers == null || controllers.isEmpty) continue;

        final opcaoData = <String, dynamic>{
          'produtoOpcaoId': opcao.produtoOpcaoId,
        };

        switch (opcao.tipo) {
          case TipoOpcaoExtra.stringFloat:
            final valorFloat1Controller = controllers['valorFloat1'];
            if (valorFloat1Controller != null && valorFloat1Controller.text.isNotEmpty) {
              opcaoData['valorFloat1'] = double.parse(valorFloat1Controller.text.replaceAll(',', '.'));
            } else {
              opcaoData['valorFloat1'] = opcao.valorFloat1 ?? 0.0;
            }
            opcaoData['valorString'] = opcao.valorString;
            break;
          
          case TipoOpcaoExtra.floatFloat:
          case TipoOpcaoExtra.percentFloat:
            final valorFloat1Controller = controllers['valorFloat1'];
            final valorFloat2Controller = controllers['valorFloat2'];
            
            if (valorFloat1Controller != null && valorFloat1Controller.text.isNotEmpty) {
              opcaoData['valorFloat1'] = double.parse(valorFloat1Controller.text.replaceAll(',', '.'));
            } else {
              opcaoData['valorFloat1'] = opcao.valorFloat1 ?? 0.0;
            }
            
            if (valorFloat2Controller != null && valorFloat2Controller.text.isNotEmpty) {
              opcaoData['valorFloat2'] = double.parse(valorFloat2Controller.text.replaceAll(',', '.'));
            } else {
              opcaoData['valorFloat2'] = opcao.valorFloat2 ?? 0.0;
            }
            break;
        }

        opcoesExtras.add(opcaoData);
      }

      await _api.salvarAlmoxarifado(
        widget.orcamento.id,
        materiais,
        despesas,
        opcoesExtras,
      );

      await _api.finalizarAlmoxarifado(widget.orcamento.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Almoxarifado finalizado com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao finalizar: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todosPreenchidos = _todosOsCamposPreenchidos();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
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
            child: Container(
              constraints: const BoxConstraints(maxWidth: 700, maxHeight: 700),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
                  border: Border(
                    bottom: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Registro do Custo',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Orçamento #${widget.orcamento.numero} - ${widget.orcamento.cliente}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
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
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _loadingData
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : Form(
                  key: _formKey,
                  onChanged: () {
                    if (!_hasChanges) {
                      setState(() => _hasChanges = true);
                    }
                  },
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.isRealizado)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.lock_outline,
                                  size: 20,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Este orçamento já foi finalizado. Visualização apenas.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.orange.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        if (!widget.isRealizado)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 20,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Informe os valores efetivamente realizados para cada item',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 24),

                        if (widget.orcamento.materiais.isNotEmpty) ...[
                          Text(
                            'Materiais',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...List.generate(widget.orcamento.materiais.length, (index) {
                            final material = widget.orcamento.materiais[index];
                            final controller = _materialControllers[index];
                            final focusNode = _materialFocusNodes[index];
                            
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
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          material.materialNome,
                                          style: theme.textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    enabled: !widget.isRealizado,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'Custo',
                                      isDense: true,
                                      prefixText: 'R\$ ',
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                    ),
                                    validator: (v) {
                                      if (widget.isRealizado) return null;
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Informe o custo';
                                      }
                                      final value = double.tryParse(v.replaceAll(',', '.'));
                                      if (value == null || value < 0) {
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

                        if (widget.orcamento.despesasAdicionais.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(
                            'Despesas Adicionais',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...List.generate(widget.orcamento.despesasAdicionais.length, (index) {
                            final despesa = widget.orcamento.despesasAdicionais[index];
                            final controller = _despesaControllers[index];
                            final focusNode = _despesaFocusNodes[index];
                            
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
                                    despesa.descricao,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),

                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    enabled: !widget.isRealizado,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'Custo',
                                      isDense: true,
                                      prefixText: 'R\$ ',
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                    ),
                                    validator: (v) {
                                      if (widget.isRealizado) return null;
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Informe o custo';
                                      }
                                      final value = double.tryParse(v.replaceAll(',', '.'));
                                      if (value == null || value < 0) {
                                        return 'Custo inválido';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],

                        if (widget.orcamento.opcoesExtras.isNotEmpty) ...[

                        if (widget.orcamento.opcoesExtras.any((o) => 
                            o.valorString != null || o.valorFloat1 != null || o.valorFloat2 != null)) ...[
                          const SizedBox(height: 24),
                          Text(
                            'Outros',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...List.generate(widget.orcamento.opcoesExtras.length, (index) {
                            final opcao = widget.orcamento.opcoesExtras[index];
                            
                            final isNaoSelection = opcao.valorString == null && 
                                                   opcao.valorFloat1 == null && 
                                                   opcao.valorFloat2 == null;
                            
                            if (isNaoSelection) {
                              return const SizedBox();
                            }
                            
                            final controllers = _opcaoExtraControllers[index];
                            final focusNodes = _opcaoExtraFocusNodes[index];
                            
                            if (controllers == null || focusNodes == null) {
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
                                    opcao.nome,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  if (opcao.tipo == TipoOpcaoExtra.stringFloat) ...[
                                    if (opcao.valorString != null)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Text(
                                          opcao.valorString!,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ),
                                    TextFormField(
                                      controller: controllers['valorFloat1'],
                                      focusNode: focusNodes['valorFloat1'],
                                      enabled: !widget.isRealizado,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                                      ],
                                      decoration: const InputDecoration(
                                        labelText: 'Custo',
                                        isDense: true,
                                        prefixText: 'R\$ ',
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                      ),
                                      validator: (v) {
                                        if (widget.isRealizado) return null;
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Informe o custo';
                                        }
                                        final value = double.tryParse(v.replaceAll(',', '.'));
                                        if (value == null || value < 0) {
                                          return 'Custo inválido';
                                        }
                                        return null;
                                      },
                                    ),
                                  ] else if (opcao.tipo == TipoOpcaoExtra.floatFloat) ...[
                                    TextFormField(
                                      controller: controllers['valorFloat1'],
                                      focusNode: focusNodes['valorFloat1'],
                                      enabled: !widget.isRealizado,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                                      ],
                                      decoration: const InputDecoration(
                                        labelText: 'Tempo',
                                        isDense: true,
                                        suffixText: 'h',
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                      ),
                                      validator: (v) {
                                        if (widget.isRealizado) return null;
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Informe a quantidade';
                                        }
                                        final value = double.tryParse(v.replaceAll(',', '.'));
                                        if (value == null || value < 0) {
                                          return 'Custo inválido';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: controllers['valorFloat2'],
                                      focusNode: focusNodes['valorFloat2'],
                                      enabled: !widget.isRealizado,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                                      ],
                                      decoration: const InputDecoration(
                                        labelText: 'Custo',
                                        isDense: true,
                                        prefixText: 'R\$ ',
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                      ),
                                      validator: (v) {
                                        if (widget.isRealizado) return null;
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Informe o custo';
                                        }
                                        final value = double.tryParse(v.replaceAll(',', '.'));
                                        if (value == null || value < 0) {
                                          return 'Custo inválido';
                                        }
                                        return null;
                                      },
                                    ),
                                  ] else if (opcao.tipo == TipoOpcaoExtra.percentFloat) ...[
                                    TextFormField(
                                      controller: controllers['valorFloat1'],
                                      focusNode: focusNodes['valorFloat1'],
                                      enabled: !widget.isRealizado,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                                      ],
                                      decoration: const InputDecoration(
                                        labelText: 'Percentual',
                                        isDense: true,
                                        suffixText: '%',
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                      ),
                                      validator: (v) {
                                        if (widget.isRealizado) return null;
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Informe o percentual';
                                        }
                                        final value = double.tryParse(v.replaceAll(',', '.'));
                                        if (value == null || value < 0) {
                                          return 'Custo inválido';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: controllers['valorFloat2'],
                                      focusNode: focusNodes['valorFloat2'],
                                      enabled: !widget.isRealizado,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                                      ],
                                      decoration: const InputDecoration(
                                        labelText: 'Base de Cálculo',
                                        isDense: true,
                                        prefixText: 'R\$ ',
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                      ),
                                      validator: (v) {
                                        if (widget.isRealizado) return null;
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Informe a base de cálculo';
                                        }
                                        final value = double.tryParse(v.replaceAll(',', '.'));
                                        if (value == null || value < 0) {
                                          return 'Custo inválido';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            );
                            }),
                          ],
                        ],
                      ]
                    ),
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
                child: Row(
                  children: [
                    Expanded(
                      child: ExcludeFocus(
                        child: OutlinedButton(
                          onPressed: _saving ? null : () async {
                            final shouldClose = await _onWillPop();
                            if (shouldClose && context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                          child: Text(widget.isRealizado ? 'Fechar' : 'Cancelar'),
                        ),
                      ),
                    ),
                    if (!widget.isRealizado) ...[
                      const SizedBox(width: 12),
                      if (!todosPreenchidos)
                        Expanded(
                          child: ExcludeFocus(
                            child: ElevatedButton.icon(
                              onPressed: _saving ? null : _salvar,
                              icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save),
                              label: Text(_saving ? 'Salvando...' : 'Salvar'),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ExcludeFocus(
                            child: ElevatedButton.icon(
                              onPressed: _saving ? null : _finalizar,
                              icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check),
                              label: Text(_saving ? 'Finalizando...' : 'Finalizar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
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