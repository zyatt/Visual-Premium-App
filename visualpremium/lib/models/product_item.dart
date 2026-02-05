import 'dart:convert';

enum TipoOpcaoExtra {
  stringFloat,
  floatFloat,
  percentFloat
}

class ProductOpcaoExtra {
  final int id;
  final String nome;
  final TipoOpcaoExtra tipo;

  const ProductOpcaoExtra({
    required this.id,
    required this.nome,
    required this.tipo,
  });

  Map<String, Object?> toMap() {
    String tipoStr;
    switch (tipo) {
      case TipoOpcaoExtra.stringFloat:
        tipoStr = 'STRINGFLOAT';
        break;
      case TipoOpcaoExtra.floatFloat:
        tipoStr = 'FLOATFLOAT';
        break;
      case TipoOpcaoExtra.percentFloat:
        tipoStr = 'PERCENTFLOAT';
        break;
    }
    
    // ✅ CORREÇÃO: Incluir o ID quando for uma opção existente (id > 0)
    // IDs gerados pelo frontend são timestamps enormes, então consideramos > 1000000 como "novo"
    final isExisting = id > 0 && id < 1000000;
    
    return {
      if (isExisting) 'id': id, // ✅ Incluir ID apenas se for opção existente
      'nome': nome,
      'tipo': tipoStr,
    };
  }

  static ProductOpcaoExtra? tryFromMap(Map<String, Object?> map) {
    try {
      final id = map['id'];
      final nome = map['nome'];
      final tipoStr = map['tipo'] as String?;

      if (id == null || nome is! String || tipoStr == null) {
        return null;
      }

      TipoOpcaoExtra tipo;
      switch (tipoStr) {
        case 'STRINGFLOAT':
          tipo = TipoOpcaoExtra.stringFloat;
          break;
        case 'FLOATFLOAT':
          tipo = TipoOpcaoExtra.floatFloat;
          break;
        case 'PERCENTFLOAT':
          tipo = TipoOpcaoExtra.percentFloat;
          break;
        default:
          return null;
      }

      return ProductOpcaoExtra(
        id: int.parse(id.toString()),
        nome: nome.trim(),
        tipo: tipo,
      );
    } catch (e) {
      return null;
    }
  }
}

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
  final List<ProductOpcaoExtra> opcoesExtras;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ProductItem({
    required this.id,
    required this.name,
    required this.materials,
    this.opcoesExtras = const [],
    required this.createdAt,
    this.updatedAt,
  });

  ProductItem copyWith({
    String? name,
    List<ProductMaterial>? materials,
    List<ProductOpcaoExtra>? opcoesExtras,
    DateTime? updatedAt,
  }) =>
      ProductItem(
        id: id,
        name: name ?? this.name,
        materials: materials ?? this.materials,
        opcoesExtras: opcoesExtras ?? this.opcoesExtras,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toMap() {
    final opcoesExtrasMap = opcoesExtras.map((o) => o.toMap()).toList();
    
    return {
      'nome': name,
      'materiais': materials.map((m) => m.toMap()).toList(),
      'opcoesExtras': opcoesExtrasMap,
    };
  }

  static ProductItem? tryFromMap(Map<String, Object?> map) {
    try {
      final id = map['id'];
      final nome = map['nome'];
      final materiaisData = map['materiais'];
      final opcoesExtrasData = map['opcoesExtras'];

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

      final opcoesExtras = <ProductOpcaoExtra>[];
      if (opcoesExtrasData is List) {
        for (final o in opcoesExtrasData) {
          if (o is Map) {
            final item = ProductOpcaoExtra.tryFromMap(o.map((k, v) => MapEntry(k.toString(), v)));
            if (item != null) opcoesExtras.add(item);
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
        opcoesExtras: opcoesExtras,
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
    return 'ProductItem(id: $id, name: $name, materials: ${materials.length}, opcoesExtras: ${opcoesExtras.length}, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}