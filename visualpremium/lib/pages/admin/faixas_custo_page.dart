import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:visualpremium/data/faixas_custo_repository.dart';
import '../../../theme.dart';

class FaixasCustoPage extends StatefulWidget {
  const FaixasCustoPage({super.key});

  @override
  State<FaixasCustoPage> createState() => _FaixasCustoPageState();
}

class _FaixasCustoPageState extends State<FaixasCustoPage> {
  final _api = FaixasCustoRepository();
  bool _loading = true;
  List<Map<String, dynamic>> _faixas = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final faixas = await _api.listar();
      if (!mounted) return;
      setState(() {
        _faixas = faixas;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar faixas: $e')),
      );
    }
  }

  Future<void> _showEditor({Map<String, dynamic>? faixa}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _FaixaEditor(faixa: faixa),
    );

    if (result != null) {
      try {
        if (faixa == null) {
          await _api.criar(result);
        } else {
          await _api.atualizar(faixa['id'], result);
        }
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(faixa == null ? 'Faixa criada' : 'Faixa atualizada')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  Future<void> _deletar(Map<String, dynamic> faixa) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir faixa?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _api.deletar(faixa['id']);
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Faixa excluída')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  String _formatarFaixa(Map<String, dynamic> faixa) {
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final custoAte = faixa['custoAte'] as num?;

    if (custoAte == null) {
      if (_faixas.length > 1) {
        final anterior = _faixas[_faixas.length - 2]['custoAte'] as num?;
        if (anterior != null) {
          return 'Acima de ${currency.format(anterior)}';
        }
      }
      return 'Acima de R\$ 0,00';
    }

    return 'Até ${currency.format(custoAte)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ExcludeFocus(
                    child: IconButton(
                      onPressed: () => context.go('/admin'),
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Voltar para Admin',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.percent,
                    size: 32,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Faixas de Custo e Markup',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => _showEditor(),
                    icon: const Icon(Icons.add),
                    label: const Text('Nova Faixa'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_faixas.isEmpty)
                Container(
                  padding: const EdgeInsets.all(48),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(Icons.percent, size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhuma faixa configurada',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _faixas.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final faixa = _faixas[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
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
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatarFaixa(faixa),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Markup: ${faixa['markup']}%',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _showEditor(faixa: faixa),
                            icon: const Icon(Icons.edit),
                            tooltip: 'Editar',
                          ),
                          IconButton(
                            onPressed: () => _deletar(faixa),
                            icon: Icon(Icons.delete, color: theme.colorScheme.error),
                            tooltip: 'Excluir',
                          ),
                        ],
                      ),
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

class _FaixaEditor extends StatefulWidget {
  final Map<String, dynamic>? faixa;

  const _FaixaEditor({this.faixa});

  @override
  State<_FaixaEditor> createState() => _FaixaEditorState();
}

class _FaixaEditorState extends State<_FaixaEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _custoCtrl;
  late final TextEditingController _markupCtrl;
  bool _semLimite = false;

  @override
  void initState() {
    super.initState();
    _custoCtrl = TextEditingController(
      text: widget.faixa?['custoAte']?.toString() ?? '',
    );
    _markupCtrl = TextEditingController(
      text: widget.faixa?['markup']?.toString() ?? '',
    );
    _semLimite = widget.faixa?['custoAte'] == null;
  }

  @override
  void dispose() {
    _custoCtrl.dispose();
    _markupCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final result = {
      'custoAte': _semLimite ? null : double.parse(_custoCtrl.text.replaceAll(',', '.')),
      'markup': double.parse(_markupCtrl.text.replaceAll(',', '.')),
    };

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.faixa == null ? 'Nova Faixa' : 'Editar Faixa',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 24),
              
              CheckboxListTile(
                value: _semLimite,
                onChanged: (value) {
                  setState(() {
                    _semLimite = value ?? false;
                    if (_semLimite) {
                      _custoCtrl.clear();
                    }
                  });
                },
                title: const Text('Sem limite superior (acima de X)'),
                contentPadding: EdgeInsets.zero,
              ),
              
              const SizedBox(height: 16),
              
              if (!_semLimite)
                TextFormField(
                  controller: _custoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Custo até',
                    prefixText: 'R\$ ',
                  ),
                  validator: (v) {
                    if (_semLimite) return null;
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
              
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _markupCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Markup',
                  suffixText: '%',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Informe o markup';
                  }
                  final value = double.tryParse(v.replaceAll(',', '.'));
                  if (value == null || value < 0) {
                    return 'Valor inválido';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 24),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      child: const Text('Salvar'),
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