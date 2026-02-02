import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UserRole {
  admin,
  user,
}

class User {
  final String username;
  final UserRole role;

  const User({
    required this.username,
    required this.role,
  });

  Map<String, dynamic> toJson() => {
    'username': username,
    'role': role.name,
  };

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'] as String,
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

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.role == UserRole.admin;
  bool get isLoading => _isLoading;

  // Usuários hardcoded (em produção, isso viria de um backend)
  static const Map<String, Map<String, dynamic>> _users = {
    'admin': {
      'password': 'admin123',
      'role': UserRole.admin,
    },
    'user': {
      'password': 'user123',
      'role': UserRole.user,
    },
  };

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
        final Map<String, dynamic> json = {
          'username': userData.split(':')[0],
          'role': userData.split(':')[1],
        };
        _currentUser = User.fromJson(json);
      }
    } catch (e) {
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    try {
      // Verifica se o usuário existe
      if (!_users.containsKey(username)) {
        return false;
      }

      // Verifica a senha
      final userData = _users[username]!;
      if (userData['password'] != password) {
        return false;
      }

      // Cria o usuário
      _currentUser = User(
        username: username,
        role: userData['role'] as UserRole,
      );

      // Salva no SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, '${_currentUser!.username}:${_currentUser!.role.name}');

      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    try {
      _currentUser = null;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      
      // ✅ Importante: notificar ANTES de qualquer navegação
      notifyListeners();
      
      // ✅ Pequeno delay para garantir que o estado foi atualizado
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      // Em caso de erro, ainda limpa o usuário
      _currentUser = null;
      notifyListeners();
    }
  }
}