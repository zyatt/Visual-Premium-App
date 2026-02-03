import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:visualpremium/models/material_item.dart';
import 'package:visualpremium/config/config.dart';

class MaterialsApiRepository {
  String get baseUrl => Config.baseUrl;

  Future<List<MaterialItem>> fetchMaterials() async {
    try {
      final url = Uri.parse('$baseUrl/materiais');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList
            .map((e) => MaterialItem.tryFromMap(e as Map<String, dynamic>))
            .whereType<MaterialItem>()
            .toList();
      } else {
        throw Exception('Erro ao buscar materiais: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<MaterialItem> createMaterial(MaterialItem item) async {
    try {
      final url = Uri.parse('$baseUrl/materiais');
      final body = item.toMap();
            
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
            
      if (response.statusCode == 200) {
        final created = MaterialItem.tryFromMap(jsonDecode(response.body));
        if (created == null) {
          throw Exception('Falha ao parsear resposta do servidor');
        }
        return created;
      } else {
        throw Exception('Erro ao criar material: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<MaterialItem> updateMaterial(MaterialItem item) async {
    final url = Uri.parse('$baseUrl/materiais/${item.id}');
    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(item.toMap()),
    );
    if (response.statusCode == 200) {
      final updated = MaterialItem.tryFromMap(jsonDecode(response.body));
      if (updated == null) {
        throw Exception('Falha ao parsear resposta do servidor');
      }
      return updated;
    } else {
      throw Exception('Erro ao atualizar material: ${response.statusCode}');
    }
  }

  Future<void> deleteMaterial(String id) async {
    final url = Uri.parse('$baseUrl/materiais/$id');
    final response = await http.delete(url);
    
    if (response.statusCode == 200) {
      return;
    } else if (response.statusCode == 400) {
      // Tenta parsear a mensagem de erro
      try {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Material em uso');
      } catch (e) {
        throw Exception('Erro ao deletar material: ${response.body}');
      }
    } else {
      throw Exception('Erro ao deletar material: ${response.statusCode}');
    }
  }
}