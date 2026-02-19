import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/update_service.dart';
import 'dart:ui';

class AutoUpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const AutoUpdateDialog({
    super.key,
    required this.updateInfo,
  });

  @override
  State<AutoUpdateDialog> createState() => _AutoUpdateDialogState();

  static Future<void> show(BuildContext context, UpdateInfo updateInfo) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AutoUpdateDialog(updateInfo: updateInfo),
    );
  }
}

class _AutoUpdateDialogState extends State<AutoUpdateDialog>
    with SingleTickerProviderStateMixin {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _showReleaseNotes = true;
  String? _errorMessage; // null = sem erro

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _errorMessage = null;
    });

    // downloadAndInstallUpdate agora retorna String? (null = sucesso)
    final error = await UpdateService.downloadAndInstallUpdate(
      widget.updateInfo.downloadUrl,
      (progress) {
        if (mounted) {
          setState(() => _downloadProgress = progress);
        }
      },
    );

    // Se chegou aqui é porque houve erro (sucesso chama exit(0))
    if (mounted && error != null) {
      setState(() {
        _isDownloading = false;
        _errorMessage = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: size.height * 0.90,
            ),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.1),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(theme),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildVersionInfo(theme),
                        const SizedBox(height: 24),

                        // Painel de erro — visível acima dos botões
                        if (_errorMessage != null) _buildErrorPanel(theme),

                        if (_showReleaseNotes &&
                            widget.updateInfo.releaseNotes.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          _buildReleaseNotes(theme),
                        ],

                        const SizedBox(height: 24),

                        if (_isDownloading)
                          _buildDownloadProgress(theme)
                        else if (_errorMessage == null)
                          _buildUpdateInfo(theme),
                      ],
                    ),
                  ),
                ),
                if (!_isDownloading) _buildActionButtons(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Painel de erro vermelho ──────────────────────────────────────────────
  Widget _buildErrorPanel(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade300, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_rounded, color: Colors.red.shade600, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Falha na atualização',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Copiar erro
              IconButton(
                tooltip: 'Copiar erro',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.copy_rounded,
                    size: 18, color: Colors.red.shade400),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _errorMessage!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Erro copiado para a área de transferência'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SelectableText(
              _errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.red.shade900,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Verifique o console (flutter run) para logs detalhados.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.red.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.system_update_alt_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Atualização Disponível',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.new_releases,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Versão ${widget.updateInfo.latestVersion}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── Botão fechar (sempre visível, exceto durante download) ──
          if (!_isDownloading)
            IconButton(
              tooltip: 'Fechar',
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          if (widget.updateInfo.mandatory && !_isDownloading)
            const SizedBox(width: 8),
          if (widget.updateInfo.mandatory)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.shade400,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.priority_high,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'OBRIGATÓRIA',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Versões ──────────────────────────────────────────────────────────────
  Widget _buildVersionInfo(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _InfoCard(
            icon: Icons.info_outline,
            label: 'Versão Atual',
            value: widget.updateInfo.currentVersion,
            theme: theme,
            color: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(width: 12),
        const Icon(Icons.arrow_forward, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: _InfoCard(
            icon: Icons.rocket_launch_outlined,
            label: 'Nova Versão',
            value: widget.updateInfo.latestVersion,
            theme: theme,
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
            isHighlight: true,
          ),
        ),
      ],
    );
  }

  // ── Release Notes ────────────────────────────────────────────────────────
  Widget _buildReleaseNotes(ThemeData theme) {
    final parsedNotes =
        _parseReleaseNotes(widget.updateInfo.releaseNotes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.article_outlined,
                    color: theme.colorScheme.primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  'O que há de novo',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            IconButton(
              onPressed: () =>
                  setState(() => _showReleaseNotes = !_showReleaseNotes),
              icon: Icon(_showReleaseNotes
                  ? Icons.expand_less
                  : Icons.expand_more),
              tooltip: _showReleaseNotes ? 'Ocultar' : 'Expandir',
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (parsedNotes['features']?.isNotEmpty ?? false)
          _buildNoteCategory(theme, 'Novidades', Icons.star_rounded,
              parsedNotes['features']!, Colors.amber),
        if (parsedNotes['improvements']?.isNotEmpty ?? false)
          _buildNoteCategory(theme, 'Melhorias', Icons.trending_up_rounded,
              parsedNotes['improvements']!, Colors.blue),
        if (parsedNotes['fixes']?.isNotEmpty ?? false)
          _buildNoteCategory(theme, 'Correções', Icons.build_rounded,
              parsedNotes['fixes']!, Colors.green),
        if (parsedNotes['other']?.isNotEmpty ?? false)
          _buildNoteCategory(theme, 'Outras Mudanças',
              Icons.category_rounded, parsedNotes['other']!,
              theme.colorScheme.primary),
      ],
    );
  }

  Widget _buildNoteCategory(ThemeData theme, String title, IconData icon,
      List<String> items, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(item,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(height: 1.5)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<String>> _parseReleaseNotes(String notes) {
    final Map<String, List<String>> categorized = {
      'features': [],
      'improvements': [],
      'fixes': [],
      'other': [],
    };

    final lines =
        notes.split('\n').where((line) => line.trim().isNotEmpty);
    String currentCategory = 'other';

    for (var line in lines) {
      final trimmed = line.trim();

      if (trimmed.toLowerCase().contains('novidade') ||
          trimmed.toLowerCase().contains('novo') ||
          trimmed.toLowerCase().contains('feature') ||
          trimmed.startsWith('✨')) {
        currentCategory = 'features';
        continue;
      } else if (trimmed.toLowerCase().contains('melhoria') ||
          trimmed.toLowerCase().contains('improvement') ||
          trimmed.toLowerCase().contains('aprimora') ||
          trimmed.startsWith('⚡')) {
        currentCategory = 'improvements';
        continue;
      } else if (trimmed.toLowerCase().contains('correção') ||
          trimmed.toLowerCase().contains('corrigido') ||
          trimmed.toLowerCase().contains('fix') ||
          trimmed.startsWith('🐛')) {
        currentCategory = 'fixes';
        continue;
      }

      if (trimmed.startsWith('-') ||
          trimmed.startsWith('*') ||
          trimmed.startsWith('•') ||
          trimmed.startsWith('✨') ||
          trimmed.startsWith('⚡') ||
          trimmed.startsWith('🐛')) {
        var cleanedLine = trimmed.substring(1).trim();
        cleanedLine =
            cleanedLine.replaceFirst(RegExp(r'^[✨⚡🐛]\s*'), '');
        if (cleanedLine.isNotEmpty) {
          categorized[currentCategory]?.add(cleanedLine);
        }
      } else if (trimmed.isNotEmpty && !trimmed.endsWith(':')) {
        categorized[currentCategory]?.add(trimmed);
      }
    }

    return categorized;
  }

  // ── Download progress ────────────────────────────────────────────────────
  Widget _buildDownloadProgress(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.1),
            theme.colorScheme.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Baixando atualização...',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              Text(
                '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _downloadProgress,
              minHeight: 10,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.info_outline,
                  color: theme.colorScheme.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'O aplicativo será reiniciado automaticamente após o download',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Info pré-download ────────────────────────────────────────────────────
  Widget _buildUpdateInfo(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.download_rounded,
                color: theme.colorScheme.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pronto para atualizar',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'A atualização será baixada e instalada automaticamente',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Botões de ação ───────────────────────────────────────────────────────
  Widget _buildActionButtons(ThemeData theme) {
    final hasError = _errorMessage != null;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          // Botão "Fechar" sempre disponível quando não está baixando
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(
                  color: hasError
                      ? Colors.red.shade300
                      : theme.dividerColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                hasError ? 'Fechar' : 'Mais tarde',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: hasError ? Colors.red.shade600 : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _startDownload,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                backgroundColor: hasError
                    ? Colors.orange.shade600
                    : theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    hasError
                        ? Icons.refresh_rounded
                        : Icons.download_rounded,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    hasError ? 'Tentar Novamente' : 'Atualizar Agora',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── InfoCard ─────────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ThemeData theme;
  final Color color;
  final bool isHighlight;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
    required this.color,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: isHighlight
            ? Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                width: 1.5,
              )
            : null,
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 28,
            color: isHighlight
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: isHighlight ? theme.colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}