import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:visualpremium/theme.dart';
import 'package:visualpremium/data/configuracao_preco_repository.dart';
import '../../../routes.dart';

class FormacaoPrecoPage extends StatefulWidget {
  const FormacaoPrecoPage({super.key});

  @override
  State<FormacaoPrecoPage> createState() => _FormacaoPrecoPageState();
}

class _FormacaoPrecoPageState extends State<FormacaoPrecoPage> {
  final _repository = ConfiguracaoPrecoRepository();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = true;
  bool _isSaving = false;

  final _faturamentoMedioController = TextEditingController();
  final _custoOperacionalController = TextEditingController();
  final _custoProdutivoController = TextEditingController();
  final _percentualComissaoController = TextEditingController();
  final _percentualImpostosController = TextEditingController();
  final _percentualJurosController = TextEditingController();
  final _markupPadraoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregarConfiguracao();
  }

  @override
  void dispose() {
    _faturamentoMedioController.dispose();
    _custoOperacionalController.dispose();
    _custoProdutivoController.dispose();
    _percentualComissaoController.dispose();
    _percentualImpostosController.dispose();
    _percentualJurosController.dispose();
    _markupPadraoController.dispose();
    super.dispose();
  }

  Future<void> _carregarConfiguracao() async {
    setState(() => _isLoading = true);
    
    try {
      final config = await _repository.obterConfig();
      
      _faturamentoMedioController.text = config['faturamentoMedio']?.toString() ?? '0';
      _custoOperacionalController.text = config['custoOperacional']?.toString() ?? '0';
      _custoProdutivoController.text = config['custoProdutivo']?.toString() ?? '';
      _percentualComissaoController.text = config['percentualComissao']?.toString() ?? '5.0';
      _percentualImpostosController.text = config['percentualImpostos']?.toString() ?? '12.0';
      _percentualJurosController.text = config['percentualJuros']?.toString() ?? '2.0';
      _markupPadraoController.text = config['markupPadrao']?.toString() ?? '40.0';
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar configuração: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _salvarConfiguracao() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await _repository.atualizarConfig({
        'faturamentoMedio': double.tryParse(_faturamentoMedioController.text) ?? 0,
        'custoOperacional': double.tryParse(_custoOperacionalController.text) ?? 0,
        'custoProdutivo': _custoProdutivoController.text.isEmpty 
            ? null 
            : double.tryParse(_custoProdutivoController.text),
        'percentualComissao': double.tryParse(_percentualComissaoController.text) ?? 5.0,
        'percentualImpostos': double.tryParse(_percentualImpostosController.text) ?? 12.0,
        'percentualJuros': double.tryParse(_percentualJurosController.text) ?? 2.0,
        'markupPadrao': double.tryParse(_markupPadraoController.text) ?? 40.0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuração salva com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
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
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Form(
          key: _formKey,
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
                    Icons.attach_money_outlined,
                    size: 32,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Formação de Preço',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 56),
                child: Text(
                  'Configure os parâmetros para cálculo automático de preços',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              _buildSection(
                theme,
                'Custos Operacionais',
                Icons.business_outlined,
                [
                  _buildTextField(
                    controller: _faturamentoMedioController,
                    label: 'Faturamento Médio (últimos 12 meses)',
                    prefix: 'R\$',
                    hint: 'Ex: 110000.00',
                  ),
                  _buildTextField(
                    controller: _custoOperacionalController,
                    label: 'Custo Operacional Total',
                    prefix: 'R\$',
                    hint: 'Despesas fixas + operacionais + colaboradores',
                  ),
                  _buildTextField(
                    controller: _custoProdutivoController,
                    label: 'Custo Produtivo (opcional)',
                    prefix: 'R\$',
                    hint: 'Soma dos salários dos colaboradores produtivos',
                    required: false,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              _buildSection(
                theme,
                'Percentuais sobre Venda',
                Icons.percent_outlined,
                [
                  _buildTextField(
                    controller: _percentualComissaoController,
                    label: 'Comissão de Venda',
                    suffix: '%',
                    hint: 'Ex: 5.0',
                  ),
                  _buildTextField(
                    controller: _percentualImpostosController,
                    label: 'Impostos sobre Venda',
                    suffix: '%',
                    hint: 'Ex: 12.0',
                  ),
                  _buildTextField(
                    controller: _percentualJurosController,
                    label: 'Juros a serem cobrados',
                    suffix: '%',
                    hint: 'Ex: 2.0',
                  ),
                ],
              ),

              const SizedBox(height: 24),

              _buildSection(
                theme,
                'Markup Padrão',
                Icons.trending_up_outlined,
                [
                  _buildTextField(
                    controller: _markupPadraoController,
                    label: 'Percentual de Markup Padrão',
                    suffix: '%',
                    hint: 'Ex: 40.0',
                    helperText: 'Markup é o índice multiplicador aplicado sobre o custo',
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.blue,
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Como funciona o cálculo?',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'O sistema utiliza o método de Custeio Direto. '
                            'Os percentuais sobre venda (comissão + impostos + juros) '
                            'são aplicados sobre o valor base. O markup é aplicado '
                            'posteriormente para definir o preço final.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.blue.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : _carregarConfiguracao,
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _salvarConfiguracao,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_isSaving ? 'Salvando...' : 'Salvar Configuração'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    ThemeData theme,
    String title,
    IconData icon,
    List<Widget> children,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? prefix,
    String? suffix,
    String? hint,
    String? helperText,
    bool required = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helperText,
          prefixText: prefix,
          suffixText: suffix,
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        ],
        validator: required
            ? (value) {
                if (value == null || value.isEmpty) {
                  return 'Campo obrigatório';
                }
                if (double.tryParse(value) == null) {
                  return 'Valor inválido';
                }
                if (double.parse(value) < 0) {
                  return 'Valor não pode ser negativo';
                }
                return null;
              }
            : null,
      ),
    );
  }
}