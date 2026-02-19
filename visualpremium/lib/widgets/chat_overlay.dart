import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../models/mensagem_item.dart';
import '../models/usuario_item.dart';
import '../data/usuarios_repository.dart';

class ChatOverlay extends StatefulWidget {
  const ChatOverlay({super.key});

  @override
  State<ChatOverlay> createState() => _ChatOverlayState();
}

class _ChatOverlayState extends State<ChatOverlay> {
  bool _isOpen = false;
  int? _selectedUsuarioId;
  Offset _position = const Offset(24, 24);

  double _chatWidth = 300;
  double _chatHeight = 300;

  static const double _minWidth = 220;
  static const double _minHeight = 220;
  static const double _maxWidth = 600;
  static const double _maxHeight = 700;

  // Edge/corner resize handle size
  static const double _handleSize = 10.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.startPolling();

      final size = MediaQuery.of(context).size;
      setState(() {
        _position = Offset(
          size.width - _chatWidth - 24,
          size.height - _chatHeight - 90,
        );
      });
    });
  }

  void _toggleChat() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _selectedUsuarioId = null;
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        chatProvider.loadConversas();
      }
    });
  }

  void _selectUsuario(int usuarioId) {
    setState(() {
      _selectedUsuarioId = usuarioId;
    });
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.loadMensagens(usuarioId);
  }

  void _voltar() {
    setState(() {
      _selectedUsuarioId = null;
    });
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.loadConversas();
  }

  void _mostrarSeletorUsuarios() {
    showDialog(
      context: context,
      builder: (context) => _SeletorUsuariosDialog(
        onUsuarioSelecionado: (usuario) {
          Navigator.pop(context);
          _selectUsuario(usuario.id);
        },
      ),
    );
  }

  /// Clamps position so the chat panel stays within screen bounds.
  void _clampPosition(Size screenSize) {
    _position = Offset(
      _position.dx.clamp(0, screenSize.width - _chatWidth),
      _position.dy.clamp(0, screenSize.height - _chatHeight),
    );
  }

  // ─── resize handlers ────────────────────────────────────────────────────────

  void _onResizeRight(DragUpdateDetails d, Size screenSize) {
    setState(() {
      _chatWidth = (_chatWidth + d.delta.dx).clamp(_minWidth, _maxWidth);
      // Also ensure we don't overflow right edge
      _chatWidth = _chatWidth.clamp(
        _minWidth,
        screenSize.width - _position.dx,
      );
    });
  }

  void _onResizeBottom(DragUpdateDetails d, Size screenSize) {
    setState(() {
      _chatHeight = (_chatHeight + d.delta.dy).clamp(_minHeight, _maxHeight);
      _chatHeight = _chatHeight.clamp(
        _minHeight,
        screenSize.height - _position.dy,
      );
    });
  }

  void _onResizeLeft(DragUpdateDetails d, Size screenSize) {
    setState(() {
      final newWidth = (_chatWidth - d.delta.dx).clamp(_minWidth, _maxWidth);
      final dx = _chatWidth - newWidth;
      _chatWidth = newWidth;
      _position = Offset(
        (_position.dx + dx).clamp(0.0, screenSize.width - _chatWidth),
        _position.dy,
      );
    });
  }

  void _onResizeTop(DragUpdateDetails d, Size screenSize) {
    setState(() {
      final newHeight = (_chatHeight - d.delta.dy).clamp(_minHeight, _maxHeight);
      final dy = _chatHeight - newHeight;
      _chatHeight = newHeight;
      _position = Offset(
        _position.dx,
        (_position.dy + dy).clamp(0.0, screenSize.height - _chatHeight),
      );
    });
  }

  // corner helpers
  void _onResizeBottomRight(DragUpdateDetails d, Size screenSize) {
    _onResizeRight(d, screenSize);
    _onResizeBottom(d, screenSize);
  }

  void _onResizeBottomLeft(DragUpdateDetails d, Size screenSize) {
    _onResizeLeft(d, screenSize);
    _onResizeBottom(d, screenSize);
  }

  void _onResizeTopRight(DragUpdateDetails d, Size screenSize) {
    _onResizeRight(d, screenSize);
    _onResizeTop(d, screenSize);
  }

  void _onResizeTopLeft(DragUpdateDetails d, Size screenSize) {
    _onResizeLeft(d, screenSize);
    _onResizeTop(d, screenSize);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final size = MediaQuery.of(context).size;

    _clampPosition(size);

    return Stack(
      children: [
        // ── chat button ──────────────────────────────────────────────────────
        Positioned(
          right: 24,
          bottom: 24,
          child: ElevatedButton(
            onPressed: _toggleChat,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: EdgeInsets.zero,
              minimumSize: const Size(56, 56),
              fixedSize: const Size(56, 56),
            ),
            child: Stack(
              children: [
                const Icon(Icons.chat, size: 28),
                if (chatProvider.naoLidas > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        chatProvider.naoLidas > 9
                            ? '9+'
                            : '${chatProvider.naoLidas}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // ── chat panel ───────────────────────────────────────────────────────
        if (_isOpen)
          Positioned(
            left: _position.dx,
            top: _position.dy,
            child: SizedBox(
              width: _chatWidth,
              height: _chatHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // ── main panel ──────────────────────────────────────────
                  GestureDetector(
                    // drag only via the header (drag_indicator icon inside children)
                    behavior: HitTestBehavior.translucent,
                    onPanUpdate: (details) {
                      // This outer detector is intentionally left without action;
                      // dragging is handled inside the header widget below.
                    },
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: _chatWidth,
                        height: _chatHeight,
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.dividerColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: _selectedUsuarioId == null
                            ? _ConversasList(
                                onSelectUsuario: _selectUsuario,
                                onNovaConversa: _mostrarSeletorUsuarios,
                                onClose: _toggleChat,
                                onHeaderDrag: (d) {
                                  setState(() {
                                    _position = Offset(
                                      (_position.dx + d.delta.dx)
                                          .clamp(0, size.width - _chatWidth),
                                      (_position.dy + d.delta.dy)
                                          .clamp(0, size.height - _chatHeight),
                                    );
                                  });
                                },
                              )
                            : _ChatView(
                                usuarioId: _selectedUsuarioId!,
                                onVoltar: _voltar,
                                onClose: _toggleChat,
                                onHeaderDrag: (d) {
                                  setState(() {
                                    _position = Offset(
                                      (_position.dx + d.delta.dx)
                                          .clamp(0, size.width - _chatWidth),
                                      (_position.dy + d.delta.dy)
                                          .clamp(0, size.height - _chatHeight),
                                    );
                                  });
                                },
                              ),
                      ),
                    ),
                  ),

                  // ── resize handles ──────────────────────────────────────

                  // Right edge
                  Positioned(
                    right: 0,
                    top: _handleSize,
                    bottom: _handleSize,
                    width: _handleSize,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeLeftRight,
                      child: GestureDetector(
                        onPanUpdate: (d) => _onResizeRight(d, size),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ),

                  // Left edge
                  Positioned(
                    left: 0,
                    top: _handleSize,
                    bottom: _handleSize,
                    width: _handleSize,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeLeftRight,
                      child: GestureDetector(
                        onPanUpdate: (d) => _onResizeLeft(d, size),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ),

                  // Bottom edge
                  Positioned(
                    bottom: 0,
                    left: _handleSize,
                    right: _handleSize,
                    height: _handleSize,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpDown,
                      child: GestureDetector(
                        onPanUpdate: (d) => _onResizeBottom(d, size),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ),

                  // Top edge
                  Positioned(
                    top: 0,
                    left: _handleSize,
                    right: _handleSize,
                    height: _handleSize,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpDown,
                      child: GestureDetector(
                        onPanUpdate: (d) => _onResizeTop(d, size),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ),

                  // Bottom-right corner
                  Positioned(
                    bottom: 0,
                    right: 0,
                    width: _handleSize * 2,
                    height: _handleSize * 2,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpLeftDownRight,
                      child: GestureDetector(
                        onPanUpdate: (d) => _onResizeBottomRight(d, size),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ),

                  // Bottom-left corner
                  Positioned(
                    bottom: 0,
                    left: 0,
                    width: _handleSize * 2,
                    height: _handleSize * 2,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpRightDownLeft,
                      child: GestureDetector(
                        onPanUpdate: (d) => _onResizeBottomLeft(d, size),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ),

                  // Top-right corner
                  Positioned(
                    top: 0,
                    right: 0,
                    width: _handleSize * 2,
                    height: _handleSize * 2,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpRightDownLeft,
                      child: GestureDetector(
                        onPanUpdate: (d) => _onResizeTopRight(d, size),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ),

                  // Top-left corner
                  Positioned(
                    top: 0,
                    left: 0,
                    width: _handleSize * 2,
                    height: _handleSize * 2,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpLeftDownRight,
                      child: GestureDetector(
                        onPanUpdate: (d) => _onResizeTopLeft(d, size),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ),

                  // Resize grip visual indicator (bottom-right)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: IgnorePointer(
                      child: Icon(
                        Icons.open_in_full,
                        size: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Seletor de usuários
// ════════════════════════════════════════════════════════════════════════════

class _SeletorUsuariosDialog extends StatefulWidget {
  final Function(UsuarioItem) onUsuarioSelecionado;

  const _SeletorUsuariosDialog({required this.onUsuarioSelecionado});

  @override
  State<_SeletorUsuariosDialog> createState() => _SeletorUsuariosDialogState();
}

class _SeletorUsuariosDialogState extends State<_SeletorUsuariosDialog> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _usuariosApi = UsuariosApiRepository();

  List<UsuarioItem> _usuarios = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _carregarUsuarios();
  }

  Future<void> _carregarUsuarios() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final usuarios = await _usuariosApi.fetchUsuarios();
      if (mounted) {
        setState(() {
          _usuarios = usuarios;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);

    final usuariosFiltrados = _usuarios
        .where((u) {
          if (u.id == authProvider.currentUser?.id) return false;
          if (!u.ativo) return false;
          if (_searchQuery.isEmpty) return true;

          final query = _searchQuery.toLowerCase();
          return u.nome.toLowerCase().contains(query) ||
              u.username.toLowerCase().contains(query);
        })
        .toList();

    final usuariosComConversa =
        chatProvider.conversas.map((c) => c.usuario.id).toSet();

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 360,
        height: 480,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_add,
                    color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 12),
                Text(
                  'Nova Conversa',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar usuário...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.3),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: theme.colorScheme.error,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Erro ao carregar',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: _carregarUsuarios,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Tentar novamente'),
                              ),
                            ],
                          ),
                        )
                      : usuariosFiltrados.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_off_outlined,
                                    size: 48,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.3),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchQuery.isEmpty
                                        ? 'Nenhum usuário disponível'
                                        : 'Nenhum usuário encontrado',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: usuariosFiltrados.length,
                              itemBuilder: (context, index) {
                                final usuario = usuariosFiltrados[index];
                                final temConversa =
                                    usuariosComConversa.contains(usuario.id);

                                return ListTile(
                                  onTap: () =>
                                      widget.onUsuarioSelecionado(usuario),
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 18,
                                    backgroundColor:
                                        theme.colorScheme.primary,
                                    child: Text(
                                      usuario.nome
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 14),
                                    ),
                                  ),
                                  title: Text(
                                    usuario.nome,
                                    style:
                                        theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '@${usuario.username}',
                                    style:
                                        theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: temConversa
                                      ? Icon(
                                          Icons.check_circle,
                                          color: theme.colorScheme.primary,
                                          size: 18,
                                        )
                                      : null,
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Lista de conversas
// ════════════════════════════════════════════════════════════════════════════

class _ConversasList extends StatelessWidget {
  final Function(int) onSelectUsuario;
  final VoidCallback onNovaConversa;
  final VoidCallback onClose;
  final Function(DragUpdateDetails) onHeaderDrag;

  const _ConversasList({
    required this.onSelectUsuario,
    required this.onNovaConversa,
    required this.onClose,
    required this.onHeaderDrag,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Column(
      children: [
        GestureDetector(
          onPanUpdate: onHeaderDrag,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.drag_indicator, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Icon(Icons.chat, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Conversas',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline,
                      color: Colors.white, size: 20),
                  onPressed: onNovaConversa,
                  tooltip: 'Nova conversa',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: chatProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : chatProvider.conversas.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat,
                            size: 48,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Nenhuma conversa',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: onNovaConversa,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Iniciar conversa',
                                style: TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: chatProvider.conversas.length,
                      itemBuilder: (context, index) {
                        final conversa = chatProvider.conversas[index];
                        final isFromMe =
                            conversa.ultimaMensagem.remetenteId ==
                                authProvider.currentUser?.id;

                        return ListTile(
                          onTap: () => onSelectUsuario(conversa.usuario.id),
                          dense: true,
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: theme.colorScheme.primary,
                            child: Text(
                              conversa.usuario.nome
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14),
                            ),
                          ),
                          title: Text(
                            conversa.usuario.nome,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: conversa.naoLidas > 0
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '${isFromMe ? "Você: " : ""}${conversa.ultimaMensagem.conteudo}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatTime(conversa.ultimaMensagem.createdAt),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              if (conversa.naoLidas > 0) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    conversa.naoLidas > 9
                                        ? '9+'
                                        : '${conversa.naoLidas}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final localTime = time.toLocal();
    final now = DateTime.now();
    final diff = now.difference(localTime);

    if (diff.inDays > 0) {
      return DateFormat('dd/MM').format(localTime);
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h';
    } else {
      return DateFormat('HH:mm').format(localTime);
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Chat view
// ════════════════════════════════════════════════════════════════════════════

class _ChatView extends StatefulWidget {
  final int usuarioId;
  final VoidCallback onVoltar;
  final VoidCallback onClose;
  final Function(DragUpdateDetails) onHeaderDrag;

  const _ChatView({
    required this.usuarioId,
    required this.onVoltar,
    required this.onClose,
    required this.onHeaderDrag,
  });

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _usuariosApi = UsuariosApiRepository();
  bool _isSending = false;
  String? _nomeUsuario;

  @override
  void initState() {
    super.initState();
    _carregarDadosUsuario();
  }

  Future<void> _carregarDadosUsuario() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    try {
      final conversa = chatProvider.conversas.firstWhere(
        (c) => c.usuario.id == widget.usuarioId,
      );

      if (mounted) {
        setState(() {
          _nomeUsuario = conversa.usuario.nome;
        });
      }
    } catch (e) {
      try {
        final usuarios = await _usuariosApi.fetchUsuarios();
        final usuario = usuarios.firstWhere(
          (u) => u.id == widget.usuarioId,
        );

        if (mounted) {
          setState(() {
            _nomeUsuario = usuario.nome;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _nomeUsuario = 'Usuário';
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _enviarMensagem() async {
    final conteudo = _messageController.text.trim();
    if (conteudo.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      await chatProvider.enviarMensagem(widget.usuarioId, conteudo);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final mensagens = chatProvider.getMensagens(widget.usuarioId);

    return Column(
      children: [
        GestureDetector(
          onPanUpdate: widget.onHeaderDrag,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.drag_indicator, color: Colors.white, size: 20),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: Colors.white, size: 20),
                  onPressed: widget.onVoltar,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  child: Text(
                    (_nomeUsuario ?? '?').substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _nomeUsuario ?? 'Carregando...',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: widget.onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: mensagens.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat,
                        size: 48,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Nenhuma mensagem ainda',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Envie a primeira mensagem!',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              : Builder(
                  builder: (context) {
                    final List<dynamic> items = [];
                    String? lastDateKey;

                    for (final mensagem in mensagens) {
                      final local = mensagem.createdAt.toLocal();
                      final dateKey =
                          DateFormat('yyyy-MM-dd').format(local);

                      if (dateKey != lastDateKey) {
                        items.add(_DateSeparator(date: local));
                        lastDateKey = dateKey;
                      }
                      items.add(mensagem);
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        if (item is _DateSeparator) {
                          return _DateSeparatorWidget(date: item.date);
                        }
                        final mensagem = item as MensagemItem;
                        final isFromMe = mensagem.remetenteId ==
                            authProvider.currentUser?.id;
                        return _MessageBubble(
                          mensagem: mensagem,
                          isFromMe: isFromMe,
                        );
                      },
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.3),
            border: Border(
              top: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Mensagem...',
                    hintStyle: const TextStyle(fontSize: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _enviarMensagem(),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _isSending ? null : _enviarMensagem,
                  icon: _isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, size: 18),
                  color: Colors.white,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Date separator
// ════════════════════════════════════════════════════════════════════════════

class _DateSeparator {
  final DateTime date;
  const _DateSeparator({required this.date});
}

class _DateSeparatorWidget extends StatelessWidget {
  final DateTime date;
  const _DateSeparatorWidget({required this.date});

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);

    if (d == today) return 'Hoje';
    if (d == yesterday) return 'Ontem';

    final diaSemana = {
      1: 'Segunda-feira',
      2: 'Terça-feira',
      3: 'Quarta-feira',
      4: 'Quinta-feira',
      5: 'Sexta-feira',
      6: 'Sábado',
      7: 'Domingo',
    }[date.weekday]!;

    return '${DateFormat('dd/MM/yyyy').format(date)} - $diaSemana';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              thickness: 1,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _formatDate(date),
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color:
                    theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Message bubble
// ════════════════════════════════════════════════════════════════════════════

class _MessageBubble extends StatelessWidget {
  final MensagemItem mensagem;
  final bool isFromMe;

  const _MessageBubble({
    required this.mensagem,
    required this.isFromMe,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isFromMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor:
                  theme.colorScheme.primary.withValues(alpha: 0.2),
              child: Text(
                mensagem.remetente.nome.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isFromMe
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isFromMe ? 14 : 4),
                  bottomRight: Radius.circular(isFromMe ? 4 : 14),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mensagem.conteudo,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isFromMe
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DateFormat('HH:mm')
                        .format(mensagem.createdAt.toLocal()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 9,
                      color: isFromMe
                          ? Colors.white.withValues(alpha: 0.7)
                          : theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isFromMe) ...[
            const SizedBox(width: 6),
            CircleAvatar(
              radius: 14,
              backgroundColor:
                  theme.colorScheme.primary.withValues(alpha: 0.2),
              child: Text(
                mensagem.remetente.nome.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}