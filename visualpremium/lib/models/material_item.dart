import 'dart:convert';

class MaterialItem {
  final String id;
  final String name;
  final String unit;
  final int costCents;
  final String quantity; // Mudado de double para String
  final DateTime createdAt;

  const MaterialItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.costCents,
    required this.quantity,
    required this.createdAt,
  });

  MaterialItem copyWith({
    String? name,
    String? unit,
    int? costCents,
    String? quantity,
  }) =>
      MaterialItem(
        id: id,
        name: name ?? this.name,
        unit: unit ?? this.unit,
        costCents: costCents ?? this.costCents,
        quantity: quantity ?? this.quantity,
        createdAt: createdAt,
      );

  Map<String, Object?> toMap() => {
        'nome': name,
        'unidade': unit,
        'custo': costCents / 100.0,
        'quantidade': quantity, // Envia como string
      };

  static MaterialItem? tryFromMap(Map<String, Object?> map) {
    try {
      final id = map['id'];
      final nome = map['nome'];
      final unidade = map['unidade'];
      final custo = map['custo'];
      final quantidade = map['quantidade'];

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

      // Converte quantidade para string
      final quantidadeStr = quantidade.toString();

      final cleanedName = nome.trim();
      final cleanedUnit = unidade.trim();
      if (cleanedName.isEmpty || cleanedUnit.isEmpty) return null;
      if (costCents < 0) return null;

      return MaterialItem(
        id: idStr,
        name: cleanedName,
        unit: cleanedUnit,
        costCents: costCents,
        quantity: quantidadeStr,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  static List<MaterialItem> decodeList(String raw) {
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
  }

  static String encodeList(List<MaterialItem> items) =>
      jsonEncode(items.map((e) => e.toMap()).toList(growable: false));
}