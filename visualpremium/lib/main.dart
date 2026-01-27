import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'theme_provider.dart';
import 'nav.dart';

void main() {
  
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MultiProvider wraps the app to provide state to all widgets
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        // Add more providers here as needed
        // Example:
        // ChangeNotifierProvider(create: (_) => ExampleProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp.router(
            title: 'Visual Premium',
            debugShowCheckedModeBanner: false,

            // Theme configuration
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: themeProvider.themeMode,

            // Use context.go() or context.push() to navigate to the routes.
            routerConfig: AppRouter.router,
          );
        },
      ),
    );
  }
}