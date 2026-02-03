import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../models/log_item.dart';
import '../../../data/logs_repository.dart';
import '../../../theme.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final _repository = LogsRepository();
  List<LogItem> _logs = [];
  bool _isLoading = true;
  String? _error;
  
  String? _filtroEntidade;
  String? _filtroAcao;
  int _currentPage = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _carregarLogs();
  }

  Future<void> _carregarLogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final resultado = await _repository.fetchLogs(
        page: _currentPage,
        entidade: _filtroEntidade,
        acao: _filtroAcao,
      );

      setState(() {
        _logs = resultado['logs'];
        _totalPages = resultado['totalPages'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _aplicarFiltros() {
    setState(() {
      _currentPage = 1;
    });
    _carregarLogs();
  }

  void _limparFiltros() {
    setState(() {
      _filtroEntidade = null;
      _filtroAcao = null;
      _currentPage = 1;
    });
    _carregarLogs();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(32.0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.go('/admin'),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Voltar para Admin',
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.history_outlined,
                  size: 32,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Logs do Sistema',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                // Filtros
                _buildFiltroDropdown(
                  label: 'Entidade',
                  value: _filtroEntidade,
                  items: const ['MATERIAL', 'PRODUTO', 'ORCAMENTO', 'PEDIDO', 'USUARIO'],
                  onChanged: (value) {
                    setState(() => _filtroEntidade = value);
                    _aplicarFiltros();
                  },
                ),
                const SizedBox(width: 12),
                _buildFiltroDropdown(
                  label: 'Ação',
                  value: _filtroAcao,
                  items: const ['CRIAR', 'EDITAR', 'DELETAR'],
                  onChanged: (value) {
                    setState(() => _filtroAcao = value);
                    _aplicarFiltros();
                  },
                ),
                const SizedBox(width: 12),
                if (_filtroEntidade != null || _filtroAcao != null)
                  TextButton.icon(
                    onPressed: _limparFiltros,
                    icon: const Icon(Icons.clear),
                    label: const Text('Limpar'),
                  ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Erro: $_error'))
                    : _logs.isEmpty
                        ? const Center(child: Text('Nenhum log encontrado'))
                        : _buildLogsList(theme),
          ),

          // Paginação
          if (!_isLoading && _logs.isNotEmpty)
            _buildPaginacao(theme),
        ],
      ),
    );
  }

  Widget _buildFiltroDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        value: value,
        hint: Text(label),
        underline: const SizedBox(),
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildLogsList(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final log = _logs[index];
        return _LogCard(log: log);
      },
    );
  }

  Widget _buildPaginacao(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _currentPage > 1
                ? () {
                    setState(() => _currentPage--);
                    _carregarLogs();
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            'Página $_currentPage de $_totalPages',
            style: theme.textTheme.bodyMedium,
          ),
          IconButton(
            onPressed: _currentPage < _totalPages
                ? () {
                    setState(() => _currentPage++);
                    _carregarLogs();
                  }
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  final LogItem log;

  const _LogCard({required this.log});

  Color _getAcaoColor() {
    switch (log.acao) {
      case 'CRIAR':
        return Colors.green;
      case 'EDITAR':
        return Colors.blue;
      case 'DELETAR':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getAcaoIcon() {
    switch (log.acao) {
      case 'CRIAR':
        return Icons.add_circle_outline;
      case 'EDITAR':
        return Icons.edit_outlined;
      case 'DELETAR':
        return Icons.delete_outline;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          // Ícone da ação
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getAcaoColor().withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getAcaoIcon(),
              color: _getAcaoColor(),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          
          // Informações
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Usuário
                    Icon(
                      Icons.person_outline,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      log.usuarioNome,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Ação
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getAcaoColor().withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        log.acaoFormatada,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _getAcaoColor(),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // Entidade
                    Text(
                      log.entidadeFormatada,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                
                // Descrição
                Text(
                  log.descricao,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          
          // Data
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(
                Icons.access_time,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 2),
              Text(
                dateFormat.format(log.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}