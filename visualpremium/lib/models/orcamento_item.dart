import 'dart:convert';

enum TipoOpcaoExtra {
  stringFloat,
  floatFloat,
}

class DespesaAdicionalItem {
  final int id;
  final String descricao;
  final double valor;

  const DespesaAdicionalItem({
    required this.id,
    required this.descricao,
    required this.valor,
  });

  DespesaAdicionalItem copyWith({
    int? id,
    String? descricao,
    double? valor,
  }) =>
      DespesaAdicionalItem(
        id: id ?? this.id,
        descricao: descricao ?? this.descricao,
        valor: valor ?? this.valor,
      );

  Map<String, Object?> toMap() => {
        'descricao': descricao,
        'valor': valor,
      };

  static DespesaAdicionalItem? tryFromMap(Map<String, Object?> map) {
    try {
      final id = map['id'];
      final descricao = map['descricao'];
      final valor = map['valor'];

      if (id == null || descricao is! String || valor == null) {
        return null;
      }

      final valorDouble = (valor is int) ? valor.toDouble() : (valor is double ? valor : 0.0);

      return DespesaAdicionalItem(
        id: int.parse(id.toString()),
        descricao: descricao.trim(),
        valor: valorDouble,
      );
    } catch (e) {
      return null;
    }
  }
}

class OrcamentoOpcaoExtraItem {
  final int id;
  final int produtoOpcaoId;
  final String nome;
  final TipoOpcaoExtra tipo;
  final String? valorString;
  final double? valorFloat1;
  final double? valorFloat2;

  const OrcamentoOpcaoExtraItem({
    required this.id,
    required this.produtoOpcaoId,
    required this.nome,
    required this.tipo,
    this.valorString,
    this.valorFloat1,
    this.valorFloat2,
  });

  OrcamentoOpcaoExtraItem copyWith({
    int? id,
    int? produtoOpcaoId,
    String? nome,
    TipoOpcaoExtra? tipo,
    String? valorString,
    double? valorFloat1,
    double? valorFloat2,
  }) =>
      OrcamentoOpcaoExtraItem(
        id: id ?? this.id,
        produtoOpcaoId: produtoOpcaoId ?? this.produtoOpcaoId,
        nome: nome ?? this.nome,
        tipo: tipo ?? this.tipo,
        valorString: valorString ?? this.valorString,
        valorFloat1: valorFloat1 ?? this.valorFloat1,
        valorFloat2: valorFloat2 ?? this.valorFloat2,
      );

  Map<String, Object?> toMap() => {
        'produtoOpcaoId': produtoOpcaoId,
        'valorString': valorString,
        'valorFloat1': valorFloat1,
        'valorFloat2': valorFloat2,
      };

  static OrcamentoOpcaoExtraItem? tryFromMap(Map<String, Object?> map) {
    try {
      final id = map['id'];
      final produtoOpcaoId = map['produtoOpcaoId'];
      final valorString = map['valorString'] as String?;
      final valorFloat1 = map['valorFloat1'];
      final valorFloat2 = map['valorFloat2'];
      final produtoOpcao = map['produtoOpcao'];

      if (id == null || produtoOpcaoId == null || produtoOpcao == null) {
        return null;
      }

      final produtoOpcaoMap = produtoOpcao as Map<String, dynamic>;
      final nome = produtoOpcaoMap['nome'] as String?;
      final tipoStr = produtoOpcaoMap['tipo'] as String?;

      if (nome == null || tipoStr == null) {
        return null;
      }

      final tipo = tipoStr == 'STRING_FLOAT' 
          ? TipoOpcaoExtra.stringFloat 
          : TipoOpcaoExtra.floatFloat;

      return OrcamentoOpcaoExtraItem(
        id: int.parse(id.toString()),
        produtoOpcaoId: int.parse(produtoOpcaoId.toString()),
        nome: nome.trim(),
        tipo: tipo,
        valorString: valorString,
        valorFloat1: valorFloat1 != null 
            ? (valorFloat1 is int ? valorFloat1.toDouble() : valorFloat1 as double)
            : null,
        valorFloat2: valorFloat2 != null 
            ? (valorFloat2 is int ? valorFloat2.toDouble() : valorFloat2 as double)
            : null,
      );
    } catch (e) {
      return null;
    }
  }
}

