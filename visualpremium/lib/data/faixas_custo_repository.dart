import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visualpremium/config/config.dart';

class FaixasCustoRepository {
  String get baseUrl => Config.baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Map<String, dynamic>>> listar() async {
    try {
      final url = Uri.parse('$baseUrl/faixas-custo-markup');
      final headers = await _getHeaders();
      final response = await http.get(url, headers: headers);
      
      if (response.statusCode == 401) {
        throw Exception('Não autorizado - faça login novamente');
      }
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Erro ao buscar faixas: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> criar(Map<String, dynamic> data) async {
    try {
      final url = Uri.parse('$baseUrl/faixas-custo-markup');
      final headers = await _getHeaders();
      
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(data),
      );
      
      if (response.statusCode == 401) {
        throw Exception('Não autorizado - faça login novamente');
      }
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Erro ao criar faixa: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> atualizar(
    int id,
    Map<String, dynamic> data,
  ) async {
    try {
      final url = Uri.parse('$baseUrl/faixas-custo-markup/$id');
      final headers = await _getHeaders();
      
      final response = await http.put(
        url,
        headers: headers,
        body: jsonEncode(data),
      );
      
      if (response.statusCode == 401) {
        throw Exception('Não autorizado - faça login novamente');
      }
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Erro ao atualizar faixa: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deletar(int id) async {
    try {
      final url = Uri.parse('$baseUrl/faixas-custo-markup/$id');
      final headers = await _getHeaders();
      
      final response = await http.delete(url, headers: headers);
      
      if (response.statusCode == 401) {
        throw Exception('Não autorizado - faça login novamente');
      }
      
      if (response.statusCode == 200) {
        return;
      } else if (response.statusCode == 400) {
        try {
          final error = jsonDecode(response.body);
          throw Exception(error['error'] ?? error['message'] ?? 'Faixa em uso');
        } catch (e) {
          throw Exception('Erro ao deletar faixa: ${response.body}');
        }
      } else {
        throw Exception('Erro ao deletar faixa: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> calcularValorSugerido(double custoTotal) async {
    try {
      final url = Uri.parse('$baseUrl/faixas-custo-markup/calcular');
      final headers = await _getHeaders();
      
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'custoTotal': custoTotal}),
      );
      
      if (response.statusCode == 401) {
        throw Exception('Não autorizado - faça login novamente');
      }
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        return null;
      } else {
        return null;
      }
    } catch (e) {
      //
      return null;
    }
  }
}