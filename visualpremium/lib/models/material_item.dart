import 'dart:convert';

class MaterialItem {
  final String id;
  final String name;
  final String unit;
  final int costCents;
  final String quantity;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const MaterialItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.costCents,
    required this.quantity,
    required this.createdAt,
    this.updatedAt,
  });

  MaterialItem copyWith({
    String? name,
    String? unit,
    int? costCents,
    String? quantity,
    DateTime? updatedAt,
  }) =>
      MaterialItem(
        id: id,
        name: name ?? this.name,
        unit: unit ?? this.unit,
        costCents: costCents ?? this.costCents,
        quantity: quantity ?? this.quantity,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toMap() => {
        'nome': name,
        'unidade': unit,
        'custo': costCents / 100.0,
        'quantidade': double.tryParse(quantity) ?? 0,
      };

  static MaterialItem? tryFromMap(Map<String, Object?> map) {
    try {
      final id = map['id'];
      final nome = map['nome'];
      final unidade = map['unidade'];
      final custo = map['custo'];
      final quantidade = map['quantidade'];
      
      final createdAtRaw = map['created_at'] ?? 
                          map['createdAt'] ?? 
                          map['data_criacao'] ?? 
                          map['dataCriacao'] ??
                          map['criado_em'] ??
                          map['criadoEm'];
                          
      final updatedAtRaw = map['updated_at'] ?? 
                          map['updatedAt'] ?? 
                          map['data_atualizacao'] ?? 
                          map['dataAtualizacao'] ??
                          map['atualizado_em'] ??
                          map['atualizadoEm'];

      if (id == null ||
          nome is! String ||
          unidade is! String ||
          custo == null ||
          quantidade == null) {
        return null;
      }

      final idStr = id.toString();
      final custoDouble =
          (custo is int) ? custo.toDouble() : (custo is double ? custo : 0.0);
      final costCents = (custoDouble * 100).round();

      final quantidadeStr = quantidade is num 
          ? quantidade.toString() 
          : quantidade.toString();

      final cleanedName = nome.trim();
      final cleanedUnit = unidade.trim();
      if (cleanedName.isEmpty || cleanedUnit.isEmpty) return null;
      if (costCents < 0) return null;

      DateTime? createdAt;
      DateTime? updatedAt;

      if (createdAtRaw != null) {
        if (createdAtRaw is String) {
          createdAt = DateTime.tryParse(createdAtRaw);
        } else if (createdAtRaw is int) {
          createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtRaw);
        } else if (createdAtRaw is DateTime) {
          createdAt = createdAtRaw;
        }
      }
      
      if (updatedAtRaw != null) {
        if (updatedAtRaw is String) {
          updatedAt = DateTime.tryParse(updatedAtRaw);
        } else if (updatedAtRaw is int) {
          updatedAt = DateTime.fromMillisecondsSinceEpoch(updatedAtRaw);
        } else if (updatedAtRaw is DateTime) {
          updatedAt = updatedAtRaw;
        }
      }

      return MaterialItem(
        id: idStr,
        name: cleanedName,
        unit: cleanedUnit,
        costCents: costCents,
        quantity: quantidadeStr,
        createdAt: createdAt ?? DateTime.now(),
        updatedAt: updatedAt,
      );
    } catch (e) {
      return null;
    }
  }

  static List<MaterialItem> decodeList(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final out = <MaterialItem>[];
      for (final e in decoded) {
        if (e is Map) {
          final map = e.map((k, v) => MapEntry(k.toString(), v));
          final item = tryFromMap(map);
          if (item != null) out.add(item);
        }
      }
      return out;
    } catch (e) {
      return const [];
    }
  }

  static String encodeList(List<MaterialItem> items) =>
      jsonEncode(items.map((e) => e.toMap()).toList(growable: false));

  @override
  String toString() {
    return 'MaterialItem(id: $id, name: $name, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}