import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/chat_repository.dart';
import '../models/mensagem_item.dart';

class ChatProvider extends ChangeNotifier {
  final _repository = ChatRepository();
  
  List<ConversaItem> _conversas = [];
  Map<int, List<MensagemItem>> _mensagensPorUsuario = {};
  int _naoLidas = 0;
  bool _isLoading = false;
  Timer? _pollingTimer;

  List<ConversaItem> get conversas => _conversas;
  int get naoLidas => _naoLidas;
  bool get isLoading => _isLoading;

  List<MensagemItem> getMensagens(int usuarioId) {
    return _mensagensPorUsuario[usuarioId] ?? [];
  }

  void startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshData(),
    );
    _refreshData();
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _refreshData() async {
    try {
      final count = await _repository.contarNaoLidas();
      if (_naoLidas != count) {
        _naoLidas = count;
        notifyListeners();
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> loadConversas() async {
    _isLoading = true;
    notifyListeners();

    try {
      _conversas = await _repository.fetchConversas();
      _naoLidas = _conversas.fold(0, (sum, c) => sum + c.naoLidas);
    } catch (e) {
      // Handle error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMensagens(int usuarioId) async {
    try {
      final mensagens = await _repository.fetchMensagens(usuarioId);
      _mensagensPorUsuario[usuarioId] = mensagens;
      
      // Atualizar contador de não lidas
      final conversa = _conversas.firstWhere(
        (c) => c.usuario.id == usuarioId,
        orElse: () => _conversas.first,
      );
      if (conversa.naoLidas > 0) {
        _naoLidas = (_naoLidas - conversa.naoLidas).clamp(0, 999);
        await loadConversas();
      }
      
      notifyListeners();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> enviarMensagem(int destinatarioId, String conteudo) async {
    try {
      final mensagem = await _repository.enviarMensagem(destinatarioId, conteudo);
      
      if (!_mensagensPorUsuario.containsKey(destinatarioId)) {
        _mensagensPorUsuario[destinatarioId] = [];
      }
      _mensagensPorUsuario[destinatarioId]!.add(mensagem);
      
      await loadConversas();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  void clear() {
    _conversas = [];
    _mensagensPorUsuario = {};
    _naoLidas = 0;
    stopPolling();
    notifyListeners();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}