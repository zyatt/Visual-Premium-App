import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:visualpremium/data/faixas_custo_repository.dart';
import '../../../theme.dart';
import '../../../routes.dart';

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
      builder: (context) => _FaixaEditor(
        faixa: faixa,
        faixasExistentes: _faixas,
      ),
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
          SnackBar(
            content: Text(faixa == null ? 'Faixa criada!' : 'Faixa atualizada!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deletar(Map<String, dynamic> faixa) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Excluir faixa?',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Esta ação não pode ser desfeita.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          side: BorderSide(
                            color: theme.dividerColor.withValues(alpha: 0.18),
                          ),
                          foregroundColor: theme.colorScheme.onSurface,
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
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

    if (confirm == true) {
      try {
        await _api.deletar(faixa['id']);
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Faixa excluída!'),
          behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  String _formatarFaixa(Map<String, dynamic> faixa) {
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final custoInicio = faixa['custoInicio'] as num;
    final custoFim = faixa['custoFim'] as num?;

    if (custoFim == null) {
      return 'De ${currency.format(custoInicio)} em diante';
    }

    return 'De ${currency.format(custoInicio)} até ${currency.format(custoFim)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          RefreshIndicator(
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
                          onPressed: () => context.go(AppRoutes.configuracoesAvancadas),
                          icon: const Icon(Icons.arrow_back),
                          tooltip: 'Voltar',
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
                        'Faixas de Custo e Margem',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showEditor(),
                        icon: const Icon(Icons.add),
                        label: const Text('Nova Faixa'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
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
                            'Configure as faixas de custo para aplicar margens diferentes automaticamente. ',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
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
                          Icon(
                            Icons.percent,
                            size: 64,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Nenhuma faixa configurada',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Clique em "Nova Faixa" para começar',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
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
                        final margem = faixa['margem'] as num;
                        
                        return InkWell(
                          onTap: () => _showEditor(faixa: faixa),
                          mouseCursor: SystemMouseCursors.click,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          splashColor: Colors.transparent,
                          hoverColor: theme.colorScheme.primary.withValues(alpha: 0.05),
                          focusColor: Colors.transparent,
                          child: Ink(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: theme.cardTheme.color,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: theme.dividerColor.withValues(alpha: 0.1),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
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
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 20),
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
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Margem: ${margem.toStringAsFixed(1)}%',
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            color: theme.colorScheme.onSecondaryContainer,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ExcludeFocus(
                                  child: IconButton(
                                    onPressed: () => _deletar(faixa),
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: theme.colorScheme.error,
                                    ),
                                    tooltip: 'Excluir faixa',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 32,
            right: 32,
            child: ExcludeFocus(
              child: IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Atualizar',
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

class _FaixaEditor extends StatefulWidget {
  final Map<String, dynamic>? faixa;
  final List<Map<String, dynamic>> faixasExistentes;

  const _FaixaEditor({
    this.faixa,
    required this.faixasExistentes,
  });

  @override
  State<_FaixaEditor> createState() => _FaixaEditorState();
}

class _FaixaEditorState extends State<_FaixaEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _custoInicioCtrl;
  late final TextEditingController _custoFimCtrl;
  late final TextEditingController _margemCtrl;
  bool _semLimite = false;

  @override
  void initState() {
    super.initState();
    _custoInicioCtrl = TextEditingController(
      text: widget.faixa?['custoInicio']?.toString() ?? '',
    );
    _custoFimCtrl = TextEditingController(
      text: widget.faixa?['custoFim']?.toString() ?? '',
    );
    _margemCtrl = TextEditingController(
      text: widget.faixa?['margem']?.toString() ?? '',
    );
    _semLimite = widget.faixa?['custoFim'] == null && widget.faixa != null;
  }

  @override
  void dispose() {
    _custoInicioCtrl.dispose();
    _custoFimCtrl.dispose();
    _margemCtrl.dispose();
    super.dispose();
  }

  bool _verificaSobreposicao(double inicio, double? fim) {
    final faixaAtualId = widget.faixa?['id'];
    
    for (final faixa in widget.faixasExistentes) {
      if (faixaAtualId != null && faixa['id'] == faixaAtualId) {
        continue;
      }
      
      final faixaInicio = (faixa['custoInicio'] as num).toDouble();
      final faixaFim = faixa['custoFim'] != null 
        ? (faixa['custoFim'] as num).toDouble() 
        : double.infinity;
      
      final fimAtual = fim ?? double.infinity;
      
      if (inicio >= faixaInicio && inicio <= faixaFim) {
        return true;
      }
      
      if (fimAtual >= faixaInicio && fimAtual <= faixaFim) {
        return true;
      }
      
      if (inicio < faixaInicio && fimAtual > faixaFim) {
        return true;
      }
    }
    
    return false;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final result = {
      'custoInicio': double.parse(_custoInicioCtrl.text.replaceAll(',', '.')),
      'custoFim': _semLimite ? null : double.parse(_custoFimCtrl.text.replaceAll(',', '.')),
      'margem': double.parse(_margemCtrl.text.replaceAll(',', '.')),
    };

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 550),
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.percent,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.faixa == null ? 'Nova Faixa' : 'Editar Faixa',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Defina a faixa de valores de custo e a margem de lucro que será aplicada automaticamente.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
               const SizedBox(height: 20),
              
              Container(
                decoration: BoxDecoration(
                  color: _semLimite 
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _semLimite
                      ? theme.colorScheme.primary.withValues(alpha: 0.3)
                      : theme.dividerColor.withValues(alpha: 0.2),
                  ),
                ),
                child: CheckboxListTile(
                  value: _semLimite,
                  onChanged: (value) {
                    setState(() {
                      _semLimite = value ?? false;
                      if (_semLimite) {
                        _custoFimCtrl.clear();
                      }
                    });
                  },
                  title: Row(
                    children: [
                      Icon(
                        Icons.all_inclusive,
                        size: 20,
                        color: _semLimite ? theme.colorScheme.primary : null,
                      ),
                      const SizedBox(width: 8),
                      const Text('Sem limite superior'),
                    ],
                  ),
                  subtitle: const Text('Aplica para valores "em diante"'),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              TextFormField(
                controller: _custoInicioCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Valor inicial (De)',
                  hintText: '0.00',
                  prefixIcon: const Icon(Icons.arrow_upward),
                  prefixText: 'R\$ ',
                  helperText: 'A partir de qual valor esta faixa começa',
                  helperMaxLines: 2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Informe o valor inicial';
                  }
                  final value = double.tryParse(v.replaceAll(',', '.'));
                  if (value == null || value < 0) {
                    return 'Valor inválido';
                  }
                  
                  final fim = _semLimite 
                    ? null 
                    : double.tryParse(_custoFimCtrl.text.replaceAll(',', '.'));
                  
                  if (_verificaSobreposicao(value, fim)) {
                    return 'Esta faixa sobrepõe uma faixa existente';
                  }
                  
                  return null;
                },
              ),
              
              const SizedBox(height: 20),
              
              if (!_semLimite)
                TextFormField(
                  controller: _custoFimCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Valor final (Até)',
                    hintText: '0.00',
                    prefixIcon: const Icon(Icons.arrow_downward),
                    prefixText: 'R\$ ',
                    helperText: 'Até qual valor esta faixa se aplica',
                    helperMaxLines: 2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) {
                    if (_semLimite) return null;
                    if (v == null || v.trim().isEmpty) {
                      return 'Informe o valor final';
                    }
                    final valorFim = double.tryParse(v.replaceAll(',', '.'));
                    if (valorFim == null || valorFim <= 0) {
                      return 'Valor inválido';
                    }
                    
                    final valorInicio = double.tryParse(_custoInicioCtrl.text.replaceAll(',', '.'));
                    if (valorInicio != null && valorFim <= valorInicio) {
                      return 'Deve ser maior que o valor inicial';
                    }
                    
                    if (valorInicio != null && _verificaSobreposicao(valorInicio, valorFim)) {
                      return 'Esta faixa sobrepõe uma faixa existente';
                    }
                    
                    return null;
                  },
                ),
              
              if (!_semLimite) const SizedBox(height: 20),
              
              TextFormField(
                controller: _margemCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Margem de lucro',
                  hintText: '0.0',
                  prefixIcon: const Icon(Icons.trending_up),
                  suffixText: '%',
                  helperText: 'Percentual sobre o preço final (mínimo 0)',
                  helperMaxLines: 2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Informe a margem';
                  }
                  final value = double.tryParse(v.replaceAll(',', '.'));
                  if (value == null || value < 0) {
                    return 'Margem deve ser maior ou igual a 0';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 28),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
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