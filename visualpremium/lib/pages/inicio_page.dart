import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:visualpremium/providers/auth_provider.dart';
import 'package:visualpremium/providers/data_provider.dart';
import 'package:visualpremium/models/material_item.dart';
import 'package:visualpremium/models/product_item.dart';
import 'package:visualpremium/models/orcamento_item.dart';
import 'package:visualpremium/models/pedido_item.dart';
import 'package:visualpremium/routes.dart';
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

  // Notifiers aqui no State para sobreviver a rebuilds do Consumer
  final _activeOrcamentoCard = ValueNotifier<_OrcamentoStatCardState?>(null);
  final _activePedidoCard = ValueNotifier<_PedidoStatCardState?>(null);

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      if (_scrollController.offset >= 300 && !_showScrollToTopButton) {
        setState(() => _showScrollToTopButton = true);
      } else if (_scrollController.offset < 300 && _showScrollToTopButton) {
        setState(() => _showScrollToTopButton = false);
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
    _activeOrcamentoCard.dispose();
    _activePedidoCard.dispose();
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
                  label: Text(dataProvider.isLoading
                      ? 'Carregando...'
                      : 'Tentar Novamente'),
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
          activeOrcamentoCard: _activeOrcamentoCard,
          activePedidoCard: _activePedidoCard,
        );
      },
    );
  }
}

