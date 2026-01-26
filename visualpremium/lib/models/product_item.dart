import 'dart:convert';

class ProductMaterial {
  final int materialId;
  final String materialNome;

  const ProductMaterial({
    required this.materialId,
    required this.materialNome,
  });

  Map<String, Object?> toMap() => {
        'materialId': materialId,
      };

  static ProductMaterial? tryFromMap(Map<String, Object?> map) {
    try {
      final materialId = map['materialId'];
      final material = map['material'];

      if (materialId == null) {
        return null;
      }

      final id = (materialId is int) ? materialId : int.tryParse(materialId.toString());
      if (id == null) return null;

      // Pega o nome do material se vier dentro do objeto 'material'
      String materialNome = '';
      if (material is Map && material['nome'] != null) {
        materialNome = material['nome'].toString();
      }

      return ProductMaterial(
        materialId: id,
        materialNome: materialNome,
      );
    } catch (e) {
      return null;
    }
  }
}

class ProductItem {
  final String id;
  final String name;
  final List<ProductMaterial> materials;
  final DateTime createdAt;

  const ProductItem({
    required this.id,
    required this.name,
    required this.materials,
    required this.createdAt,
  });

  ProductItem copyWith({
    String? name,
    List<ProductMaterial>? materials,
  }) =>
      ProductItem(
        id: id,
        name: name ?? this.name,
        materials: materials ?? this.materials,
        createdAt: createdAt,
      );

  Map<String, Object?> toMap() => {
        'nome': name,
        'materiais': materials.map((m) => m.toMap()).toList(),
      };

  static ProductItem? tryFromMap(Map<String, Object?> map) {
    try {
      final id = map['id'];
      final nome = map['nome'];
      final materiaisData = map['materiais'];

      if (id == null || nome is! String) {
        return null;
      }

      final idStr = id.toString();
      final cleanedName = nome.trim();
      if (cleanedName.isEmpty) return null;

      final materials = <ProductMaterial>[];
      if (materiaisData is List) {
        for (final m in materiaisData) {
          if (m is Map) {
            // O backend retorna: { id, produtoId, materialId, material: { id, nome, ... } }
            final materialData = m['material'];
            final materialId = m['materialId'];
            
            if (materialId != null && materialData is Map) {
              final id = (materialId is int) ? materialId : int.tryParse(materialId.toString());
              final nome = materialData['nome']?.toString() ?? '';
              
              if (id != null && nome.isNotEmpty) {
                materials.add(ProductMaterial(
                  materialId: id,
                  materialNome: nome,
                ));
              }
            }
          }
        }
      }

      return ProductItem(
        id: idStr,
        name: cleanedName,
        materials: materials,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  static List<ProductItem> decodeList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final out = <ProductItem>[];
    for (final e in decoded) {
      if (e is Map) {
        final map = e.map((k, v) => MapEntry(k.toString(), v));
        final item = tryFromMap(map);
        if (item != null) out.add(item);
      }
    }
    return out;
  }

  static String encodeList(List<ProductItem> items) =>
      jsonEncode(items.map((e) => e.toMap()).toList(growable: false));
}