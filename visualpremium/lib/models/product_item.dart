
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
  final DateTime? updatedAt;

  const ProductItem({
    required this.id,
    required this.name,
    required this.materials,
    required this.createdAt,
    this.updatedAt,
  });

  ProductItem copyWith({
    String? name,
    List<ProductMaterial>? materials,
    DateTime? updatedAt,
  }) =>
      ProductItem(
        id: id,
        name: name ?? this.name,
        materials: materials ?? this.materials,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
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

      return ProductItem(
        id: idStr,
        name: cleanedName,
        materials: materials,
        createdAt: createdAt ?? DateTime.now(),
        updatedAt: updatedAt,
      );
    } catch (e) {
      return null;
    }
  }

  static List<ProductItem> decodeList(String raw) {
    try {      
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
    } catch (e) {
      return const [];
    }
  }

  static String encodeList(List<ProductItem> items) =>
      jsonEncode(items.map((e) => e.toMap()).toList(growable: false));

  @override
  String toString() {
    return 'ProductItem(id: $id, name: $name, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}