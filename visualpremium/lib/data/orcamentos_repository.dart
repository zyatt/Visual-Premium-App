import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visualpremium/models/orcamento_item.dart';
import 'package:visualpremium/models/pedido_item.dart';
import 'package:visualpremium/config/config.dart';

class OrcamentosApiRepository {
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

  Future<List<OrcamentoItem>> fetchOrcamentos() async {
    try {
      final url = Uri.parse('$baseUrl/orcamentos');
      final headers = await _getHeaders();
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 401) {
        throw Exception('Não autorizado - faça login novamente');
      }

      if (response.statusCode == 200) {
        return OrcamentoItem.decodeList(response.body);
      } else {
        throw Exception('Erro ao buscar orçamentos: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<ProdutoItem>> fetchProdutos() async {
    try {
      final url = Uri.parse('$baseUrl/orcamentos/produtos');
      final headers = await _getHeaders();
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 401) {
        throw Exception('Não autorizado - faça login novamente');
      }

      if (response.statusCode == 200) {
        return OrcamentoItem.decodeProdutoList(response.body);
      } else {
        throw Exception('Erro ao buscar produtos: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<OrcamentoItem> createOrcamento(OrcamentoItem item) async {
    try {
      final url = Uri.parse('$baseUrl/orcamentos');
      final headers = await _getHeaders();
      final body = item.toMap();

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 401) {
        throw Exception('Não autorizado - faça login novamente');
      }

      // ✅ CORRIGIDO: Aceitar tanto 200 quanto 201
      if (response.statusCode == 200 || response.statusCode == 201) {
        final created = OrcamentoItem.tryFromMap(jsonDecode(response.body));
        if (created == null) {
          throw Exception('Falha ao parsear resposta do servidor');
        }
        return created;
      } else {
        // Tentar extrair mensagem de erro do JSON
        try {
          final errorJson = jsonDecode(response.body);
          if (errorJson is Map && errorJson.containsKey('error')) {
            throw Exception(errorJson['error']);
          } else if (errorJson is Map && errorJson.containsKey('message')) {
            throw Exception(errorJson['message']);
          }
        } catch (_) {
          // Se não conseguir parsear, usar mensagem genérica
        }
        throw Exception('Erro ao criar orçamento: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<OrcamentoItem> updateOrcamento(OrcamentoItem item) async {
    final url = Uri.parse('$baseUrl/orcamentos/${item.id}');
    final headers = await _getHeaders();
    
    final response = await http.put(
      url,
      headers: headers,
      body: jsonEncode(item.toMap()),
    );
    
    if (response.statusCode == 401) {
      throw Exception('Não autorizado - faça login novamente');
    }
    
    if (response.statusCode == 200) {
      final updated = OrcamentoItem.tryFromMap(jsonDecode(response.body));
      if (updated == null) {
        throw Exception('Falha ao parsear resposta do servidor');
      }
      return updated;
    } else {
      // Extrair mensagem de erro
      try {
        final errorJson = jsonDecode(response.body);
        if (errorJson is Map && errorJson.containsKey('error')) {
          throw Exception(errorJson['error']);
        } else if (errorJson is Map && errorJson.containsKey('message')) {
          throw Exception(errorJson['message']);
        }
      } catch (_) {}
      throw Exception('Erro ao atualizar orçamento: ${response.statusCode}');
    }
  }

  Future<OrcamentoItem> updateStatus(OrcamentoItem item, String status) async {
    try {
      final url = Uri.parse('$baseUrl/orcamentos/${item.id}/status');
      final headers = await _getHeaders();
      
      final response = await http.patch(
        url,
        headers: headers,
        body: jsonEncode({
          'status': status,
          'produtoId': item.produtoId,
          'cliente': item.cliente,
          'numero': item.numero,
        }),
      );
      
      if (response.statusCode == 401) {
        throw Exception('Não autorizado - faça login novamente');
      }
            
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final updated = OrcamentoItem.tryFromMap(jsonData);
        
        if (updated == null) {
          throw Exception('Falha ao parsear resposta do servidor');
        }
        
        return updated;
      } else {
        // Extrair mensagem de erro
        try {
          final errorJson = jsonDecode(response.body);
          if (errorJson is Map && errorJson.containsKey('error')) {
            throw Exception(errorJson['error']);
          } else if (errorJson is Map && errorJson.containsKey('message')) {
            throw Exception(errorJson['message']);
          }
        } catch (_) {}
        throw Exception('Erro ao atualizar status: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteOrcamento(int id) async {
    final url = Uri.parse('$baseUrl/orcamentos/$id');
    final headers = await _getHeaders();
    final response = await http.delete(url, headers: headers);

    if (response.statusCode == 401) {
      throw Exception('Não autorizado - faça login novamente');
    }

    if (response.statusCode == 200) {
      return;
    } else {
      throw Exception('Erro ao deletar orçamento: ${response.statusCode}');
    }
  }

  Future<Uint8List> downloadOrcamentoPdf(int id, {bool regenerate = false}) async {
    try {
      final queryParams = regenerate ? '?regenerate=true' : '';
      final url = Uri.parse('$baseUrl/pdf/orcamento/$id$queryParams');
      final headers = await _getHeaders();
      
      final response = await http.get(
        url,
        headers: {
          ...headers,
          'Accept': 'application/pdf',
        },
      );

      if (response.statusCode == 401) {
        throw Exception('Não autorizado - faça login novamente');
      }

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Erro ao baixar PDF: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro ao baixar PDF: $e');
    }
  }

  Future<List<PedidoItem>> fetchPedidos() async {
    try {
      final url = Uri.parse('$baseUrl/pedidos');
      final headers = await _getHeaders();
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 401) {
        throw Exception('Não autorizado - faça login novamente');
      }

      if (response.statusCode == 200) {
        return PedidoItem.decodeList(response.body);
      } else {
        throw Exception('Erro ao buscar pedidos: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<PedidoItem> updatePedido(PedidoItem item) async {
    final url = Uri.parse('$baseUrl/pedidos/${item.id}');
    final headers = await _getHeaders();
    
    final response = await http.put(
      url,
      headers: headers,
      body: jsonEncode(item.toMap()),
    );
    
    if (response.statusCode == 401) {
      throw Exception('Não autorizado - faça login novamente');
    }
    
    if (response.statusCode == 200) {
      final updated = PedidoItem.tryFromMap(jsonDecode(response.body));
      if (updated == null) {
        throw Exception('Falha ao parsear resposta do servidor');
      }
      return updated;
    } else {
      String errorMessage = 'Erro ao atualizar pedido: ${response.statusCode}';
      try {
        final errorJson = jsonDecode(response.body);
        if (errorJson is Map && errorJson.containsKey('error')) {
          errorMessage = errorJson['error'];
        } else {
          errorMessage += ' - ${response.body}';
        }
      } catch (_) {
        if (response.body.isNotEmpty) {
          errorMessage += ' - ${response.body}';
        }
      }
      throw Exception(errorMessage);
    }
  }

  Future<PedidoItem> updatePedidoStatus(int id, String status) async {
    final url = Uri.parse('$baseUrl/pedidos/$id/status');
    final headers = await _getHeaders();
    
    final response = await http.patch(
      url,
      headers: headers,
      body: jsonEncode({'status': status}),
    );
    
    if (response.statusCode == 401) {
      throw Exception('Não autorizado - faça login novamente');
    }
    
    if (response.statusCode == 200) {
      final updated = PedidoItem.tryFromMap(jsonDecode(response.body));
      if (updated == null) {
        throw Exception('Falha ao parsear resposta do servidor');
      }
      return updated;
    } else {
      throw Exception('Erro ao atualizar status: ${response.statusCode}');
    }
  }

  Future<void> deletePedido(int id) async {
    final url = Uri.parse('$baseUrl/pedidos/$id');
    final headers = await _getHeaders();
    final response = await http.delete(url, headers: headers);

    if (response.statusCode == 401) {
      throw Exception('Não autorizado - faça login novamente');
    }

    if (response.statusCode == 200) {
      return;
    } else {
      throw Exception('Erro ao deletar pedido: ${response.statusCode}');
    }
  }

  Future<Uint8List> downloadPedidoPdf(int id) async {
    try {
      final url = Uri.parse('$baseUrl/pdf/pedido/$id');
      final headers = await _getHeaders();
      
      final response = await http.get(
        url,
        headers: {
          ...headers,
          'Accept': 'application/pdf',
        },
      );

      if (response.statusCode == 401) {
        throw Exception('Não autorizado - faça login novamente');
      }

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Erro ao baixar PDF: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}