// =============================================================================
// _HomePageContent
// =============================================================================

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
  final ValueNotifier<_OrcamentoStatCardState?> activeOrcamentoCard;
  final ValueNotifier<_PedidoStatCardState?> activePedidoCard;

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
    required this.activeOrcamentoCard,
    required this.activePedidoCard,
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
      pedidos.where((p) => p.status == 'Pendente').length;
  int get _pedidosConcluidos =>
      pedidos.where((p) => p.status == 'Concluído').length;
 
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
              padding: EdgeInsets.all(
                  screenWidth < 600 ? 16 : screenWidth < 1200 ? 24 : 32),
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
                            fontSize: screenWidth < 600
                                ? 20
                                : screenWidth < 1200
                                    ? 24
                                    : 28,
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
                  SizedBox(
                      height:
                          screenWidth < 600 ? 16 : screenWidth < 1200 ? 24 : 32),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2),
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
                    SizedBox(
                        height: screenWidth < 600
                            ? 16
                            : screenWidth < 1200
                                ? 24
                                : 32),
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
                    SizedBox(
                        height: screenWidth < 600
                            ? 16
                            : screenWidth < 1200
                                ? 24
                                : 32),
                    if (_materiaisBaixoEstoque.isNotEmpty) ...[
                      _buildLowStockWarning(theme, screenWidth),
                      SizedBox(
                          height: screenWidth < 600
                              ? 16
                              : screenWidth < 1200
                                  ? 24
                                  : 32),
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

                        final spacing = screenWidth < 600
                            ? 12.0
                            : screenWidth < 1200
                                ? 16.0
                                : 24.0;

                        return GridView.count(
                          crossAxisCount: crossAxisCount,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: spacing,
                          childAspectRatio: constraints.maxWidth /
                              (cardHeight * crossAxisCount),
                          children: [
                            RepaintBoundary(
                                child:
                                    _buildOrcamentosSection(theme, cardHeight)),
                            RepaintBoundary(
                                child: _buildPedidosSection(theme, cardHeight)),
                            RepaintBoundary(
                                child:
                                    _buildMateriaisSection(theme, cardHeight)),
                            RepaintBoundary(
                                child: _buildProdutosSection(theme, cardHeight)),
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
                  backgroundColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          if (showScrollToTopButton)
            Positioned(
              right: 24,
              bottom: 100,
              child: AnimatedOpacity(
                opacity: showScrollToTopButton ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: FloatingActionButton(
                  mini: false,
                  onPressed: onScrollToTop,
                  tooltip: 'Voltar ao topo',
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
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
        final spacing = isWide ? 16.0 : 12.0;

        final cards = [
          RepaintBoundary(
            child: _OrcamentoStatCard(
              title: 'Total',
              value: _totalOrcamentos.toString(),
              icon: Icons.description_outlined,
              color: theme.colorScheme.primary,
              isCompact: screenWidth < 600,
              orcamentos: List.from(orcamentos),
              activeCardNotifier: activeOrcamentoCard,
            ),
          ),
          RepaintBoundary(
            child: _OrcamentoStatCard(
              title: 'Pendentes',
              value: _orcamentosPendentes.toString(),
              icon: Icons.schedule,
              color: Colors.orange,
              isCompact: screenWidth < 600,
              orcamentos:
                  orcamentos.where((o) => o.status == 'Pendente').toList(),
              activeCardNotifier: activeOrcamentoCard,
            ),
          ),
          RepaintBoundary(
            child: _OrcamentoStatCard(
              title: 'Aprovados',
              value: _orcamentosAprovados.toString(),
              icon: Icons.check_circle_outline,
              color: Colors.green,
              isCompact: screenWidth < 600,
              orcamentos:
                  orcamentos.where((o) => o.status == 'Aprovado').toList(),
              activeCardNotifier: activeOrcamentoCard,
            ),
          ),
          RepaintBoundary(
            child: _OrcamentoStatCard(
              title: 'Não Aprovados',
              value: _orcamentosNaoAprovados.toString(),
              icon: Icons.cancel_outlined,
              color: Colors.red,
              isCompact: screenWidth < 600,
              orcamentos:
                  orcamentos.where((o) => o.status == 'Não Aprovado').toList(),
              activeCardNotifier: activeOrcamentoCard,
            ),
          ),
        ];

        if (isWide) {
          return Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) SizedBox(width: spacing),
                Expanded(child: cards[i]),
              ],
            ],
          );
        } else if (isMedium) {
          return Column(
            children: [
              Row(children: [
                Expanded(child: cards[0]),
                SizedBox(width: spacing),
                Expanded(child: cards[1]),
              ]),
              SizedBox(height: spacing),
              Row(children: [
                Expanded(child: cards[2]),
                SizedBox(width: spacing),
                Expanded(child: cards[3]),
              ]),
            ],
          );
        } else {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) SizedBox(height: spacing),
                cards[i],
              ],
            ],
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
        final spacing = isWide ? 16.0 : 12.0;

        final cards = [
          RepaintBoundary(
            child: _PedidoStatCard(
              title: 'Total',
              value: _totalPedidos.toString(),
              icon: Icons.shopping_cart_outlined,
              color: theme.colorScheme.secondary,
              isCompact: screenWidth < 600,
              pedidos: List.from(pedidos),
              activeCardNotifier: activePedidoCard,
            ),
          ),
          RepaintBoundary(
            child: _PedidoStatCard(
              title: 'Pendente',
              value: _pedidosEmAndamento.toString(),
              icon: Icons.schedule,
              color: Colors.blue,
              isCompact: screenWidth < 600,
              pedidos: pedidos.where((p) => p.status == 'Pendente').toList(),
              activeCardNotifier: activePedidoCard,
            ),
          ),
          RepaintBoundary(
            child: _PedidoStatCard(
              title: 'Concluídos',
              value: _pedidosConcluidos.toString(),
              icon: Icons.check_circle_outline,
              color: Colors.green,
              isCompact: screenWidth < 600,
              pedidos: pedidos.where((p) => p.status == 'Concluído').toList(),
              activeCardNotifier: activePedidoCard,
            ),
          ),
        ];

        if (isWide) {
          return Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) SizedBox(width: spacing),
                Expanded(child: cards[i]),
              ],
            ],
          );
        } else if (isMedium) {
          return Column(
            children: [
              Row(children: [
                Expanded(child: cards[0]),
                SizedBox(width: spacing),
                Expanded(child: cards[1]),
              ]),
              SizedBox(height: spacing),
              Row(children: [
                Expanded(child: cards[2]),
              ]),
            ],
          );
        } else {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) SizedBox(height: spacing),
                cards[i],
              ],
            ],
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
                    Icon(Icons.circle, size: 8, color: Colors.orange.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${material.name} - Quantidade: ${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 1)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: screenWidth < 600 ? 12 : 14,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.8),
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
              itemBuilder: (context, index) => RepaintBoundary(
                child: _OrcamentoItem(orcamento: _orcamentosRecentes[index]),
              ),
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
              itemBuilder: (context, index) => RepaintBoundary(
                child: _PedidoItem(pedido: _pedidosRecentes[index]),
              ),
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
              itemBuilder: (context, index) => RepaintBoundary(
                child: _MaterialItem(material: _materiaisRecentes[index]),
              ),
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
              itemBuilder: (context, index) => RepaintBoundary(
                child: _ProductItem(product: _produtosRecentes[index]),
              ),
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

