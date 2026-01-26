import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../routes.dart';
import 'components/app_layout.dart';
import 'pages/inicio_page.dart';
import 'pages/orcamentos_page.dart';
import 'pages/produtos_page.dart';
import 'pages/materiais_page.dart';

/// GoRouter configuration for app navigation
class AppRouter {
  // Navigator keys are useful for nested navigation
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.inicio,
    routes: [
      // ShellRoute wraps the pages with the AppLayout (Sidebar)
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
        ],
      ),
    ],
  );
}
