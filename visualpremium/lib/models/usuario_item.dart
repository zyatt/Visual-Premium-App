class UsuarioItem {
  final int id;
  final String username;
  final String nome;
  final String role;
  final bool ativo;
  final DateTime createdAt;
  final DateTime updatedAt;

  UsuarioItem({
    required this.id,
    required this.username,
    required this.nome,
    required this.role,
    required this.ativo,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UsuarioItem.fromJson(Map<String, dynamic> json) {
    return UsuarioItem(
      id: json['id'] as int,
      username: json['username'] as String,
      nome: json['nome'] as String,
      role: json['role'] as String,
      ativo: json['ativo'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'nome': nome,
      'role': role,
      'ativo': ativo,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  bool get isAdmin => role == 'admin';
  bool get isCompras => role == 'compras';
  bool get hasAlmoxarifadoAccess => isAdmin || isCompras;
}