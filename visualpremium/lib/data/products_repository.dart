import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:visualpremium/models/product_item.dart';
import 'package:visualpremium/data/config.dart';

class ProductsApiRepository {
  String get baseUrl => Config.baseUrl;

  Future<List<ProductItem>> fetchProducts() async {
    try {
      final url = Uri.parse('$baseUrl/produtos');
      final response = await http.get(url);
      
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
      final body = item.toMap();
            
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
            
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
    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(item.toMap()),
    );
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
    final url = Uri.parse('$baseUrl/produtos/$id');
    final response = await http.delete(url);
    if (response.statusCode != 200) {
      throw Exception('Erro ao deletar produto');
    }
  }
}