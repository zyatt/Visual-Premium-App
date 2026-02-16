import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../routes.dart';
import '../providers/auth_provider.dart';
import 'components/app_layout.dart';
import 'pages/inicio_page.dart';
import 'pages/orcamentos_page.dart';
import 'pages/pedidos_page.dart';
import 'pages/produtos_page.dart';
import 'pages/materiais_page.dart';
import 'pages/admin/admin_page.dart';
import 'pages/admin/usuarios_page.dart';
import 'pages/admin/almoxarifado_page.dart';
import 'pages/admin/relatorio_page.dart';
import 'pages/loading/splash_page.dart';
import 'pages/login/login_page.dart';
import 'pages/admin/logs_page.dart';
import '../widgets/update_checker_widget.dart';
import 'pages/admin/faixas_custo_page.dart';
import 'pages/admin/configuracoes_avancadas_page.dart';
import 'pages/admin/formacao_preco_page.dart';
import 'pages/admin/folha_pagamento_page.dart';
import 'pages/admin/imposto_sobra_page.dart';
import 'pages/chat_page.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter createRouter(AuthProvider authProvider) {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/splash',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final isLoading = authProvider.isLoading;
        final isAuthenticated = authProvider.isAuthenticated;
        final isAdmin = authProvider.isAdmin;
        final hasAlmoxarifadoAccess = authProvider.hasAlmoxarifadoAccess;

        final location = state.uri.toString();

        final isGoingToLogin = location == '/login';
        final isGoingToSplash = location == '/splash';
        final isGoingToAdminPanel = location.startsWith('/admin');
        final isGoingToConfigAvancadas = location.startsWith('/configuracoes-avancadas');
        final isGoingToAlmoxarifado = location.startsWith('/almoxarifado');

        if (isGoingToSplash) return null;
        if (isLoading) return '/splash';

        if (!isAuthenticated) {
          if (!isGoingToLogin) return '/login';
          return null;
        }

        if (isGoingToLogin) return '/';

        if (isGoingToAdminPanel && !isAdmin) return '/';
        if (isGoingToConfigAvancadas && !isAdmin) return '/';
        
        if (isGoingToAlmoxarifado && !hasAlmoxarifadoAccess) return '/';

        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          name: 'splash',
          pageBuilder: (context, state) => NoTransitionPage(
            child: const SplashPage(),
          ),
        ),
        GoRoute(
          path: '/login',
          name: 'login',
          pageBuilder: (context, state) => NoTransitionPage(
            child: const LoginPage(),
          ),
        ),
        ShellRoute(
          navigatorKey: _shellNavigatorKey,
          builder: (context, state, child) {
            return UpdateChecker(
              child: AppLayout(child: child),
            );
          },
          routes: [
            GoRoute(
              path: AppRoutes.inicio,
              name: 'inicio',
              pageBuilder: (context, state) => NoTransitionPage(
                child: const HomePage(),
              ),
            ),
            GoRoute(
              path: AppRoutes.orcamentos,
              name: 'orcamentos',
              pageBuilder: (context, state) => NoTransitionPage(
                child: const BudgetsPage(),
              ),
            ),
            GoRoute(
              path: AppRoutes.pedidos,
              name: 'pedidos',
              pageBuilder: (context, state) => NoTransitionPage(
                child: const PedidosPage(),
              ),
            ),
            GoRoute(
              path: AppRoutes.produtos,
              name: 'produtos',
              pageBuilder: (context, state) => NoTransitionPage(
                child: const ProductsPage(),
              ),
            ),
            GoRoute(
              path: AppRoutes.materiais,
              name: 'materiais',
              pageBuilder: (context, state) => NoTransitionPage(
                child: const MaterialsPage(),
              ),
            ),
            GoRoute(
              path: AppRoutes.admin,
              name: 'admin',
              pageBuilder: (context, state) => NoTransitionPage(
                child: const AdminPage(),
              ),
            ),
            GoRoute(
              path: AppRoutes.usuarios,
              name: 'usuarios',
              pageBuilder: (context, state) => NoTransitionPage(
                child: const UsuariosPage(),
              ),
            ),
            GoRoute(
              path: AppRoutes.logs,
              name: 'logs',
              pageBuilder: (context, state) => NoTransitionPage(
                child: const LogsPage(),
              ),
            ),
            GoRoute(
              path: AppRoutes.almoxarifado,
              name: 'almoxarifado',
              pageBuilder: (context, state) => NoTransitionPage(
                child: const AlmoxarifadoPage(),
              ),
            ),
            GoRoute(
              path: AppRoutes.relatorio,
              name: 'relatorio',
              pageBuilder: (context, state) => NoTransitionPage(
                child: const RelatorioPage(),
              ),
            ),
            // Configurações Avançadas
            GoRoute(
              path: AppRoutes.configuracoesAvancadas,
              name: 'configuracoesAvancadas',
              pageBuilder: (context, state) => NoTransitionPage(
                child: const ConfiguracoesAvancadasPage(),
              ),
            ),
            GoRoute(
              path: AppRoutes.faixacusto,
              name: 'faixacusto',
              pageBuilder: (context, state) => NoTransitionPage(
                child: const FaixasCustoPage(),
              ),
            ),
            GoRoute(
              path: AppRoutes.formacaoPreco,
              name: 'formacaoPreco',
              pageBuilder: (context, state) => NoTransitionPage(
                child: const FormacaoPrecoPage(),
              ),
            ),
            GoRoute(
              path: AppRoutes.folhaPagamento,
              name: 'folhaPagamento',
              pageBuilder: (context, state) => NoTransitionPage(
                child: const FolhaPagamentoPage(),
              ),
            ),
            GoRoute(
              path: AppRoutes.impostoSobra,
              name: 'impostoSobra',
              pageBuilder: (context, state) => NoTransitionPage(
                child: const ImpostoSobraPage(),
              ),
            ),
            GoRoute(
              path: AppRoutes.chat,
              name: 'chat',
              pageBuilder: (context, state) => NoTransitionPage(
                child: const ChatPage(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}