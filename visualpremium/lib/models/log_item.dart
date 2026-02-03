class LogItem {
  final int id;
  final int usuarioId;
  final String usuarioNome;
  final String acao;
  final String entidade;
  final int entidadeId;
  final String descricao;
  final Map<String, dynamic>? detalhes;
  final DateTime createdAt;

  LogItem({
    required this.id,
    required this.usuarioId,
    required this.usuarioNome,
    required this.acao,
    required this.entidade,
    required this.entidadeId,
    required this.descricao,
    this.detalhes,
    required this.createdAt,
  });

  factory LogItem.fromJson(Map<String, dynamic> json) {
    return LogItem(
      id: json['id'] as int,
      usuarioId: json['usuarioId'] as int,
      usuarioNome: json['usuarioNome'] as String,
      acao: json['acao'] as String,
      entidade: json['entidade'] as String,
      entidadeId: json['entidadeId'] as int,
      descricao: json['descricao'] as String,
      detalhes: json['detalhes'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  String get acaoFormatada {
    switch (acao) {
      case 'CRIAR':
        return 'Criou';
      case 'EDITAR':
        return 'Editou';
      case 'DELETAR':
        return 'Deletou';
      default:
        return acao;
    }
  }

  String get entidadeFormatada {
    switch (entidade) {
      case 'MATERIAL':
        return 'Material';
      case 'PRODUTO':
        return 'Produto';
      case 'ORCAMENTO':
        return 'Orçamento';
      case 'PEDIDO':
        return 'Pedido';
      case 'USUARIO':
        return 'Usuário';
      default:
        return entidade;
    }
  }
}