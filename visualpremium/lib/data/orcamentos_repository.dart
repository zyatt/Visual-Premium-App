import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:visualpremium/models/orcamento_item.dart';
import 'package:visualpremium/models/pedido_item.dart';
import 'package:visualpremium/data/config.dart';

class OrcamentosApiRepository {
  String get baseUrl => Config.baseUrl;

  Future<List<OrcamentoItem>> fetchOrcamentos() async {
    try {
      final url = Uri.parse('$baseUrl/orcamentos');
      final response = await http.get(url);

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
      final response = await http.get(url);

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
      final body = item.toMap();

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final created = OrcamentoItem.tryFromMap(jsonDecode(response.body));
        if (created == null) {
          throw Exception('Falha ao parsear resposta do servidor');
        }
        return created;
      } else {
        throw Exception('Erro ao criar orçamento: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<OrcamentoItem> updateOrcamento(OrcamentoItem item) async {
    final url = Uri.parse('$baseUrl/orcamentos/${item.id}');
    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(item.toMap()),
    );
    if (response.statusCode == 200) {
      final updated = OrcamentoItem.tryFromMap(jsonDecode(response.body));
      if (updated == null) {
        throw Exception('Falha ao parsear resposta do servidor');
      }
      return updated;
    } else {
      throw Exception('Erro ao atualizar orçamento: ${response.statusCode}');
    }
  }

  // ✅ VERSÃO CORRIGIDA - Agora recebe o OrcamentoItem completo
  Future<OrcamentoItem> updateStatus(OrcamentoItem item, String status) async {
    try {
      final url = Uri.parse('$baseUrl/orcamentos/${item.id}/status');
      
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'status': status,
          'produtoId': item.produtoId,  // ✅ Enviando produtoId
          'cliente': item.cliente,       // ✅ Enviando cliente
          'numero': item.numero,         // ✅ Enviando número
        }),
      );
            
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final updated = OrcamentoItem.tryFromMap(jsonData);
        
        if (updated == null) {
          throw Exception('Falha ao parsear resposta do servidor');
        }
        
        return updated;
      } else {
        throw Exception('Erro ao atualizar status: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteOrcamento(int id) async {
    final url = Uri.parse('$baseUrl/orcamentos/$id');
    final response = await http.delete(url);

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
      
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/pdf',
        },
      );

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
      final response = await http.get(url);

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
    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(item.toMap()),
    );
    if (response.statusCode == 200) {
      final updated = PedidoItem.tryFromMap(jsonDecode(response.body));
      if (updated == null) {
        throw Exception('Falha ao parsear resposta do servidor');
      }
      return updated;
    } else {
      // ✅ Capturar e exibir a mensagem de erro do servidor
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
  // ✅ CORRIGIDO - Apenas envia o status, sem dados desnecessários
  Future<PedidoItem> updatePedidoStatus(int id, String status) async {
    final url = Uri.parse('$baseUrl/pedidos/$id/status');
    final response = await http.patch(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': status}),  // ✅ APENAS o status
    );
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
    final response = await http.delete(url);

    if (response.statusCode == 200) {
      return;
    } else {
      throw Exception('Erro ao deletar pedido: ${response.statusCode}');
    }
  }

  Future<Uint8List> downloadPedidoPdf(int id) async {
    try {
      final url = Uri.parse('$baseUrl/pdf/pedido/$id');
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/pdf',
        },
      );

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