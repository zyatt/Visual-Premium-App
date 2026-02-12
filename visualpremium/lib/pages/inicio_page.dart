import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:visualpremium/providers/auth_provider.dart';
import 'package:visualpremium/providers/data_provider.dart';
import 'package:visualpremium/models/material_item.dart';
import 'package:visualpremium/models/product_item.dart';
import 'package:visualpremium/models/orcamento_item.dart';
import 'package:visualpremium/models/pedido_item.dart';
import 'package:visualpremium/theme.dart';
import 'package:visualpremium/components/welcome_toast.dart';

const double estoqueBaixo = 10;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  final _scrollController = ScrollController();
  bool _showScrollToTopButton = false;

  @override
  void initState() {
    super.initState();
    
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
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.shouldShowWelcome) {
        WelcomeToast.show(context, authProvider.currentUser!.nome);
        authProvider.markWelcomeAsShown();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final dataProvider = Provider.of<DataProvider>(context, listen: false);

      if (dataProvider.isLoaded && !dataProvider.isLoading) {
        dataProvider.refreshData();
      } else if (!dataProvider.isLoaded && !dataProvider.isLoading) {
        dataProvider.loadAllData();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleRefresh(DataProvider dataProvider) async {
    await dataProvider.refreshData();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DataProvider>(
      builder: (context, dataProvider, child) {
        if (dataProvider.error != null && !dataProvider.isLoaded) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Erro ao carregar dados',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  dataProvider.error!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: dataProvider.isLoading
                      ? null
                      : () => _handleRefresh(dataProvider),
                  icon: dataProvider.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(
                      dataProvider.isLoading ? 'Carregando...' : 'Tentar Novamente'),
                ),
              ],
            ),
          );
        }

        return _HomePageContent(
          materials: dataProvider.materials,
          products: dataProvider.products,
          orcamentos: dataProvider.orcamentos,
          pedidos: dataProvider.pedidos,
          isLoading: dataProvider.isLoading,
          onRefresh: () => _handleRefresh(dataProvider),
          scrollController: _scrollController,
          showScrollToTopButton: _showScrollToTopButton,
          onScrollToTop: _scrollToTop,
        );
      },
    );
  }
}

class _HomePageContent extends StatelessWidget {
  final List<MaterialItem> materials;
  final List<ProductItem> products;
  final List<OrcamentoItem> orcamentos;
  final List<PedidoItem> pedidos;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final ScrollController scrollController;
  final bool showScrollToTopButton;
  final VoidCallback onScrollToTop;

  const _HomePageContent({
    required this.materials,
    required this.products,
    required this.orcamentos,
    required this.pedidos,
    required this.isLoading,
    required this.onRefresh,
    required this.scrollController,
    required this.showScrollToTopButton,
    required this.onScrollToTop,
  });

  int get _totalOrcamentos => orcamentos.length;
  int get _orcamentosPendentes =>
      orcamentos.where((o) => o.status == 'Pendente').length;
  int get _orcamentosAprovados =>
      orcamentos.where((o) => o.status == 'Aprovado').length;
  int get _orcamentosNaoAprovados =>
      orcamentos.where((o) => o.status == 'Não Aprovado').length;

  int get _totalPedidos => pedidos.length;
  int get _pedidosEmAndamento =>
      pedidos.where((p) => p.status == 'Em Andamento').length;
  int get _pedidosConcluidos =>
      pedidos.where((p) => p.status == 'Concluído').length;
  int get _pedidosCancelados =>
      pedidos.where((p) => p.status == 'Cancelado').length;

  List<MaterialItem> get _materiaisBaixoEstoque {
    return materials.where((m) {
      final qty = double.tryParse(m.quantity) ?? 0;
      return qty < estoqueBaixo;
    }).toList();
  }

  List<OrcamentoItem> get _orcamentosRecentes {
    final sorted = List<OrcamentoItem>.from(orcamentos);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(5).toList();
  }

  List<PedidoItem> get _pedidosRecentes {
    final sorted = List<PedidoItem>.from(pedidos);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(5).toList();
  }

  List<MaterialItem> get _materiaisRecentes {
    final sorted = List<MaterialItem>.from(materials);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(5).toList();
  }

