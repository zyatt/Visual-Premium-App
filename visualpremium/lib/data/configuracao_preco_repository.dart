import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visualpremium/config/config.dart';

class ConfiguracaoPrecoRepository {
  String get baseUrl => Config.baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ==================== CONFIGURAÇÃO GERAL ====================

  Future<Map<String, dynamic>> obterConfig() async {
    try {
      final url = Uri.parse('$baseUrl/configuracao-preco/config');
      final headers = await _getHeaders();
      final response = await http.get(url, headers: headers);
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Erro ao obter configuração: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> atualizarConfig(Map<String, dynamic> data) async {
    try {
      final url = Uri.parse('$baseUrl/configuracao-preco/config');
      final headers = await _getHeaders();
      
      final response = await http.put(
        url,
        headers: headers,
        body: jsonEncode(data),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Erro ao atualizar configuração');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ==================== FOLHA DE PAGAMENTO ====================

  Future<List<Map<String, dynamic>>> listarFolhaPagamento() async {
    try {
      final url = Uri.parse('$baseUrl/configuracao-preco/folha-pagamento');
      final headers = await _getHeaders();
      final response = await http.get(url, headers: headers);
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Erro ao listar folha de pagamento: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> criarFolhaPagamento(Map<String, dynamic> data) async {
    try {
      final url = Uri.parse('$baseUrl/configuracao-preco/folha-pagamento');
      final headers = await _getHeaders();
      
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(data),
      );
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Erro ao criar registro');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> atualizarFolhaPagamento(
    int id,
    Map<String, dynamic> data,
  ) async {
    try {
      final url = Uri.parse('$baseUrl/configuracao-preco/folha-pagamento/$id');
      final headers = await _getHeaders();
      
      final response = await http.put(
        url,
        headers: headers,
        body: jsonEncode(data),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Erro ao atualizar registro');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deletarFolhaPagamento(int id) async {
    try {
      final url = Uri.parse('$baseUrl/configuracao-preco/folha-pagamento/$id');
      final headers = await _getHeaders();
      
      final response = await http.delete(url, headers: headers);
      
      if (response.statusCode == 200) {
        return;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Erro ao deletar registro');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ==================== CÁLCULO DE PREVIEW ====================

  Future<Map<String, dynamic>?> calcularPreview({
    required List<Map<String, dynamic>> materiais,
    required List<Map<String, dynamic>> despesasAdicionais,
    required List<Map<String, dynamic>> opcoesExtras,
    required int tempoProdutivoMinutos,
    double? percentualMarkup,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/configuracao-preco/calcular-preview');
      final headers = await _getHeaders();
      
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'materiais': materiais,
          'despesasAdicionais': despesasAdicionais,
          'opcoesExtras': opcoesExtras,
          'tempoProdutivoMinutos': tempoProdutivoMinutos,
          'percentualMarkup': percentualMarkup,
        }),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}