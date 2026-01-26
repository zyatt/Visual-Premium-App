import 'dart:convert';

class OrcamentoMaterialItem {
  final int id;
  final int materialId;
  final String materialNome;
  final String materialUnidade;
  final double materialCusto;
  final String quantidade; // Mudado de double para String

  const OrcamentoMaterialItem({
    required this.id,
    required this.materialId,
    required this.materialNome,
    required this.materialUnidade,
    required this.materialCusto,
    required this.quantidade,
  });

  double get total {
    // Parse da string para calcular o total
    final qty = double.tryParse(quantidade) ?? 0.0;
    return materialCusto * qty;
  }

  OrcamentoMaterialItem copyWith({
    int? id,
    int? materialId,
    String? materialNome,
    String? materialUnidade,
    double? materialCusto,
    String? quantidade,
  }) =>
      OrcamentoMaterialItem(
        id: id ?? this.id,
        materialId: materialId ?? this.materialId,
        materialNome: materialNome ?? this.materialNome,
        materialUnidade: materialUnidade ?? this.materialUnidade,
        materialCusto: materialCusto ?? this.materialCusto,
        quantidade: quantidade ?? this.quantidade,
      );

  Map<String, Object?> toMap() => {
        'materialId': materialId,
        'quantidade': quantidade, // Envia como string
      };

  static OrcamentoMaterialItem? tryFromMap(Map<String, Object?> map) {
    try {
      final id = map['id'];
      final materialId = map['materialId'];
      final quantidade = map['quantidade'];
      final material = map['material'];

      if (id == null || materialId == null || quantidade == null || material == null) {
        return null;
      }

      final materialMap = material as Map<String, dynamic>;
      final nome = materialMap['nome'] as String?;
      final custo = materialMap['custo'];
      final unidade = materialMap['unidade'] as String?;

      if (nome == null || custo == null || unidade == null) {
        return null;
      }

      final custoDouble = (custo is int) ? custo.toDouble() : (custo is double ? custo : 0.0);
      
      // Converte quantidade para string
      final quantidadeStr = quantidade.toString();

      return OrcamentoMaterialItem(
        id: int.parse(id.toString()),
        materialId: int.parse(materialId.toString()),
        materialNome: nome.trim(),
        materialUnidade: unidade.trim(),
        materialCusto: custoDouble,
        quantidade: quantidadeStr,
      );
    } catch (e) {
      return null;
    }
  }
}

class ProdutoItem {
  final int id;
  final String nome;
  final List<ProdutoMaterialItem> materiais;

  const ProdutoItem({
    required this.id,
    required this.nome,
    required this.materiais,
  });

  static ProdutoItem? tryFromMap(Map<String, Object?> map) {
    try {
      final id = map['id'];
      final nome = map['nome'];
      final materiaisData = map['materiais'];

      if (id == null || nome is! String) {
        return null;
      }

      final materiais = <ProdutoMaterialItem>[];
      if (materiaisData is List) {
        for (final m in materiaisData) {
          if (m is Map) {
            final item = ProdutoMaterialItem.tryFromMap(m.map((k, v) => MapEntry(k.toString(), v)));
            if (item != null) materiais.add(item);
          }
        }
      }

      return ProdutoItem(
        id: int.parse(id.toString()),
        nome: nome.trim(),
        materiais: materiais,
      );
    } catch (e) {
      return null;
    }
  }
}

class ProdutoMaterialItem {
  final int materialId;
  final String materialNome;
  final String materialUnidade;
  final double materialCusto;

  const ProdutoMaterialItem({
    required this.materialId,
    required this.materialNome,
    required this.materialUnidade,
    required this.materialCusto,
  });

