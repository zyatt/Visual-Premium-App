class MensagemItem {
  final int id;
  final int remetenteId;
  final int destinatarioId;
  final String conteudo;
  final bool lida;
  final DateTime createdAt;
  final UsuarioSimples remetente;
  final UsuarioSimples destinatario;

  MensagemItem({
    required this.id,
    required this.remetenteId,
    required this.destinatarioId,
    required this.conteudo,
    required this.lida,
    required this.createdAt,
    required this.remetente,
    required this.destinatario,
  });

  factory MensagemItem.fromJson(Map<String, dynamic> json) {
    return MensagemItem(
      id: json['id'] as int,
      remetenteId: json['remetenteId'] as int,
      destinatarioId: json['destinatarioId'] as int,
      conteudo: json['conteudo'] as String,
      lida: json['lida'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      remetente: UsuarioSimples.fromJson(json['remetente']),
      destinatario: UsuarioSimples.fromJson(json['destinatario']),
    );
  }
}

class UsuarioSimples {
  final int id;
  final String username;
  final String nome;

  UsuarioSimples({
    required this.id,
    required this.username,
    required this.nome,
  });

  factory UsuarioSimples.fromJson(Map<String, dynamic> json) {
    return UsuarioSimples(
      id: json['id'] as int,
      username: json['username'] as String,
      nome: json['nome'] as String,
    );
  }
}

class ConversaItem {
  final UsuarioSimples usuario;
  final MensagemItem ultimaMensagem;
  final int naoLidas;

  ConversaItem({
    required this.usuario,
    required this.ultimaMensagem,
    required this.naoLidas,
  });

  factory ConversaItem.fromJson(Map<String, dynamic> json) {
    return ConversaItem(
      usuario: UsuarioSimples.fromJson(json['usuario']),
      ultimaMensagem: MensagemItem.fromJson(json['ultimaMensagem']),
      naoLidas: json['naoLidas'] as int,
    );
  }
}