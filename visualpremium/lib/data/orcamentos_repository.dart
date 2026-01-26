import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:visualpremium/models/orcamento_item.dart';
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

  Future<OrcamentoItem> updateStatus(int id, String status) async {
    final url = Uri.parse('$baseUrl/orcamentos/$id/status');
    final response = await http.patch(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': status}),
    );
    if (response.statusCode == 200) {
      final updated = OrcamentoItem.tryFromMap(jsonDecode(response.body));
      if (updated == null) {
        throw Exception('Falha ao parsear resposta do servidor');
      }
      return updated;
    } else {
      throw Exception('Erro ao atualizar status: ${response.statusCode}');
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
}