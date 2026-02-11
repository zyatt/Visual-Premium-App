import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visualpremium/models/product_item.dart';
import 'package:visualpremium/config/config.dart';

class ProductsApiRepository {
  String get baseUrl => Config.baseUrl;

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
      final headers = await _getHeaders();
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
      // Separa avisos que estão vinculados a opções extras temporárias
      final avisosComOpcaoExtraTemporaria = item.avisos.where((aviso) {
        return aviso.opcaoExtraId != null && aviso.opcaoExtraId! >= 1000000;
      }).toList();

      // Cria um map para armazenar a relação entre IDs temporários e IDs reais
      final tempToRealOpcaoExtraIdMap = <int, int>{};

      // PASSO 1: Cria o produto sem os avisos vinculados a opções extras temporárias
      final url = Uri.parse('$baseUrl/produtos');
      final headers = await _getHeaders();
      final body = item.toMap(); // Isso já filtra os avisos com opções extras temporárias
      
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );
      
      if (response.statusCode == 401) {
        throw Exception('Não autorizado - faça login novamente');
      }
      
      if (response.statusCode == 400) {
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['error'] ?? errorData['message'] ?? 'Erro desconhecido';
          throw Exception('Erro de validação: $errorMessage');
        } catch (e) {
          throw Exception('Erro ao criar produto: ${response.body}');
        }
      }
      
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Erro ao criar produto: ${response.statusCode} - ${response.body}');
      }

      final createdProduct = ProductItem.tryFromMap(jsonDecode(response.body));
      if (createdProduct == null) {
        throw Exception('Falha ao parsear resposta do servidor');
      }

      // PASSO 2: Se existem avisos pendentes, mapeia os IDs e os cria
      if (avisosComOpcaoExtraTemporaria.isNotEmpty) {
        // Mapeia IDs temporários para IDs reais das opções extras
        for (int i = 0; i < item.opcoesExtras.length; i++) {
          final tempOpcaoExtra = item.opcoesExtras[i];
          if (tempOpcaoExtra.isTemporary && i < createdProduct.opcoesExtras.length) {
            final realOpcaoExtra = createdProduct.opcoesExtras[i];
            tempToRealOpcaoExtraIdMap[tempOpcaoExtra.id] = realOpcaoExtra.id;
          }
        }

        // Cria os avisos pendentes com os IDs reais
        final avisosParaCriar = avisosComOpcaoExtraTemporaria.map((aviso) {
          final realOpcaoExtraId = tempToRealOpcaoExtraIdMap[aviso.opcaoExtraId];
          if (realOpcaoExtraId == null) {
            throw Exception('Não foi possível mapear a opção extra para o aviso: ${aviso.mensagem}');
          }
          
          return aviso.copyWith(
            opcaoExtraId: realOpcaoExtraId,
          );
        }).toList();

        // Atualiza o produto com os avisos adicionais
        final productWithAvisos = createdProduct.copyWith(
          avisos: [...createdProduct.avisos, ...avisosParaCriar],
        );

        return await updateProduct(productWithAvisos);
      }

      return createdProduct;
    } catch (e) {
      rethrow;
    }
  }

  Future<ProductItem> updateProduct(ProductItem item) async {
    try {
      // Verifica se há avisos com opções extras temporárias
      final hasTemporaryOpcaoExtraAvisos = item.avisos.any((aviso) {
        return aviso.opcaoExtraId != null && aviso.opcaoExtraId! >= 1000000;
      });

      if (hasTemporaryOpcaoExtraAvisos) {
        // Se houver avisos com IDs temporários, cria um mapeamento
        final tempToRealOpcaoExtraIdMap = <int, int>{};
        
        // Busca o produto atual do servidor para obter os IDs reais
        final currentProduct = await _fetchProductById(item.id);
        if (currentProduct != null) {
          // Tenta mapear baseado na ordem das opções extras
          for (int i = 0; i < item.opcoesExtras.length; i++) {
            final tempOpcaoExtra = item.opcoesExtras[i];
            if (tempOpcaoExtra.isTemporary && i < currentProduct.opcoesExtras.length) {
              final realOpcaoExtra = currentProduct.opcoesExtras[i];
              tempToRealOpcaoExtraIdMap[tempOpcaoExtra.id] = realOpcaoExtra.id;
            }
          }
        }

        // Atualiza os avisos com IDs reais
        final avisosAtualizados = item.avisos.map((aviso) {
          if (aviso.opcaoExtraId != null && aviso.opcaoExtraId! >= 1000000) {
            final realId = tempToRealOpcaoExtraIdMap[aviso.opcaoExtraId];
            if (realId != null) {
              return aviso.copyWith(opcaoExtraId: realId);
            }
          }
          return aviso;
        }).toList();

        // Cria um novo item com os avisos atualizados
        final itemAtualizado = item.copyWith(avisos: avisosAtualizados);
        
        final url = Uri.parse('$baseUrl/produtos/${itemAtualizado.id}');
        final headers = await _getHeaders();
        final body = itemAtualizado.toMap();
              
        final response = await http.put(
          url,
          headers: headers,
          body: jsonEncode(body),
        );

        if (response.statusCode == 401) {
          throw Exception('Não autorizado - faça login novamente');
        }
        
        if (response.statusCode == 400) {
          try {
            final errorData = jsonDecode(response.body);
            final errorMessage = errorData['error'] ?? errorData['message'] ?? 'Erro desconhecido';
            throw Exception('Erro de validação: $errorMessage');
          } catch (e) {
            throw Exception('Erro ao atualizar produto: ${response.body}');
          }
        }
        
        if (response.statusCode == 200) {
          final updated = ProductItem.tryFromMap(jsonDecode(response.body));
          if (updated == null) {
            throw Exception('Falha ao parsear resposta do servidor');
          }
          return updated;
        } else {
          throw Exception('Erro ao atualizar produto: ${response.statusCode} - ${response.body}');
        }
      }

      // Caso normal sem IDs temporários
      final url = Uri.parse('$baseUrl/produtos/${item.id}');
      final headers = await _getHeaders();
      final body = item.toMap();
            
      final response = await http.put(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 401) {
        throw Exception('Não autorizado - faça login novamente');
      }
      
      if (response.statusCode == 400) {
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['error'] ?? errorData['message'] ?? 'Erro desconhecido';
          throw Exception('Erro de validação: $errorMessage');
        } catch (e) {
          throw Exception('Erro ao atualizar produto: ${response.body}');
        }
      }
      
      if (response.statusCode == 200) {
        final updated = ProductItem.tryFromMap(jsonDecode(response.body));
        if (updated == null) {
          throw Exception('Falha ao parsear resposta do servidor');
        }
        return updated;
      } else {
        throw Exception('Erro ao atualizar produto: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<ProductItem?> _fetchProductById(String id) async {
    try {
      final url = Uri.parse('$baseUrl/produtos/$id');
      final headers = await _getHeaders();
      final response = await http.get(url, headers: headers);
      
      if (response.statusCode == 200) {
        return ProductItem.tryFromMap(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      final url = Uri.parse('$baseUrl/produtos/$id');
      final headers = await _getHeaders();
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