// =============================================================================
// _OrcamentoStatCard — hover estável + múltiplos popups simultâneos
// =============================================================================

class _OrcamentoStatCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isCompact;
  final List<OrcamentoItem> orcamentos;
  final ValueNotifier<_OrcamentoStatCardState?> activeCardNotifier;

  const _OrcamentoStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.orcamentos,
    required this.activeCardNotifier,
    this.isCompact = false,
  });

  @override
  State<_OrcamentoStatCard> createState() => _OrcamentoStatCardState();
}

class _OrcamentoStatCardState extends State<_OrcamentoStatCard>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _overlayEntry;
  bool _isHovered = false;
  bool _isPinned = false;
  bool _mouseOnCard = false;
  bool _mouseOnPopup = false;

  double _cardWidth = 0;

  final LayerLink _layerLink = LayerLink();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.06),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _removeOverlay();
    _animController.dispose();
    super.dispose();
  }

  // ── Overlay lifecycle ────────────────────────────────────────────────────

  void _showOverlay({bool pinning = false}) {
    final prev = widget.activeCardNotifier.value;

    // Se outro card está pinado e estamos apenas com hover, não abre
    if (!pinning && prev != null && prev != this && prev._isPinned) return;

    // Se há outro card aberto (pinado ou não), fecha ele
    if (prev != null && prev != this) {
      prev._isPinned = false;
      prev._mouseOnCard = false;
      prev._mouseOnPopup = false;
      prev._removeOverlay();
      if (prev.mounted) prev.setState(() {});
    }

    if (_overlayEntry != null) return;
    widget.activeCardNotifier.value = this;

    final overlay = Overlay.of(context, rootOverlay: true);
    _overlayEntry = OverlayEntry(builder: (_) => _buildOverlayWidget());
    overlay.insert(_overlayEntry!);
    _animController.forward(from: 0);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (widget.activeCardNotifier.value == this) {
      widget.activeCardNotifier.value = null;
    }
  }

  Future<void> _hideOverlay() async {
    if (_overlayEntry == null) return;
    await _animController.reverse();
    _removeOverlay();
  }

  void _scheduleHide() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      if (!_mouseOnCard && !_mouseOnPopup && !_isPinned) {
        _hideOverlay().then((_) {
          if (mounted) setState(() {});
        });
      }
    });
  }

  // ── Build do overlay ─────────────────────────────────────────────────────

  Widget _buildOverlayWidget() {
    return Positioned(
      width: _cardWidth > 0 ? _cardWidth : null,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: TapRegion(
                groupId: _layerLink,
                onTapOutside: (_) {
                  if (mounted) {
                    setState(() {
                      _isPinned = false;
                      _mouseOnCard = false;
                      _mouseOnPopup = false;
                    });
                  }
                  _hideOverlay();
                },
                child: MouseRegion(
                  onEnter: (_) => _mouseOnPopup = true,
                  onExit: (_) {
                    _mouseOnPopup = false;
                    _scheduleHide();
                  },
                  child: _buildPopupContent(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopupContent() {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final dateFormat = DateFormat('dd/MM/yy');

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 320),
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: widget.color.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: widget.color.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.1),
                  border: Border(
                    bottom: BorderSide(
                      color: widget.color.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(widget.icon, color: widget.color, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: widget.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${widget.orcamentos.length}',
                        style: TextStyle(
                          color: widget.color,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),

                  ],
                ),
              ),
              // Lista
              if (widget.orcamentos.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Nenhum orçamento',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: widget.orcamentos.length,
                    itemBuilder: (_, i) {
                      final orc = widget.orcamentos[i];
                      final Color statusColor;
                      switch (orc.status) {
                        case 'Aprovado':
                          statusColor = Colors.green;
                          break;
                        case 'Não Aprovado':
                          statusColor = Colors.red;
                          break;
                        default:
                          statusColor = Colors.orange;
                      }
                      return _OrcamentoPopupItem(
                        orcamento: orc,
                        statusColor: statusColor,
                        currency: currency,
                        dateFormat: dateFormat,
                        accentColor: widget.color,
                        onTap: () {
                          setState(() {
                            _isPinned = false;
                            _mouseOnPopup = false;
                            _mouseOnCard = false;
                          });
                          _hideOverlay();
                          context.go(AppRoutes.orcamentos, extra: orc.id);
                        },
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

  // ── Build do card ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool highlighted = _isHovered || _isPinned;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        _mouseOnCard = true;
        _isHovered = true;
        _showOverlay(pinning: false);
        setState(() {});
      },
      onExit: (_) {
        _mouseOnCard = false;
        _isHovered = false;
        setState(() {});
        if (!_isPinned) _scheduleHide();
      },
      child: TapRegion(
        groupId: _layerLink,
        child: GestureDetector(
        onTap: () {
          setState(() => _isPinned = true);
          _showOverlay(pinning: true);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_cardWidth != constraints.maxWidth) {
                _cardWidth = constraints.maxWidth;
              }
            });
            return CompositedTransformTarget(
              link: _layerLink,
              child: Container(
                padding: EdgeInsets.all(widget.isCompact ? 16 : 20),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: highlighted
                        ? widget.color.withValues(alpha: 0.5)
                        : theme.dividerColor.withValues(alpha: 0.1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: highlighted
                          ? widget.color.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.03),
                      blurRadius: highlighted ? 16 : 10,
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
                          padding:
                              EdgeInsets.all(widget.isCompact ? 8 : 10),
                          decoration: BoxDecoration(
                            color: widget.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            widget.icon,
                            color: widget.color,
                            size: widget.isCompact ? 20 : 24,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                    SizedBox(height: widget.isCompact ? 12 : 16),
                    Text(
                      widget.value,
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: widget.isCompact ? 28 : 32,
                        color: widget.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: widget.isCompact ? 12 : 14,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
    );
  }
}

class _OrcamentoPopupItem extends StatefulWidget {
  final OrcamentoItem orcamento;
  final Color statusColor;
  final Color accentColor;
  final NumberFormat currency;
  final DateFormat dateFormat;
  final VoidCallback onTap;

  const _OrcamentoPopupItem({
    required this.orcamento,
    required this.statusColor,
    required this.accentColor,
    required this.currency,
    required this.dateFormat,
    required this.onTap,
  });

  @override
  State<_OrcamentoPopupItem> createState() => _OrcamentoPopupItemState();
}

class _OrcamentoPopupItemState extends State<_OrcamentoPopupItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orc = widget.orcamento;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.accentColor.withValues(alpha: 0.08)
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.07),
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '#${orc.numero}',
                    style: TextStyle(
                      color: widget.accentColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      orc.cliente,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.dateFormat.format(orc.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.currency.format(orc.total),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: widget.accentColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: widget.statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      orc.status,
                      style: TextStyle(
                        color: widget.statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 14,
                color: _hovered
                    ? widget.accentColor
                    : theme.colorScheme.onSurface.withValues(alpha: 0.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _PedidoStatCard — hover estável + popup com largura do card
// =============================================================================

class _PedidoStatCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isCompact;
  final List<PedidoItem> pedidos;
  final ValueNotifier<_PedidoStatCardState?> activeCardNotifier;

  const _PedidoStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.pedidos,
    required this.activeCardNotifier,
    this.isCompact = false,
  });

  @override
  State<_PedidoStatCard> createState() => _PedidoStatCardState();
}

class _PedidoStatCardState extends State<_PedidoStatCard>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _overlayEntry;
  bool _isHovered = false;
  bool _isPinned = false;
  bool _mouseOnCard = false;
  bool _mouseOnPopup = false;

  double _cardWidth = 0;

  final LayerLink _layerLink = LayerLink();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.06),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _removeOverlay();
    _animController.dispose();
    super.dispose();
  }

  void _showOverlay({bool pinning = false}) {
    final prev = widget.activeCardNotifier.value;
    if (!pinning && prev != null && prev != this && prev._isPinned) return;
    if (prev != null && prev != this) {
      prev._isPinned = false;
      prev._mouseOnCard = false;
      prev._mouseOnPopup = false;
      prev._removeOverlay();
      if (prev.mounted) prev.setState(() {});
    }
    if (_overlayEntry != null) return;
    widget.activeCardNotifier.value = this;
    final overlay = Overlay.of(context, rootOverlay: true);
    _overlayEntry = OverlayEntry(builder: (_) => _buildOverlayWidget());
    overlay.insert(_overlayEntry!);
    _animController.forward(from: 0);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (widget.activeCardNotifier.value == this) {
      widget.activeCardNotifier.value = null;
    }
  }

  Future<void> _hideOverlay() async {
    if (_overlayEntry == null) return;
    await _animController.reverse();
    _removeOverlay();
  }

  void _scheduleHide() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      if (!_mouseOnCard && !_mouseOnPopup && !_isPinned) {
        _hideOverlay().then((_) {
          if (mounted) setState(() {});
        });
      }
    });
  }

  Widget _buildOverlayWidget() {
    return Positioned(
      width: _cardWidth > 0 ? _cardWidth : null,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 340),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: TapRegion(
                groupId: _layerLink,
                onTapOutside: (_) {
                  if (mounted) {
                    setState(() {
                      _isPinned = false;
                      _mouseOnCard = false;
                      _mouseOnPopup = false;
                    });
                  }
                  _hideOverlay();
                },
                child: MouseRegion(
                  onEnter: (_) => _mouseOnPopup = true,
                  onExit: (_) {
                    _mouseOnPopup = false;
                    _scheduleHide();
                  },
                  child: _buildPopupContent(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopupContent() {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final dateFormat = DateFormat('dd/MM/yy');

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 340),
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: widget.color.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: widget.color.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.1),
                  border: Border(
                    bottom: BorderSide(
                      color: widget.color.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(widget.icon, color: widget.color, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: widget.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${widget.pedidos.length}',
                        style: TextStyle(
                          color: widget.color,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.pedidos.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Nenhum pedido',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: widget.pedidos.length,
                    itemBuilder: (_, i) {
                      final pedido = widget.pedidos[i];
                      final Color statusColor;
                      switch (pedido.status) {
                        case 'Concluído':
                          statusColor = Colors.green;
                          break;
                        case 'Cancelado':
                          statusColor = Colors.red;
                          break;
                        default:
                          statusColor = Colors.blue;
                      }
                      return _PedidoPopupItem(
                        pedido: pedido,
                        statusColor: statusColor,
                        currency: currency,
                        dateFormat: dateFormat,
                        accentColor: widget.color,
                        onTap: () {
                          setState(() {
                            _isPinned = false;
                            _mouseOnPopup = false;
                            _mouseOnCard = false;
                          });
                          _hideOverlay();
                          context.go(AppRoutes.pedidos, extra: pedido.id);
                        },
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool highlighted = _isHovered || _isPinned;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        _mouseOnCard = true;
        _isHovered = true;
        _showOverlay(pinning: false);
        setState(() {});
      },
      onExit: (_) {
        _mouseOnCard = false;
        _isHovered = false;
        setState(() {});
        if (!_isPinned) _scheduleHide();
      },
      child: TapRegion(
        groupId: _layerLink,
        child: GestureDetector(
          onTap: () {
            setState(() => _isPinned = true);
            _showOverlay(pinning: true);
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_cardWidth != constraints.maxWidth) {
                  _cardWidth = constraints.maxWidth;
                }
              });
              return CompositedTransformTarget(
                link: _layerLink,
                child: Container(
                  padding: EdgeInsets.all(widget.isCompact ? 16 : 20),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: highlighted
                          ? widget.color.withValues(alpha: 0.5)
                          : theme.dividerColor.withValues(alpha: 0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: highlighted
                            ? widget.color.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.03),
                        blurRadius: highlighted ? 16 : 10,
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
                            padding: EdgeInsets.all(widget.isCompact ? 8 : 10),
                            decoration: BoxDecoration(
                              color: widget.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              widget.icon,
                              color: widget.color,
                              size: widget.isCompact ? 20 : 24,
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                      SizedBox(height: widget.isCompact ? 12 : 16),
                      Text(
                        widget.value,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: widget.isCompact ? 28 : 32,
                          color: widget.color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: widget.isCompact ? 12 : 14,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _PedidoPopupItem
// =============================================================================

class _PedidoPopupItem extends StatefulWidget {
  final PedidoItem pedido;
  final Color statusColor;
  final Color accentColor;
  final NumberFormat currency;
  final DateFormat dateFormat;
  final VoidCallback onTap;

  const _PedidoPopupItem({
    required this.pedido,
    required this.statusColor,
    required this.accentColor,
    required this.currency,
    required this.dateFormat,
    required this.onTap,
  });

  @override
  State<_PedidoPopupItem> createState() => _PedidoPopupItemState();
}

class _PedidoPopupItemState extends State<_PedidoPopupItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pedido = widget.pedido;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.accentColor.withValues(alpha: 0.08)
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.07),
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    pedido.numero != null ? '#${pedido.numero}' : '–',
                    style: TextStyle(
                      color: widget.accentColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pedido.cliente,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.dateFormat.format(pedido.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.currency.format(pedido.total),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: widget.accentColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: widget.statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      pedido.status,
                      style: TextStyle(
                        color: widget.statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 14,
                color: _hovered
                    ? widget.accentColor
                    : theme.colorScheme.onSurface.withValues(alpha: 0.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _SectionCard
// =============================================================================

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

// =============================================================================
// _OrcamentoItem (lista da seção recentes)
// =============================================================================

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
        onTap: () {},
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
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateFormat.format(orcamento.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: statusColor.withValues(alpha: 0.3)),
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

// =============================================================================
// _PedidoItem
// =============================================================================

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
        onTap: () {},
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
                  color:
                      theme.colorScheme.secondary.withValues(alpha: 0.1),
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
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateFormat.format(pedido.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: statusColor.withValues(alpha: 0.3)),
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

// =============================================================================
// _MaterialItem
// =============================================================================

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
        onTap: () {},
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
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            material.name,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Qtd: ${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 1)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
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

// =============================================================================
// _ProductItem
// =============================================================================

class _ProductItem extends StatelessWidget {
  final ProductItem product;

  const _ProductItem({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {},
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
                child: const Icon(
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
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${product.materials.length} ${product.materials.length == 1 ? 'material' : 'materiais'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
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