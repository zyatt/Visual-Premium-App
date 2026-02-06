import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/settings_dialog.dart';
import '../providers/auth_provider.dart';

class AppLayout extends StatelessWidget {
  final Widget child;

  const AppLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const _Sidebar(),
          Expanded(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252323) : Colors.white,
        border: Border(
          right: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo Area
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Visual Premium',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),

          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _NavItem(
                  icon: Icons.dashboard_outlined,
                  label: 'Início',
                  route: '/',
                ),
                _NavItem(
                  icon: Icons.attach_money_rounded,
                  label: 'Orçamentos',
                  route: '/orcamentos',
                ),
                _NavItem(
                  icon: Icons.shopping_cart_outlined,
                  label: 'Pedidos',
                  route: '/pedidos',
                ),
                _NavItem(
                  icon: Icons.inventory_2_outlined,
                  label: 'Produtos',
                  route: '/produtos',
                ),
                _NavItem(
                  icon: Icons.construction_outlined,
                  label: 'Materiais',
                  route: '/materiais',
                ),
                
                // ✅ Seção Administração - visibilidade controlada
                if (authProvider.hasAlmoxarifadoAccess || authProvider.isAdmin) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'ADMINISTRAÇÃO',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  
                  // ✅ Almoxarifado - admin E almoxarife veem
                  if (authProvider.hasAlmoxarifadoAccess)
                    _NavItem(
                      icon: Icons.inventory_2,
                      label: 'Almoxarifado',
                      route: '/almoxarifado',
                    ),
                  
                  // ✅ Painel Admin - APENAS admin vê
                  if (authProvider.isAdmin)
                    _NavItem(
                      icon: Icons.admin_panel_settings,
                      label: 'Painel Admin',
                      route: '/admin',
                    ),
                ],
              ],
            ),
          ),

          // User Profile / Bottom Actions
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Botão de configurações
                InkWell(
                  onTap: () => SettingsDialog.show(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: colorScheme.primary,
                          child: Text(
                            authProvider.currentUser?.username.substring(0, 1).toUpperCase() ?? 'U',
                            style: TextStyle(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                authProvider.currentUser?.username ?? 'Usuário',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                authProvider.isAdmin ? 'Administrador' : 'Usuário',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.settings,
                          size: 18,
                          color: theme.iconTheme.color?.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Botão de logout
                InkWell(
                  onTap: () async {
                    // ✅ Captura o router antes de operações assíncronas
                    final router = GoRouter.of(context);
                    
                    final confirm = await showDialog<bool>(
                      context: context,
                      barrierDismissible: false,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Sair'),
                        content: const Text('Deseja realmente sair do sistema?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(true),
                            style: TextButton.styleFrom(
                              foregroundColor: colorScheme.error,
                            ),
                            child: const Text('Sair'),
                          ),
                        ],
                      ),
                    );
                    
                    if (confirm == true) {
                      // ✅ Faz logout
                      await authProvider.logout();
                      
                      // ✅ Navega usando o router capturado
                      router.go('/login');
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: colorScheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.logout,
                          size: 18,
                          color: colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Sair',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.error,
                          ),
                        ),
                      ],
                    ),
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

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final GoRouterState state = GoRouterState.of(context);
    final bool isActive = state.uri.toString() == route;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go(route),
          borderRadius: BorderRadius.circular(10),
          hoverColor: colorScheme.primary.withValues(alpha: 0.05),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isActive ? colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive ? colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isActive ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: isActive ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                if (isActive) ...[
                  const Spacer(),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}