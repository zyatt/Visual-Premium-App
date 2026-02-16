import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/config.dart';
import '../models/mensagem_item.dart';

class ChatRepository {
  String get baseUrl => Config.baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<ConversaItem>> fetchConversas() async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/chat/conversas'),
        headers: headers,
      );

      if (response.statusCode == 401) {
        throw Exception('Não autorizado');
      }

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => ConversaItem.fromJson(json)).toList();
      } else {
        throw Exception('Falha ao carregar conversas');
      }
    } catch (e) {
      throw Exception('Erro ao conectar: $e');
    }
  }

  Future<List<MensagemItem>> fetchMensagens(int usuarioId) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/chat/mensagens/$usuarioId'),
        headers: headers,
      );

      if (response.statusCode == 401) {
        throw Exception('Não autorizado');
      }

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => MensagemItem.fromJson(json)).toList();
      } else {
        throw Exception('Falha ao carregar mensagens');
      }
    } catch (e) {
      throw Exception('Erro ao conectar: $e');
    }
  }

  Future<MensagemItem> enviarMensagem(int destinatarioId, String conteudo) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/chat/mensagens'),
        headers: headers,
        body: jsonEncode({
          'destinatarioId': destinatarioId,
          'conteudo': conteudo,
        }),
      );

      if (response.statusCode == 401) {
        throw Exception('Não autorizado');
      }

      if (response.statusCode == 201) {
        return MensagemItem.fromJson(jsonDecode(response.body));
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Erro ao enviar mensagem');
      }
    } catch (e) {
      throw Exception('Erro ao enviar: $e');
    }
  }

  Future<int> contarNaoLidas() async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/chat/nao-lidas'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['count'] as int;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }
}