class OrcamentoMaterialItem {
  final int id;
  final int materialId;
  final String materialNome;
  final String materialUnidade;
  final double materialCusto;
  final double quantidade;

  const OrcamentoMaterialItem({
    required this.id,
    required this.materialId,
    required this.materialNome,
    required this.materialUnidade,
    required this.materialCusto,
    required this.quantidade,
  });

  double get total {
    return materialCusto * quantidade;
  }

  OrcamentoMaterialItem copyWith({
    int? id,
    int? materialId,
    String? materialNome,
    String? materialUnidade,
    double? materialCusto,
    double? quantidade,
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
        'quantidade': quantidade,
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
      final quantidadeDouble = (quantidade is int) ? quantidade.toDouble() : (quantidade is double ? quantidade : 0.0);

      return OrcamentoMaterialItem(
        id: int.parse(id.toString()),
        materialId: int.parse(materialId.toString()),
        materialNome: nome.trim(),
        materialUnidade: unidade.trim(),
        materialCusto: custoDouble,
        quantidade: quantidadeDouble,
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
  final List<ProdutoOpcaoExtraItem> opcoesExtras;

  const ProdutoItem({
    required this.id,
    required this.nome,
    required this.materiais,
    this.opcoesExtras = const [],
  });

  static ProdutoItem? tryFromMap(Map<String, Object?> map) {
    try {
      final id = map['id'];
      final nome = map['nome'];
      final materiaisData = map['materiais'];
      final opcoesExtrasData = map['opcoesExtras'];

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

      final opcoesExtras = <ProdutoOpcaoExtraItem>[];
      if (opcoesExtrasData is List) {
        for (final o in opcoesExtrasData) {
          if (o is Map) {
            final item = ProdutoOpcaoExtraItem.tryFromMap(o.map((k, v) => MapEntry(k.toString(), v)));
            if (item != null) opcoesExtras.add(item);
          }
        }
      }

      return ProdutoItem(
        id: int.parse(id.toString()),
        nome: nome.trim(),
        materiais: materiais,
        opcoesExtras: opcoesExtras,
      );
    } catch (e) {
      return null;
    }
  }
}

class ProdutoOpcaoExtraItem {
  final int id;
  final String nome;
  final TipoOpcaoExtra tipo;

  const ProdutoOpcaoExtraItem({
    required this.id,
    required this.nome,
    required this.tipo,
  });

  static ProdutoOpcaoExtraItem? tryFromMap(Map<String, Object?> map) {
    try {
      final id = map['id'];
      final nome = map['nome'];
      final tipoStr = map['tipo'] as String?;

      if (id == null || nome is! String || tipoStr == null) {
        return null;
      }

      final tipo = tipoStr == 'STRING_FLOAT' 
          ? TipoOpcaoExtra.stringFloat 
          : TipoOpcaoExtra.floatFloat;

      return ProdutoOpcaoExtraItem(
        id: int.parse(id.toString()),
        nome: nome.trim(),
        tipo: tipo,
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
  final List<DespesaAdicionalItem> despesasAdicionais;
  final List<OrcamentoOpcaoExtraItem> opcoesExtras;
  final String formaPagamento;
  final String condicoesPagamento;
  final String prazoEntrega;
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
    this.despesasAdicionais = const [],
    this.opcoesExtras = const [],
    required this.formaPagamento,
    required this.condicoesPagamento,
    required this.prazoEntrega,
    required this.createdAt,
    required this.updatedAt,
  });

  double get totalMateriais {
   return materiais.fold(0.0, (sum, item) => sum + item.total);
  }

  double get totalDespesasAdicionais {
    return despesasAdicionais.fold(0.0, (sum, item) => sum + item.valor);
  }

  double get totalOpcoesExtras {
    double total = 0.0;
    
    for (final opcao in opcoesExtras) {
      if (opcao.tipo == TipoOpcaoExtra.stringFloat) {
        // Descrição + Valor: o valor está em float1
        total += opcao.valorFloat1 ?? 0.0;
      } else {
        // Minutos + Valor/Hora: calcular (minutos / 60) * valor_hora
        final minutos = opcao.valorFloat1 ?? 0.0;
        final valorHora = opcao.valorFloat2 ?? 0.0;
        final horas = minutos / 60.0;
        total += horas * valorHora;
      }
    }
    
    return total;
  }

  double get total {
    return totalMateriais + totalDespesasAdicionais + totalOpcoesExtras;
  }

  OrcamentoItem copyWith({
    int? id,
    String? cliente,
    int? numero,
    String? status,
    int? produtoId,
    String? produtoNome,
    List<OrcamentoMaterialItem>? materiais,
    List<DespesaAdicionalItem>? despesasAdicionais,
    List<OrcamentoOpcaoExtraItem>? opcoesExtras,
    String? formaPagamento,
    String? condicoesPagamento,
    String? prazoEntrega,
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
        despesasAdicionais: despesasAdicionais ?? this.despesasAdicionais,
        opcoesExtras: opcoesExtras ?? this.opcoesExtras,
        formaPagamento: formaPagamento ?? this.formaPagamento,
        condicoesPagamento: condicoesPagamento ?? this.condicoesPagamento,
        prazoEntrega: prazoEntrega ?? this.prazoEntrega,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toMap() => {
        'cliente': cliente,
        'numero': numero,
        'status': status,
        'produtoId': produtoId,
        'materiais': materiais.map((e) => e.toMap()).toList(),
        'despesasAdicionais': despesasAdicionais.map((e) => e.toMap()).toList(),
        'opcoesExtras': opcoesExtras.map((e) => e.toMap()).toList(),
        'formaPagamento': formaPagamento,
        'condicoesPagamento': condicoesPagamento,
        'prazoEntrega': prazoEntrega,
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
      final despesasData = map['despesasAdicionais'];
      final opcoesExtrasData = map['opcoesExtras'];
      final createdAt = map['createdAt'];
      final updatedAt = map['updatedAt'];
      final formaPagamento = map['formaPagamento'];
      final condicoesPagamento = map['condicoesPagamento'];
      final prazoEntrega = map['prazoEntrega'];

      if (id == null || cliente is! String || numero == null || status is! String || 
          produtoId == null || produtoData == null || formaPagamento is! String ||
          condicoesPagamento is! String || prazoEntrega is! String) {
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

      final despesasAdicionais = <DespesaAdicionalItem>[];
      if (despesasData is List) {
        for (final d in despesasData) {
          if (d is Map) {
            final item = DespesaAdicionalItem.tryFromMap(d.map((k, v) => MapEntry(k.toString(), v)));
            if (item != null) despesasAdicionais.add(item);
          }
        }
      }

      final opcoesExtras = <OrcamentoOpcaoExtraItem>[];
      if (opcoesExtrasData is List) {
        for (final o in opcoesExtrasData) {
          if (o is Map) {
            final item = OrcamentoOpcaoExtraItem.tryFromMap(o.map((k, v) => MapEntry(k.toString(), v)));
            if (item != null) opcoesExtras.add(item);
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
        despesasAdicionais: despesasAdicionais,
        opcoesExtras: opcoesExtras,
        formaPagamento: formaPagamento.trim(),
        condicoesPagamento: condicoesPagamento.trim(),
        prazoEntrega: prazoEntrega.trim(),
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