import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../routes.dart';
import 'components/app_layout.dart';
import 'pages/home_page.dart';
import 'pages/budgets_page.dart';
import 'pages/products_page.dart';
import 'pages/materials_page.dart';

/// GoRouter configuration for app navigation
class AppRouter {
  // Navigator keys are useful for nested navigation
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home,
    routes: [
      // ShellRoute wraps the pages with the AppLayout (Sidebar)
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return AppLayout(child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.home,
            name: 'home',
            pageBuilder: (context, state) => NoTransitionPage(
              child: const HomePage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.budgets,
            name: 'budgets',
            pageBuilder: (context, state) => NoTransitionPage(
              child: const BudgetsPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.products,
            name: 'products',
            pageBuilder: (context, state) => NoTransitionPage(
              child: const ProductsPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.materials,
            name: 'materials',
            pageBuilder: (context, state) => NoTransitionPage(
              child: const MaterialsPage(),
            ),
          ),
        ],
      ),
    ],
  );
}