  List<ProductItem> get _produtosRecentes {
    final sorted = List<ProductItem>.from(products);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          RepaintBoundary(
            child: SingleChildScrollView(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(screenWidth < 600 ? 16 : screenWidth < 1200 ? 24 : 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.dashboard_outlined,
                        size: screenWidth < 600 ? 24 : 32,
                        color: theme.colorScheme.primary,
                      ),
                      SizedBox(width: screenWidth < 600 ? 8 : 12),
                      Expanded(
                        child: Text(
                          'Visão Geral',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: screenWidth < 600 ? 20 : screenWidth < 1200 ? 24 : 28,
                          ),
                        ),
                      ),
                      ExcludeFocus(
                        child: IconButton(
                          onPressed: isLoading ? null : onRefresh,
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Atualizar',
                        ),
                      )
                    ],
                  ),
                  SizedBox(height: screenWidth < 600 ? 16 : screenWidth < 1200 ? 24 : 32),
                  if (isLoading)
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
                  else ...[
                    Text(
                      'Orçamentos',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: screenWidth < 600 ? 14 : 16,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildOrcamentosStatsCards(theme, screenWidth),
                    
                    SizedBox(height: screenWidth < 600 ? 16 : screenWidth < 1200 ? 24 : 32),
                    
                    Text(
                      'Pedidos',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: screenWidth < 600 ? 14 : 16,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildPedidosStatsCards(theme, screenWidth),
                    
                    SizedBox(height: screenWidth < 600 ? 16 : screenWidth < 1200 ? 24 : 32),
                    
                    if (_materiaisBaixoEstoque.isNotEmpty) ...[
                      _buildLowStockWarning(theme, screenWidth),
                      SizedBox(height: screenWidth < 600 ? 16 : screenWidth < 1200 ? 24 : 32),
                    ],
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = constraints.maxWidth > 1600
                            ? 4
                            : constraints.maxWidth > 1200
                                ? 3
                                : constraints.maxWidth > 800
                                    ? 2
                                    : 1;

                        final cardHeight = screenHeight < 700 
                            ? 400.0 
                            : screenHeight < 900 
                                ? 450.0 
                                : 500.0;

                        final spacing = screenWidth < 600 ? 12.0 : screenWidth < 1200 ? 16.0 : 24.0;

                        return GridView.count(
                          crossAxisCount: crossAxisCount,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: spacing,
                          childAspectRatio: constraints.maxWidth / (cardHeight * crossAxisCount),
                          children: [
                            RepaintBoundary(child: _buildOrcamentosSection(theme, cardHeight)),
                            RepaintBoundary(child: _buildPedidosSection(theme, cardHeight)),
                            RepaintBoundary(child: _buildMateriaisSection(theme, cardHeight)),
                            RepaintBoundary(child: _buildProdutosSection(theme, cardHeight)),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isLoading)
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
          if (showScrollToTopButton)
            Positioned(
              right: screenWidth < 600 ? 16 : 32,
              bottom: screenWidth < 600 ? 16 : 32,
              child: AnimatedOpacity(
                opacity: showScrollToTopButton ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: FloatingActionButton(
                  onPressed: onScrollToTop,
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

  Widget _buildOrcamentosStatsCards(ThemeData theme, double screenWidth) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        final isMedium = constraints.maxWidth > 600;
        
        final children = [
          Expanded(
            child: RepaintBoundary(
              child: _StatCard(
                title: 'Total',
                value: _totalOrcamentos.toString(),
                icon: Icons.description_outlined,
                color: theme.colorScheme.primary,
                isCompact: screenWidth < 600,
              ),
            ),
          ),
          SizedBox(width: isWide ? 16 : 12, height: isWide ? 16 : 12),
          Expanded(
            child: RepaintBoundary(
              child: _StatCard(
                title: 'Pendentes',
                value: _orcamentosPendentes.toString(),
                icon: Icons.schedule,
                color: Colors.orange,
                isCompact: screenWidth < 600,
              ),
            ),
          ),
          SizedBox(width: isWide ? 16 : 12, height: isWide ? 16 : 12),
          Expanded(
            child: RepaintBoundary(
              child: _StatCard(
                title: 'Aprovados',
                value: _orcamentosAprovados.toString(),
                icon: Icons.check_circle_outline,
                color: Colors.green,
                isCompact: screenWidth < 600,
              ),
            ),
          ),
          SizedBox(width: isWide ? 16 : 12, height: isWide ? 16 : 12),
          Expanded(
            child: RepaintBoundary(
              child: _StatCard(
                title: 'Não Aprovados',
                value: _orcamentosNaoAprovados.toString(),
                icon: Icons.cancel_outlined,
                color: Colors.red,
                isCompact: screenWidth < 600,
              ),
            ),
          ),
        ];

        if (isWide) {
          return Row(children: children);
        } else if (isMedium) {
          return Column(
            children: [
              Row(children: [children[0], children[1], children[2]]),
              const SizedBox(height: 12),
              Row(children: [children[4], children[6]]),
            ],
          );
        } else {
          return Column(
            children: children.map((w) {
              if (w is SizedBox) return const SizedBox(height: 12);
              return w;
            }).toList(),
          );
        }
      },
    );
  }

  Widget _buildPedidosStatsCards(ThemeData theme, double screenWidth) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        final isMedium = constraints.maxWidth > 600;
        
        final children = [
          Expanded(
            child: RepaintBoundary(
              child: _StatCard(
                title: 'Total',
                value: _totalPedidos.toString(),
                icon: Icons.shopping_cart_outlined,
                color: theme.colorScheme.secondary,
                isCompact: screenWidth < 600,
              ),
            ),
          ),
          SizedBox(width: isWide ? 16 : 12, height: isWide ? 16 : 12),
          Expanded(
            child: RepaintBoundary(
              child: _StatCard(
                title: 'Em Andamento',
                value: _pedidosEmAndamento.toString(),
                icon: Icons.play_circle_outline,
                color: Colors.blue,
                isCompact: screenWidth < 600,
              ),
            ),
          ),
          SizedBox(width: isWide ? 16 : 12, height: isWide ? 16 : 12),
          Expanded(
            child: RepaintBoundary(
              child: _StatCard(
                title: 'Concluídos',
                value: _pedidosConcluidos.toString(),
                icon: Icons.check_circle_outline,
                color: Colors.green,
                isCompact: screenWidth < 600,
              ),
            ),
          ),
          SizedBox(width: isWide ? 16 : 12, height: isWide ? 16 : 12),
          Expanded(
            child: RepaintBoundary(
              child: _StatCard(
                title: 'Cancelados',
                value: _pedidosCancelados.toString(),
                icon: Icons.cancel_outlined,
                color: Colors.red,
                isCompact: screenWidth < 600,
              ),
            ),
          ),
        ];

        if (isWide) {
          return Row(children: children);
        } else if (isMedium) {
          return Column(
            children: [
              Row(children: [children[0], children[1], children[2]]),
              const SizedBox(height: 12),
              Row(children: [children[4], children[6]]),
            ],
          );
        } else {
          return Column(
            children: children.map((w) {
              if (w is SizedBox) return const SizedBox(height: 12);
              return w;
            }).toList(),
          );
        }
      },
    );
  }

  Widget _buildLowStockWarning(ThemeData theme, double screenWidth) {
    return RepaintBoundary(
      child: Container(
        padding: EdgeInsets.all(screenWidth < 600 ? 16 : 20),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: Colors.orange.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: screenWidth < 600 ? 24 : 28,
                ),
                SizedBox(width: screenWidth < 600 ? 8 : 12),
                Expanded(
                  child: Text(
                    'Materiais com Estoque Baixo',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: screenWidth < 600 ? 16 : 20,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: screenWidth < 600 ? 12 : 16),
            ...(_materiaisBaixoEstoque.map((material) {
              final qty = double.tryParse(material.quantity) ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${material.name} - Quantidade: ${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 1)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: screenWidth < 600 ? 12 : 14,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            })),
          ],
        ),
      ),
    );
  }

  Widget _buildOrcamentosSection(ThemeData theme, double cardHeight) {
    return _SectionCard(
      title: 'Orçamentos Recentes',
      icon: Icons.description_outlined,
      iconColor: theme.colorScheme.primary,
      height: cardHeight,
      child: _orcamentosRecentes.isEmpty
          ? _buildEmptyState(theme, 'Nenhum orçamento cadastrado')
          : ListView.builder(
              itemCount: _orcamentosRecentes.length,
              itemBuilder: (context, index) {
                return RepaintBoundary(
                  child: _OrcamentoItem(orcamento: _orcamentosRecentes[index]),
                );
              },
            ),
    );
  }

  Widget _buildPedidosSection(ThemeData theme, double cardHeight) {
    return _SectionCard(
      title: 'Pedidos Recentes',
      icon: Icons.shopping_cart_outlined,
      iconColor: theme.colorScheme.secondary,
      height: cardHeight,
      child: _pedidosRecentes.isEmpty
          ? _buildEmptyState(theme, 'Nenhum pedido cadastrado')
          : ListView.builder(
              itemCount: _pedidosRecentes.length,
              itemBuilder: (context, index) {
                return RepaintBoundary(
                  child: _PedidoItem(pedido: _pedidosRecentes[index]),
                );
              },
            ),
    );
  }

  Widget _buildMateriaisSection(ThemeData theme, double cardHeight) {
    return _SectionCard(
      title: 'Materiais Recentes',
      icon: Icons.construction,
      iconColor: theme.colorScheme.tertiary,
      height: cardHeight,
      child: _materiaisRecentes.isEmpty
          ? _buildEmptyState(theme, 'Nenhum material cadastrado')
          : ListView.builder(
              itemCount: _materiaisRecentes.length,
              itemBuilder: (context, index) {
                return RepaintBoundary(
                  child: _MaterialItem(material: _materiaisRecentes[index]),
                );
              },
            ),
    );
  }

  Widget _buildProdutosSection(ThemeData theme, double cardHeight) {
    return _SectionCard(
      title: 'Produtos Recentes',
      icon: Icons.inventory_2_outlined,
      iconColor: Colors.purple,
      height: cardHeight,
      child: _produtosRecentes.isEmpty
          ? _buildEmptyState(theme, 'Nenhum produto cadastrado')
          : ListView.builder(
              itemCount: _produtosRecentes.length,
              itemBuilder: (context, index) {
                return RepaintBoundary(
                  child: _ProductItem(product: _produtosRecentes[index]),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isCompact;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(isCompact ? 16 : 20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isCompact ? 8 : 10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: isCompact ? 20 : 24),
              ),
              const Spacer(),
            ],
          ),
          SizedBox(height: isCompact ? 12 : 16),
          Text(
            value,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: isCompact ? 28 : 32,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: isCompact ? 12 : 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  final double height;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _OrcamentoItem extends StatelessWidget {
  final OrcamentoItem orcamento;

  const _OrcamentoItem({required this.orcamento});

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
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final dateFormat = DateFormat('dd/MM/yyyy');
    final statusColor = _getStatusColor(orcamento.status);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector( 
        onTap: () {
        },
        child: Container(
          padding: const EdgeInsets.all(16),
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '#${orcamento.numero}',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      orcamento.cliente,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateFormat.format(orcamento.createdAt),
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
                    currency.format(orcamento.total),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      orcamento.status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
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

class _PedidoItem extends StatelessWidget {
  final PedidoItem pedido;

  const _PedidoItem({required this.pedido});

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
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final dateFormat = DateFormat('dd/MM/yyyy');
    final statusColor = _getStatusColor(pedido.status);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
        },
        child: Container(
          padding: const EdgeInsets.all(16),
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    pedido.numero != null ? '#${pedido.numero}' : '-',
                    style: TextStyle(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pedido.cliente,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateFormat.format(pedido.createdAt),
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
                    currency.format(pedido.total),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      pedido.status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
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

class _MaterialItem extends StatelessWidget {
  final MaterialItem material;

  const _MaterialItem({required this.material});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final qty = double.tryParse(material.quantity) ?? 0;
    final isLowStock = qty < 10;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
        },
        child: Container(
          padding: const EdgeInsets.all(16),
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
                  color: theme.colorScheme.tertiary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.construction,
                  color: theme.colorScheme.tertiary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isLowStock) ...[
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            material.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Qtd: ${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 1)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                currency.format(material.costCents / 100.0),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductItem extends StatelessWidget {
  final ProductItem product;

  const _ProductItem({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
        },
        child: Container(
          padding: const EdgeInsets.all(16),
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
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: Colors.purple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${product.materials.length} ${product.materials.length == 1 ? 'material' : 'materiais'}',
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
  }
}