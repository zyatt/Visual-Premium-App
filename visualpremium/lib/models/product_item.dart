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

  // Verifica se é um ID temporário (gerado no frontend antes de salvar)
  bool get isTemporary => id >= 1000000;

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
    
    // Apenas envia o ID se for um ID real do banco (< 1000000)
    final isExisting = id > 0 && id < 1000000;
    
    return {
      if (isExisting) 'id': id,
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

class ProductAviso {
  final int id;
  final String mensagem;
  final int? materialId;
  final String? materialNome;
  final int? opcaoExtraId;
  final String? opcaoExtraNome;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductAviso({
    required this.id,
    required this.mensagem,
    this.materialId,
    this.materialNome,
    this.opcaoExtraId,
    this.opcaoExtraNome,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get temMaterialAtribuido => materialId != null;
  bool get temOpcaoExtraAtribuida => opcaoExtraId != null;
  bool get aguardandoAtribuicao => materialId == null && opcaoExtraId == null;
  bool get temAtribuicao => materialId != null || opcaoExtraId != null;
  bool get isTemporary => id >= 1000000;
  bool get opcaoExtraIsTemporary => opcaoExtraId != null && opcaoExtraId! >= 1000000;

  Map<String, Object?> toMap({Map<int, int>? tempOpcaoExtraIdMap}) {
    final isExisting = id > 0 && id < 1000000;
    
    // Se há um mapeamento de IDs temporários para IDs reais, usa ele
    int? finalOpcaoExtraId = opcaoExtraId;
    if (opcaoExtraId != null && opcaoExtraId! >= 1000000 && tempOpcaoExtraIdMap != null) {
      // Procura o ID real correspondente ao ID temporário
      finalOpcaoExtraId = tempOpcaoExtraIdMap[opcaoExtraId];
    } else if (opcaoExtraId != null && opcaoExtraId! >= 1000000) {
      // Se é temporário mas não tem mapeamento, não envia
      finalOpcaoExtraId = null;
    }
    
    return {
      if (isExisting) 'id': id,
      'mensagem': mensagem.trim(),
      'materialId': materialId,
      'opcaoExtraId': finalOpcaoExtraId,
    };
  }

  static ProductAviso? tryFromMap(Map<String, Object?> map) {
    try {
      final id = map['id'];
      final mensagem = map['mensagem'];
      final materialId = map['materialId'];
      final material = map['material'];
      final opcaoExtraId = map['opcaoExtraId'];
      final opcaoExtra = map['opcaoExtra'];
      
      final createdAtRaw = map['created_at'] ?? 
                          map['createdAt'] ?? 
                          map['criado_em'] ??
                          map['criadoEm'];
                          
      final updatedAtRaw = map['updated_at'] ?? 
                          map['updatedAt'] ?? 
                          map['atualizado_em'] ??
                          map['atualizadoEm'];

      if (id == null || mensagem is! String) {
        return null;
      }

      final cleanedMensagem = mensagem.trim();
      if (cleanedMensagem.isEmpty) return null;

      int? parsedMaterialId;
      if (materialId != null) {
        parsedMaterialId = (materialId is int) 
          ? materialId 
          : int.tryParse(materialId.toString());
      }
      
      String? materialNome;
      if (material is Map && material['nome'] != null) {
        materialNome = material['nome'].toString();
      }

      int? parsedOpcaoExtraId;
      if (opcaoExtraId != null) {
        parsedOpcaoExtraId = (opcaoExtraId is int) 
          ? opcaoExtraId 
          : int.tryParse(opcaoExtraId.toString());
      }
      
      String? opcaoExtraNome;
      if (opcaoExtra is Map && opcaoExtra['nome'] != null) {
        opcaoExtraNome = opcaoExtra['nome'].toString();
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

      return ProductAviso(
        id: int.parse(id.toString()),
        mensagem: cleanedMensagem,
        materialId: parsedMaterialId,
        materialNome: materialNome,
        opcaoExtraId: parsedOpcaoExtraId,
        opcaoExtraNome: opcaoExtraNome,
        createdAt: createdAt ?? DateTime.now(),
        updatedAt: updatedAt ?? DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }
  
  ProductAviso copyWith({
    int? id,
    String? mensagem,
    int? materialId,
    String? materialNome,
    int? opcaoExtraId,
    String? opcaoExtraNome,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductAviso(
      id: id ?? this.id,
      mensagem: mensagem ?? this.mensagem,
      materialId: materialId ?? this.materialId,
      materialNome: materialNome ?? this.materialNome,
      opcaoExtraId: opcaoExtraId ?? this.opcaoExtraId,
      opcaoExtraNome: opcaoExtraNome ?? this.opcaoExtraNome,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ProductItem {
  final String id;
  final String name;
  final List<ProductMaterial> materials;
  final List<ProductOpcaoExtra> opcoesExtras;
  final List<ProductAviso> avisos;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ProductItem({
    required this.id,
    required this.name,
    required this.materials,
    this.opcoesExtras = const [],
    this.avisos = const [],
    required this.createdAt,
    this.updatedAt,
  });

  ProductItem copyWith({
    String? name,
    List<ProductMaterial>? materials,
    List<ProductOpcaoExtra>? opcoesExtras,
    List<ProductAviso>? avisos,
    DateTime? updatedAt,
  }) =>
      ProductItem(
        id: id,
        name: name ?? this.name,
        materials: materials ?? this.materials,
        opcoesExtras: opcoesExtras ?? this.opcoesExtras,
        avisos: avisos ?? this.avisos,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toMap() {
    final opcoesExtrasMap = opcoesExtras.map((o) => o.toMap()).toList();
    
    // Filtra avisos que têm opções extras temporárias
    // Esses avisos não devem ser enviados na criação inicial
    final avisosParaEnviar = avisos.where((aviso) {
      // Se o aviso está vinculado a uma opção extra temporária, não envia
      if (aviso.opcaoExtraId != null && aviso.opcaoExtraId! >= 1000000) {
        return false;
      }
      return true;
    }).map((a) => a.toMap()).toList();
    
    return {
      'nome': name,
      'materiais': materials.map((m) => m.toMap()).toList(),
      'opcoesExtras': opcoesExtrasMap,
      'avisos': avisosParaEnviar,
    };
  }

  static ProductItem? tryFromMap(Map<String, Object?> map) {
    try {
      final id = map['id'];
      final nome = map['nome'];
      final materiaisData = map['materiais'];
      final opcoesExtrasData = map['opcoesExtras'];
      final avisosData = map['avisos'];

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

      final avisos = <ProductAviso>[];
      if (avisosData is List) {
        for (final a in avisosData) {
          if (a is Map) {
            final item = ProductAviso.tryFromMap(a.map((k, v) => MapEntry(k.toString(), v)));
            if (item != null) avisos.add(item);
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
        avisos: avisos,
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
    return 'ProductItem(id: $id, name: $name, materials: ${materials.length}, opcoesExtras: ${opcoesExtras.length}, avisos: ${avisos.length}, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}