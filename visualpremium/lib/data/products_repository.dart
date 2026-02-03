import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visualpremium/models/product_item.dart';
import 'package:visualpremium/config/config.dart';

class ProductsApiRepository {
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

  Future<List<ProductItem>> fetchProducts() async {
    try {
      final url = Uri.parse('$baseUrl/produtos');
      final headers = await _getHeaders(); // ✅ Inclui token
      final response = await http.get(url, headers: headers);
      
      if (response.statusCode == 401) {
        throw Exception('Não autorizado - faça login novamente');
      }
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList
            .map((e) => ProductItem.tryFromMap(e as Map<String, dynamic>))
            .whereType<ProductItem>()
            .toList();
      } else {
        throw Exception('Erro ao buscar produtos: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<ProductItem> createProduct(ProductItem item) async {
    try {
      final url = Uri.parse('$baseUrl/produtos');
      final headers = await _getHeaders(); // ✅ Inclui token
      final body = item.toMap();
            
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );
      
      if (response.statusCode == 401) {
        throw Exception('Não autorizado - faça login novamente');
      }
            
      if (response.statusCode == 200) {
        final created = ProductItem.tryFromMap(jsonDecode(response.body));
        if (created == null) {
          throw Exception('Falha ao parsear resposta do servidor');
        }
        return created;
      } else {
        throw Exception('Erro ao criar produto: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<ProductItem> updateProduct(ProductItem item) async {
    final url = Uri.parse('$baseUrl/produtos/${item.id}');
    final headers = await _getHeaders(); // ✅ Inclui token
    
    final response = await http.put(
      url,
      headers: headers,
      body: jsonEncode(item.toMap()),
    );
    
    if (response.statusCode == 401) {
      throw Exception('Não autorizado - faça login novamente');
    }
    
    if (response.statusCode == 200) {
      final updated = ProductItem.tryFromMap(jsonDecode(response.body));
      if (updated == null) {
        throw Exception('Falha ao parsear resposta do servidor');
      }
      return updated;
    } else {
      throw Exception('Erro ao atualizar produto: ${response.statusCode}');
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      final url = Uri.parse('$baseUrl/produtos/$id');
      final headers = await _getHeaders(); // ✅ Inclui token
      final response = await http.delete(url, headers: headers);
      
      if (response.statusCode == 401) {
        throw Exception('Não autorizado - faça login novamente');
      }
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Erro ao deletar produto');
      } else {
        throw Exception('Erro ao deletar produto: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}