import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/config.dart';
import '../models/usuario_item.dart';

class UsuariosApiRepository {
  String get baseUrl => Config.baseUrl;

  // ✅ Método para obter headers com token
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<UsuarioItem>> fetchUsuarios() async {
    try {
      final headers= await _getHeaders();
      
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/usuarios'),
        headers: headers,
      );

      if (response.statusCode == 401) {
        throw Exception('Não autorizado - faça login novamente');
      }

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => UsuarioItem.fromJson(json)).toList();
      } else {
        throw Exception('Falha ao carregar usuários');
      }
    } catch (e) {
      throw Exception('Erro ao conectar com o servidor: $e');
    }
  }

  Future<UsuarioItem> createUsuario(Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.post(
        Uri.parse('${Config.baseUrl}/usuarios'),
        headers: headers,
        body: jsonEncode(data),
      );

      if (response.statusCode == 401) {
        throw Exception('Não autorizado - faça login novamente');
      }

      if (response.statusCode == 201) {
        return UsuarioItem.fromJson(jsonDecode(response.body));
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Erro ao criar usuário');
      }
    } catch (e) {
      throw Exception('Erro ao criar usuário: $e');
    }
  }

  Future<UsuarioItem> updateUsuario(int id, Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.put(
        Uri.parse('${Config.baseUrl}/usuarios/$id'),
        headers: headers,
        body: jsonEncode(data),
      );

      if (response.statusCode == 401) {
        throw Exception('Não autorizado - faça login novamente');
      }

      if (response.statusCode == 200) {
        return UsuarioItem.fromJson(jsonDecode(response.body));
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Erro ao atualizar usuário');
      }
    } catch (e) {
      throw Exception('Erro ao atualizar usuário: $e');
    }
  }

  Future<void> deleteUsuario(int id) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/usuarios/$id');
      final response = await http.delete(url, headers: headers);

      if (response.statusCode == 401) {
        throw Exception('Não autorizado - faça login novamente');
      }

      if (response.statusCode != 204) {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Erro ao deletar usuário');
      }
    } catch (e) {
      throw Exception('Erro ao deletar usuário: $e');
    }
  }
}