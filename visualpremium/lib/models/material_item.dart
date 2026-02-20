import 'dart:convert';

class MaterialItem {
  final String id;
  final String name;
  final String unit;
  final int costCents;
  final String quantity;
  final double? altura;        // Para m² (mm)
  final double? largura;       // Para m² (mm)
  final double? comprimento;   // Para m/l (mm)
  final bool sobras;           // Indica se o material gera sobras
  final DateTime createdAt;
  final DateTime? updatedAt;

  const MaterialItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.costCents,
    required this.quantity,
    this.altura,
    this.largura,
    this.comprimento,
    this.sobras = false,
    required this.createdAt,
    this.updatedAt,
  });

  MaterialItem copyWith({
    String? name,
    String? unit,
    int? costCents,
    String? quantity,
    double? altura,
    double? largura,
    double? comprimento,
    bool? sobras,
    DateTime? updatedAt,
  }) =>
      MaterialItem(
        id: id,
        name: name ?? this.name,
        unit: unit ?? this.unit,
        costCents: costCents ?? this.costCents,
        quantity: quantity ?? this.quantity,
        altura: altura ?? this.altura,
        largura: largura ?? this.largura,
        comprimento: comprimento ?? this.comprimento,
        sobras: sobras ?? this.sobras,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toMap() {
    final map = {
      'nome': name,
      'unidade': unit,
      'custo': costCents / 100.0,
      'quantidade': double.tryParse(quantity) ?? 0,
      'sobras': sobras,
    };
    
    if (altura != null) map['altura'] = altura!;
    if (largura != null) map['largura'] = largura!;
    if (comprimento != null) map['comprimento'] = comprimento!;
    
    return map;
  }

  static MaterialItem? tryFromMap(Map<String, Object?> map) {
    try {
      final id = map['id'];
      final nome = map['nome'];
      final unidade = map['unidade'];
      final custo = map['custo'];
      final quantidade = map['quantidade'];
      final alturaRaw = map['altura'];
      final larguraRaw = map['largura'];
      final comprimentoRaw = map['comprimento'];
      final sobrasRaw = map['sobras'];
      
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

      // Parse altura, largura e comprimento
      double? altura;
      double? largura;
      double? comprimento;
      
      if (alturaRaw != null) {
        if (alturaRaw is num) {
          altura = alturaRaw.toDouble();
        } else if (alturaRaw is String) {
          altura = double.tryParse(alturaRaw);
        }
      }
      
      if (larguraRaw != null) {
        if (larguraRaw is num) {
          largura = larguraRaw.toDouble();
        } else if (larguraRaw is String) {
          largura = double.tryParse(larguraRaw);
        }
      }

      if (comprimentoRaw != null) {
        if (comprimentoRaw is num) {
          comprimento = comprimentoRaw.toDouble();
        } else if (comprimentoRaw is String) {
          comprimento = double.tryParse(comprimentoRaw);
        }
      }

      // Parse sobras
      bool sobras = false;
      if (sobrasRaw is bool) {
        sobras = sobrasRaw;
      } else if (sobrasRaw is int) {
        sobras = sobrasRaw != 0;
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

      return MaterialItem(
        id: idStr,
        name: cleanedName,
        unit: cleanedUnit,
        costCents: costCents,
        quantity: quantidadeStr,
        altura: altura,
        largura: largura,
        comprimento: comprimento,
        sobras: sobras,
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
    return 'MaterialItem(id: $id, name: $name, unit: $unit, altura: $altura, largura: $largura, comprimento: $comprimento, sobras: $sobras, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}