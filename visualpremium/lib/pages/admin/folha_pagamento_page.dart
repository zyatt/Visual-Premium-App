import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:visualpremium/theme.dart';
import 'package:visualpremium/data/configuracao_preco_repository.dart';
import '../../../routes.dart';

class FolhaPagamentoPage extends StatefulWidget {
  const FolhaPagamentoPage({super.key});

  @override
  State<FolhaPagamentoPage> createState() => _FolhaPagamentoPageState();
}

class _FolhaPagamentoPageState extends State<FolhaPagamentoPage> {
  final _repository = ConfiguracaoPrecoRepository();
  
  List<Map<String, dynamic>> _funcionarios = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarFolha();
  }

  Future<void> _carregarFolha() async {
    setState(() => _isLoading = true);
    
    try {
      final folha = await _repository.listarFolhaPagamento();
      setState(() {
        _funcionarios = folha;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar folha: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _mostrarDialogFuncionario({Map<String, dynamic>? funcionario}) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => _DialogFuncionario(funcionario: funcionario),
    );

    if (resultado == true) {
      _carregarFolha();
    }
  }

  Future<void> _deletarFuncionario(int id, String profissao) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja realmente excluir "$profissao"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    try {
      await _repository.deletarFolhaPagamento(id);
      _carregarFolha();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Funcionário excluído com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final totalFuncionarios = _funcionarios.fold<int>(
      0,
      (sum, f) => sum + (f['quantidade'] as int),
    );
    final totalFolha = _funcionarios.fold<double>(
      0.0,
      (sum, f) => sum + (f['totalComEncargos'] as num).toDouble(),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.go(AppRoutes.configuracoesAvancadas),
                  tooltip: 'Voltar',
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.people_outline,
                  size: 32,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Folha de Pagamento',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _mostrarDialogFuncionario(),
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar Funcionário'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 56),
              child: Text(
                'Gerencie a folha de pagamento para cálculo de custo produtivo',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  child: _buildResumoCard(
                    theme,
                    'Total de Funcionários',
                    totalFuncionarios.toString(),
                    Icons.people,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildResumoCard(
                    theme,
                    'Total da Folha',
                    'R\$ ${totalFolha.toStringAsFixed(2)}',
                    Icons.attach_money,
                    Colors.green,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            if (_funcionarios.isEmpty)
              Container(
                padding: const EdgeInsets.all(48),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhum funcionário cadastrado',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Clique em "Adicionar Funcionário" para começar',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.1),
                  ),
                ),
                child: DataTable(
                  headingRowHeight: 56,
                  dataRowMinHeight: 56,
                  dataRowMaxHeight: 56,
                  columns: const [
                    DataColumn(label: Text('Profissão')),
                    DataColumn(label: Text('Salário Base')),
                    DataColumn(label: Text('Quantidade')),
                    DataColumn(label: Text('Total com Encargos')),
                    DataColumn(label: Text('Tipo')),
                    DataColumn(label: Text('Ações')),
                  ],
                  rows: _funcionarios.map((func) {
                    return DataRow(
                      cells: [
                        DataCell(Text(func['profissao'])),
                        DataCell(Text('R\$ ${func['salarioBase'].toStringAsFixed(2)}')),
                        DataCell(Text(func['quantidade'].toString())),
                        DataCell(
                          Text(
                            'R\$ ${func['totalComEncargos'].toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataCell(
                          Chip(
                            label: Text(
                              func['ehProdutivo'] ? 'Produtivo' : 'Não Produtivo',
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: func['ehProdutivo']
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.1),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                onPressed: () => _mostrarDialogFuncionario(funcionario: func),
                                tooltip: 'Editar',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                onPressed: () => _deletarFuncionario(
                                  func['id'],
                                  func['profissao'],
                                ),
                                tooltip: 'Excluir',
                                color: Colors.red,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumoCard(
    ThemeData theme,
    String titulo,
    String valor,
    IconData icon,
    Color cor,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: cor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  valor,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
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

class _DialogFuncionario extends StatefulWidget {
  final Map<String, dynamic>? funcionario;

  const _DialogFuncionario({this.funcionario});

  @override
  State<_DialogFuncionario> createState() => _DialogFuncionarioState();
}

class _DialogFuncionarioState extends State<_DialogFuncionario> {
  final _formKey = GlobalKey<FormState>();
  final _repository = ConfiguracaoPrecoRepository();
  
  late final TextEditingController _profissaoController;
  late final TextEditingController _salarioBaseController;
  late final TextEditingController _quantidadeController;
  late final TextEditingController _totalComEncargosController;
  late bool _ehProdutivo;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _profissaoController = TextEditingController(
      text: widget.funcionario?['profissao'] ?? '',
    );
    _salarioBaseController = TextEditingController(
      text: widget.funcionario?['salarioBase']?.toString() ?? '',
    );
    _quantidadeController = TextEditingController(
      text: widget.funcionario?['quantidade']?.toString() ?? '',
    );
    _totalComEncargosController = TextEditingController(
      text: widget.funcionario?['totalComEncargos']?.toString() ?? '',
    );
    _ehProdutivo = widget.funcionario?['ehProdutivo'] ?? false;
  }

  @override
  void dispose() {
    _profissaoController.dispose();
    _salarioBaseController.dispose();
    _quantidadeController.dispose();
    _totalComEncargosController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final data = {
        'profissao': _profissaoController.text.trim(),
        'salarioBase': double.parse(_salarioBaseController.text),
        'quantidade': int.parse(_quantidadeController.text),
        'totalComEncargos': double.parse(_totalComEncargosController.text),
        'ehProdutivo': _ehProdutivo,
      };

      if (widget.funcionario == null) {
        await _repository.criarFolhaPagamento(data);
      } else {
        await _repository.atualizarFolhaPagamento(widget.funcionario!['id'], data);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdicao = widget.funcionario != null;

    return AlertDialog(
      title: Text(isEdicao ? 'Editar Funcionário' : 'Adicionar Funcionário'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _profissaoController,
                  decoration: const InputDecoration(
                    labelText: 'Profissão *',
                    hintText: 'Ex: Serralheiro',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Campo obrigatório';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _salarioBaseController,
                  decoration: const InputDecoration(
                    labelText: 'Salário Base *',
                    prefixText: 'R\$ ',
                    hintText: 'Ex: 2800.00',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Campo obrigatório';
                    }
                    if (double.tryParse(value) == null || double.parse(value) <= 0) {
                      return 'Valor deve ser maior que zero';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _quantidadeController,
                  decoration: const InputDecoration(
                    labelText: 'Quantidade *',
                    hintText: 'Ex: 2',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Campo obrigatório';
                    }
                    if (int.tryParse(value) == null || int.parse(value) <= 0) {
                      return 'Quantidade deve ser maior que zero';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _totalComEncargosController,
                  decoration: const InputDecoration(
                    labelText: 'Total com Encargos *',
                    prefixText: 'R\$ ',
                    hintText: 'Ex: 4480.00',
                    helperText: 'Incluir salário + encargos trabalhistas',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Campo obrigatório';
                    }
                    if (double.tryParse(value) == null || double.parse(value) <= 0) {
                      return 'Valor deve ser maior que zero';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('É colaborador produtivo?'),
                  subtitle: const Text(
                    'Marque se este colaborador trabalha diretamente na produção',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _ehProdutivo,
                  onChanged: (value) {
                    setState(() {
                      _ehProdutivo = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _salvar,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEdicao ? 'Salvar' : 'Adicionar'),
        ),
      ],
    );
  }
}