import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/config.dart';
import '../models/log_item.dart';

class LogsRepository {
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> fetchLogs({
    int page = 1,
    int limit = 50,
    String? entidade,
    int? usuarioId,
    String? acao,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (entidade != null) queryParams['entidade'] = entidade;
      if (usuarioId != null) queryParams['usuarioId'] = usuarioId.toString();
      if (acao != null) queryParams['acao'] = acao;

      final uri = Uri.parse('${Config.baseUrl}/logs').replace(
        queryParameters: queryParams,
      );

      final headers = await _getHeaders();
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final logs = (data['logs'] as List)
            .map((json) => LogItem.fromJson(json))
            .toList();

        return {
          'logs': logs,
          'total': data['total'],
          'page': data['page'],
          'totalPages': data['totalPages'],
        };
      } else {
        throw Exception('Erro HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      rethrow; // Propaga o erro original
    }
  }
}