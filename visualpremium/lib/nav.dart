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
import 'pages/admin_page.dart';
import 'pages/splash_page.dart';
import 'pages/login_page.dart';

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
        
        final isGoingToLogin = state.uri.toString() == '/login';
        final isGoingToSplash = state.uri.toString() == '/splash';
        final isGoingToAdmin = state.uri.toString() == '/admin';

        // Aguarda carregamento
        if (isLoading && !isGoingToSplash) {
          return '/splash';
        }

        // Redireciona para login se não autenticado
        if (!isAuthenticated && !isGoingToLogin && !isGoingToSplash) {
          return '/login';
        }

        // Redireciona para home se já autenticado e tentando acessar login
        if (isAuthenticated && isGoingToLogin) {
          return '/';
        }

        // Protege rota admin
        if (isGoingToAdmin && !isAdmin) {
          return '/';
        }

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
            return AppLayout(child: child);
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
          ],
        ),
      ],
    );
  }
}