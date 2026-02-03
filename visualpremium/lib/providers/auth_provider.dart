import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/config.dart';

enum UserRole {
  admin,
  user,
}

class User {
  final int id;
  final String username;
  final String nome;
  final UserRole role;

  const User({
    required this.id,
    required this.username,
    required this.nome,
    required this.role,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'nome': nome,
    'role': role.name,
  };

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String,
      nome: json['nome'] as String,
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.user,
      ),
    );
  }
}

class AuthProvider extends ChangeNotifier {
  static const String _userKey = 'logged_user';
  User? _currentUser;
  bool _isLoading = true;
  bool _shouldShowWelcome = false;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.role == UserRole.admin;
  bool get isLoading => _isLoading;
  bool get shouldShowWelcome => _shouldShowWelcome;

  AuthProvider() {
    _loadUser();
  }

  Future<void> _loadUser() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString(_userKey);
      
      if (userData != null) {
        final Map<String, dynamic> json = jsonDecode(userData);
        _currentUser = User.fromJson(json);
        // ✅ Ao carregar usuário de sessão anterior, NÃO mostra welcome
        _shouldShowWelcome = false;
      }
    } catch (e) {
      _currentUser = null;
      _shouldShowWelcome = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${Config.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentUser = User.fromJson(data);
        // ✅ Define que deve mostrar welcome após login manual
        _shouldShowWelcome = true;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, jsonEncode(_currentUser!.toJson()));

        notifyListeners();
        return {'success': true};
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['error'] ?? 'Erro ao fazer login',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão com o servidor',
      };
    }
  }

  void markWelcomeAsShown() {
    _shouldShowWelcome = false;
    notifyListeners();
  }

  void setWelcomePending() {
    _shouldShowWelcome = true;
  }

  Future<void> logout() async {
    try {
      _currentUser = null;
      _shouldShowWelcome = false;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      
      notifyListeners();
      
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      _currentUser = null;
      _shouldShowWelcome = false;
      notifyListeners();
    }
  }
}