import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            isDark ? 'assets/images/logo branca.png' : 'assets/images/logo preta.png',
            width: MediaQuery.of(context).size.width * 0.70,
            height: MediaQuery.of(context).size.height * 0.70,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}