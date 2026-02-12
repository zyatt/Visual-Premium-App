import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.dark;
  bool _isChangingTheme = false;
  
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isChangingTheme => _isChangingTheme;

  ThemeProvider() {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themeKey);
    
    if (savedTheme != null) {
      _themeMode = savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    }
  }

  Future<void> toggleTheme() async {
    _isChangingTheme = true;
    notifyListeners();
    
    // Small delay to show the animation starting
    await Future.delayed(const Duration(milliseconds: 150));
    
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, _themeMode == ThemeMode.dark ? 'dark' : 'light');
    
    notifyListeners();
    
    // Wait for animation to complete
    await Future.delayed(const Duration(milliseconds: 1000));
    
    _isChangingTheme = false;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    
    _isChangingTheme = true;
    notifyListeners();
    
    // Small delay to show the animation starting
    await Future.delayed(const Duration(milliseconds: 150));
    
    _themeMode = mode;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode == ThemeMode.dark ? 'dark' : 'light');
    
    notifyListeners();
    
    // Wait for animation to complete
    await Future.delayed(const Duration(milliseconds: 1000));
    
    _isChangingTheme = false;
    notifyListeners();
  }
}