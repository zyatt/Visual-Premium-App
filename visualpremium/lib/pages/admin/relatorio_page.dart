import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:visualpremium/data/orcamentos_repository.dart';
import '../../../theme.dart';

class RelatorioPage extends StatefulWidget {
  const RelatorioPage({super.key});

  @override
  State<RelatorioPage> createState() => _RelatoriosPageState();
}

class _RelatoriosPageState extends State<RelatorioPage> {
  final _api = OrcamentosApiRepository();
  bool _loading = true;
  List<Map<String, dynamic>> _relatorios = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRelatorios();
  }

  Future<void> _loadRelatorios() async {
    setState(() => _loading = true);
    try {
      final relatorios = await _api.fetchRelatoriosComparativos();
      
      if (!mounted) return;
      setState(() {
        _relatorios = relatorios;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar relatórios: $e')),
        );
      });
    }
  }

  Future<void> _abrirRelatorio(Map<String, dynamic> relatorio) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return _RelatorioDetalhadoDialog(relatorio: relatorio);
      },
    );
  }

  List<Map<String, dynamic>> get _filteredRelatorios {
    if (_searchQuery.isEmpty) {
      return _relatorios;
    }
    
    final query = _searchQuery.toLowerCase();
    return _relatorios.where((r) {
      final almox = r['almoxarifado'] as Map<String, dynamic>?;
      if (almox == null) return false;
      
      final orc = almox['orcamento'] as Map<String, dynamic>?;
      if (orc == null) return false;
      
      final cliente = orc['cliente'] as String? ?? '';
      final numero = orc['numero']?.toString() ?? '';
      
      return cliente.toLowerCase().contains(query) ||
          numero.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final filteredRelatorios = _filteredRelatorios;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadRelatorios,
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
                        Icons.analytics,
                        size: 32,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Relatórios Comparativos',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  ExcludeFocus(
                    child: IconButton(
                      onPressed: _loadRelatorios,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Atualizar',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Análise comparativa entre valores orçados e realizados',
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
                    hintText: 'Buscar relatórios',
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
              else if (filteredRelatorios.isEmpty)
                _EmptyState(hasSearch: _searchQuery.isNotEmpty)
              else
                ExcludeFocus(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredRelatorios.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final relatorio = filteredRelatorios[index];
                      return _RelatorioCard(
                        relatorio: relatorio,
                        currency: currency,
                        onTap: () => _abrirRelatorio(relatorio),
                      );
                    },
                  ),
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSearch ? Icons.search_off : Icons.analytics_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch
                  ? 'Nenhum relatório encontrado'
                  : 'Nenhum relatório gerado',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            if (!hasSearch) ...[
              const SizedBox(height: 8),
              Text(
                'Relatórios aparecerão após finalizar ',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RelatorioCard extends StatelessWidget {
  final Map<String, dynamic> relatorio;
  final NumberFormat currency;
  final VoidCallback onTap;

  const _RelatorioCard({
    required this.relatorio,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final almox = relatorio['almoxarifado'] as Map<String, dynamic>?;
    final orc = (almox?['orcamento'] as Map<String, dynamic>?) ?? {};
    final produto = (orc['produto'] as Map<String, dynamic>?) ?? {};
    
    final cliente = orc['cliente'] as String? ?? 'N/A';
    final numero = orc['numero'] as int? ?? 0;
    final produtoNome = produto['nome'] as String? ?? 'N/A';
    
    final diferencaTotal = (relatorio['diferencaTotal'] as num?)?.toDouble() ?? 0.0;
    final percentualTotal = (relatorio['percentualTotal'] as num?)?.toDouble() ?? 0.0;
    final totalOrcado = (relatorio['totalOrcado'] as num?)?.toDouble() ?? 0.0;
    final totalRealizado = (relatorio['totalRealizado'] as num?)?.toDouble() ?? 0.0;
    
    final isEconomia = diferencaTotal < 0;
    final isExcedeu = diferencaTotal > 0;
    final statusColor = isEconomia ? Colors.green : isExcedeu ? Colors.red : Colors.grey;
    final statusText = isEconomia ? 'Economia' : isExcedeu ? 'Excedeu' : 'Conforme';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(20),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Orçamento #$numero',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              statusText,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cliente,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 16,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          produtoNome,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Orçado',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                            Text(
                              currency.format(totalOrcado),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Realizado',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                            Text(
                              currency.format(totalRealizado),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Diferença',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                            Row(
                              children: [
                                Icon(
                                  isEconomia ? Icons.arrow_downward : isExcedeu ? Icons.arrow_upward : Icons.remove,
                                  size: 14,
                                  color: statusColor,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${percentualTotal.abs().toStringAsFixed(1)}%',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: statusColor,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Dialog de detalhes do relatório
class _RelatorioDetalhadoDialog extends StatelessWidget {
  final Map<String, dynamic> relatorio;

  const _RelatorioDetalhadoDialog({required this.relatorio});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    
    final almox = relatorio['almoxarifado'] as Map<String, dynamic>?;
    final orc = (almox?['orcamento'] as Map<String, dynamic>?) ?? {};
    final produto = (orc['produto'] as Map<String, dynamic>?) ?? {};
    
    final cliente = orc['cliente'] as String? ?? 'N/A';
    final numero = orc['numero'] as int? ?? 0;
    final produtoNome = produto['nome'] as String? ?? 'N/A';
    
    final analiseDetalhada = relatorio['analiseDetalhada'] as Map<String, dynamic>? ?? {};
    final materiais = (analiseDetalhada['materiais'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final despesas = (analiseDetalhada['despesas'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final opcoesExtrasRaw = (analiseDetalhada['opcoesExtras'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    
    // Filtrar opções extras que foram marcadas como "Não" (valorOrcado = 0 E valorRealizado = 0)
    final opcoesExtras = opcoesExtrasRaw.where((opcao) {
      final valorOrcado = (opcao['valorOrcado'] as num?)?.toDouble() ?? 0.0;
      final valorRealizado = (opcao['valorRealizado'] as num?)?.toDouble() ?? 0.0;
      
      // Só incluir se pelo menos um dos valores for diferente de zero
      return valorOrcado != 0.0 || valorRealizado != 0.0;
    }).toList();
    
    final totalOrcado = (relatorio['totalOrcado'] as num?)?.toDouble() ?? 0.0;
    final totalRealizado = (relatorio['totalRealizado'] as num?)?.toDouble() ?? 0.0;
    final diferencaTotal = (relatorio['diferencaTotal'] as num?)?.toDouble() ?? 0.0;
    final percentualTotal = (relatorio['percentualTotal'] as num?)?.toDouble() ?? 0.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 800),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          children: [
            // Header
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
                          'Relatório Comparativo',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Orçamento #$numero - $cliente',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        Text(
                          produtoNome,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ExcludeFocus(
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildResumoCard(theme, currency, totalOrcado, totalRealizado, diferencaTotal, percentualTotal),
                    const SizedBox(height: 24),
                    
                    if (materiais.isNotEmpty) ...[
                      Text(
                        'Materiais',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...materiais.map((m) => _buildMaterialCard(theme, currency, m)),
                      const SizedBox(height: 24),
                    ],
                    
                    if (despesas.isNotEmpty) ...[
                      Text(
                        'Despesas',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...despesas.map((d) => _buildDespesaCard(theme, currency, d)),
                      const SizedBox(height: 24),
                    ],
                    
                    if (opcoesExtras.isNotEmpty) ...[
                      Text(
                        'Outros',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...opcoesExtras.map((o) => _buildOpcaoExtraCard(theme, currency, o)),
                    ],
                  ],
                ),
              ),
            ),

            // Footer
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
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fechar'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumoCard(ThemeData theme, NumberFormat currency, double totalOrcado, 
      double totalRealizado, double diferencaTotal, double percentualTotal) {
    final isEconomia = diferencaTotal < 0;
    final isExcedeu = diferencaTotal > 0;
    final statusColor = isEconomia ? Colors.green : isExcedeu ? Colors.red : Colors.grey;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withValues(alpha: 0.1),
            statusColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildValueColumn(theme, 'Total Orçado', currency.format(totalOrcado), null),
              ),
              Container(
                width: 1,
                height: 40,
                color: theme.dividerColor.withValues(alpha: 0.2),
              ),
              Expanded(
                child: _buildValueColumn(theme, 'Total Realizado', currency.format(totalRealizado), null),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: theme.dividerColor.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isEconomia ? Icons.trending_down : isExcedeu ? Icons.trending_up : Icons.remove,
                color: statusColor,
                size: 32,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEconomia ? 'Economia' : isExcedeu ? 'Excedeu' : 'Conforme',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        currency.format(diferencaTotal.abs()),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${percentualTotal.abs().toStringAsFixed(1)}%)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildValueColumn(ThemeData theme, String label, String value, Color? color) {
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildMaterialCard(ThemeData theme, NumberFormat currency, Map<String, dynamic> material) {
    final nome = material['materialNome'] as String? ?? 'N/A';
    final valorOrcado = (material['valorOrcado'] as num?)?.toDouble() ?? 0.0;
    final custoRealizado = (material['custoRealizadoTotal'] as num?)?.toDouble() ?? 0.0;
    final diferenca = (material['diferenca'] as num?)?.toDouble() ?? 0.0;
    final percentual = (material['percentual'] as num?)?.toDouble() ?? 0.0;
    final status = material['status'] as String? ?? 'igual';
    
    final statusColor = status == 'abaixo' ? Colors.green : status == 'acima' ? Colors.red : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nome,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      status == 'abaixo' ? Icons.arrow_downward : status == 'acima' ? Icons.arrow_upward : Icons.remove,
                      size: 12,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${percentual.abs().toStringAsFixed(1)}%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Orçado',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    Text(
                      currency.format(valorOrcado),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Realizado',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    Text(
                      currency.format(custoRealizado),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Diferença',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    Text(
                      currency.format(diferenca.abs()),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDespesaCard(ThemeData theme, NumberFormat currency, Map<String, dynamic> despesa) {
    final descricao = despesa['descricao'] as String? ?? 'N/A';
    final valorOrcado = (despesa['valorOrcado'] as num?)?.toDouble() ?? 0.0;
    final valorRealizado = (despesa['valorRealizado'] as num?)?.toDouble() ?? 0.0;
    final diferenca = (despesa['diferenca'] as num?)?.toDouble() ?? 0.0;
    final percentual = (despesa['percentual'] as num?)?.toDouble() ?? 0.0;
    final status = despesa['status'] as String? ?? 'igual';
    
    final statusColor = status == 'abaixo' ? Colors.green : status == 'acima' ? Colors.red : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  descricao,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      status == 'abaixo' ? Icons.arrow_downward : status == 'acima' ? Icons.arrow_upward : Icons.remove,
                      size: 12,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${percentual.abs().toStringAsFixed(1)}%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Orçado',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    Text(
                      currency.format(valorOrcado),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Realizado',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    Text(
                      currency.format(valorRealizado),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Diferença',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    Text(
                      currency.format(diferenca.abs()),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOpcaoExtraCard(ThemeData theme, NumberFormat currency, Map<String, dynamic> opcaoExtra) {
    final nome = opcaoExtra['nome'] as String? ?? 'N/A';
    final valorOrcado = (opcaoExtra['valorOrcado'] as num?)?.toDouble() ?? 0.0;
    final valorRealizado = (opcaoExtra['valorRealizado'] as num?)?.toDouble() ?? 0.0;
    final diferenca = (opcaoExtra['diferenca'] as num?)?.toDouble() ?? 0.0;
    final percentual = (opcaoExtra['percentual'] as num?)?.toDouble() ?? 0.0;
    final status = opcaoExtra['status'] as String? ?? 'igual';
    
    final statusColor = status == 'abaixo' ? Colors.green : status == 'acima' ? Colors.red : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nome,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      status == 'abaixo' ? Icons.arrow_downward : status == 'acima' ? Icons.arrow_upward : Icons.remove,
                      size: 12,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${percentual.abs().toStringAsFixed(1)}%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Orçado',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    Text(
                      currency.format(valorOrcado),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Realizado',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    Text(
                      currency.format(valorRealizado),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Diferença',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    Text(
                      currency.format(diferenca.abs()),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}