  static ProdutoMaterialItem? tryFromMap(Map<String, Object?> map) {
    try {
      final materialData = map['material'];
      if (materialData == null) return null;

      final materialMap = materialData as Map<String, dynamic>;
      final id = materialMap['id'];
      final nome = materialMap['nome'];
      final custo = materialMap['custo'];
      final unidade = materialMap['unidade'];

      if (id == null || nome is! String || custo == null || unidade is! String) {
        return null;
      }

      final custoDouble = (custo is int) ? custo.toDouble() : (custo is double ? custo : 0.0);

      return ProdutoMaterialItem(
        materialId: int.parse(id.toString()),
        materialNome: nome.trim(),
        materialUnidade: unidade.trim(),
        materialCusto: custoDouble,
      );
    } catch (e) {
      return null;
    }
  }
}

class OrcamentoItem {
  final int id;
  final String cliente;
  final int numero;
  final String status;
  final int produtoId;
  final String produtoNome;
  final List<OrcamentoMaterialItem> materiais;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OrcamentoItem({
    required this.id,
    required this.cliente,
    required this.numero,
    required this.status,
    required this.produtoId,
    required this.produtoNome,
    required this.materiais,
    required this.createdAt,
    required this.updatedAt,
  });

  double get total {
    return materiais.fold(0.0, (sum, item) => sum + item.total);
  }

  OrcamentoItem copyWith({
    int? id,
    String? cliente,
    int? numero,
    String? status,
    int? produtoId,
    String? produtoNome,
    List<OrcamentoMaterialItem>? materiais,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      OrcamentoItem(
        id: id ?? this.id,
        cliente: cliente ?? this.cliente,
        numero: numero ?? this.numero,
        status: status ?? this.status,
        produtoId: produtoId ?? this.produtoId,
        produtoNome: produtoNome ?? this.produtoNome,
        materiais: materiais ?? this.materiais,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toMap() => {
        'cliente': cliente,
        'numero': numero,
        'status': status,
        'produtoId': produtoId,
        'materiais': materiais.map((e) => e.toMap()).toList(),
      };

  static OrcamentoItem? tryFromMap(Map<String, Object?> map) {
    try {
      final id = map['id'];
      final cliente = map['cliente'];
      final numero = map['numero'];
      final status = map['status'];
      final produtoId = map['produtoId'];
      final produtoData = map['produto'];
      final materiaisData = map['materiais'];
      final createdAt = map['createdAt'];
      final updatedAt = map['updatedAt'];

      if (id == null || cliente is! String || numero == null || status is! String || produtoId == null || produtoData == null) {
        return null;
      }

      final produtoMap = produtoData as Map<String, dynamic>;
      final produtoNome = produtoMap['nome'] as String?;

      if (produtoNome == null) return null;

      final materiais = <OrcamentoMaterialItem>[];
      if (materiaisData is List) {
        for (final m in materiaisData) {
          if (m is Map) {
            final item = OrcamentoMaterialItem.tryFromMap(m.map((k, v) => MapEntry(k.toString(), v)));
            if (item != null) materiais.add(item);
          }
        }
      }

      return OrcamentoItem(
        id: int.parse(id.toString()),
        cliente: cliente.trim(),
        numero: int.parse(numero.toString()),
        status: status.trim(),
        produtoId: int.parse(produtoId.toString()),
        produtoNome: produtoNome.trim(),
        materiais: materiais,
        createdAt: createdAt != null ? DateTime.parse(createdAt.toString()) : DateTime.now(),
        updatedAt: updatedAt != null ? DateTime.parse(updatedAt.toString()) : DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  static List<OrcamentoItem> decodeList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final out = <OrcamentoItem>[];
    for (final e in decoded) {
      if (e is Map) {
        final map = e.map((k, v) => MapEntry(k.toString(), v));
        final item = tryFromMap(map);
        if (item != null) out.add(item);
      }
    }
    return out;
  }

  static List<ProdutoItem> decodeProdutoList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final out = <ProdutoItem>[];
    for (final e in decoded) {
      if (e is Map) {
        final map = e.map((k, v) => MapEntry(k.toString(), v));
        final item = ProdutoItem.tryFromMap(map);
        if (item != null) out.add(item);
      }
    }
    return out;
  }
}