import 'dart:convert';

enum TipoOpcaoExtra {
  stringFloat,
  floatFloat,
  percentFloat, // ✅ NOVO TIPO ADICIONADO
}

class PedidoOpcaoExtraItem {
  final int id;
  final int produtoOpcaoId;
  final String nome;
  final TipoOpcaoExtra tipo;
  final String? valorString;
  final double? valorFloat1;
  final double? valorFloat2;

  const PedidoOpcaoExtraItem({
    required this.id,
    required this.produtoOpcaoId,
    required this.nome,
    required this.tipo,
    this.valorString,
    this.valorFloat1,
    this.valorFloat2,
  });

  PedidoOpcaoExtraItem copyWith({
    int? id,
    int? produtoOpcaoId,
    String? nome,
    TipoOpcaoExtra? tipo,
    String? valorString,
    double? valorFloat1,
    double? valorFloat2,
  }) =>
      PedidoOpcaoExtraItem(
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

  static PedidoOpcaoExtraItem? tryFromMap(Map<String, Object?> map) {
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

      final tipo = tipoStr == 'STRINGFLOAT' 
          ? TipoOpcaoExtra.stringFloat 
          : tipoStr == 'PERCENTFLOAT'
              ? TipoOpcaoExtra.percentFloat
              : TipoOpcaoExtra.floatFloat;

      return PedidoOpcaoExtraItem(
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

class PedidoDespesaAdicionalItem {
  final int id;
  final String descricao;
  final double valor;

  const PedidoDespesaAdicionalItem({
    required this.id,
    required this.descricao,
    required this.valor,
  });

  PedidoDespesaAdicionalItem copyWith({
    int? id,
    String? descricao,
    double? valor,
  }) =>
      PedidoDespesaAdicionalItem(
        id: id ?? this.id,
        descricao: descricao ?? this.descricao,
        valor: valor ?? this.valor,
      );

  Map<String, Object?> toMap() => {
        'descricao': descricao,
        'valor': valor,
      };

  static PedidoDespesaAdicionalItem? tryFromMap(Map<String, Object?> map) {
    try {
      final id = map['id'];
      final descricao = map['descricao'];
      final valor = map['valor'];

      if (id == null || descricao is! String || valor == null) {
        return null;
      }

      final valorDouble = (valor is int) ? valor.toDouble() : (valor is double ? valor : 0.0);

      return PedidoDespesaAdicionalItem(
        id: int.parse(id.toString()),
        descricao: descricao.trim(),
        valor: valorDouble,
      );
    } catch (e) {
      return null;
    }
  }
}

class PedidoMaterialItem {
  final int id;
  final int materialId;
  final String materialNome;
  final String materialUnidade;
  final double materialCusto;
  final double quantidade;

  const PedidoMaterialItem({
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

  PedidoMaterialItem copyWith({
    int? id,
    int? materialId,
    String? materialNome,
    String? materialUnidade,
    double? materialCusto,
    double? quantidade,
  }) =>
      PedidoMaterialItem(
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

  static PedidoMaterialItem? tryFromMap(Map<String, Object?> map) {
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

      return PedidoMaterialItem(
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

class PedidoItem {
  final int id;
  final String cliente;
  final int? numero;
  final String status;
  final int produtoId;
  final String produtoNome;
  final List<PedidoMaterialItem> materiais;
  final List<PedidoDespesaAdicionalItem> despesasAdicionais;
  final List<PedidoOpcaoExtraItem> opcoesExtras;
  final String formaPagamento;
  final String condicoesPagamento;
  final String prazoEntrega;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? orcamentoId;
  final int? orcamentoNumero;

  const PedidoItem({
    required this.id,
    required this.cliente,
    this.numero,
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
    this.orcamentoId,
    this.orcamentoNumero,
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
      } else if (opcao.tipo == TipoOpcaoExtra.floatFloat) {
        // ✅ CORRIGIDO: Horas × Valor/Hora (não precisa dividir por 60)
        final horas = opcao.valorFloat1 ?? 0.0;
        final valorHora = opcao.valorFloat2 ?? 0.0;
        total += horas * valorHora;  // ✅ CÁLCULO DIRETO
      } else if (opcao.tipo == TipoOpcaoExtra.percentFloat) {
        // % + Valor: calcular (percentual / 100) * valor
        final percentual = opcao.valorFloat1 ?? 0.0;
        final valor = opcao.valorFloat2 ?? 0.0;
        total += (percentual / 100.0) * valor;
      }
    }
    
    return total;
  }

  double get total {
    return totalMateriais + totalDespesasAdicionais + totalOpcoesExtras;
  }

  PedidoItem copyWith({
    int? id,
    String? cliente,
    int? numero,
    String? status,
    int? produtoId,
    String? produtoNome,
    List<PedidoMaterialItem>? materiais,
    List<PedidoDespesaAdicionalItem>? despesasAdicionais,
    List<PedidoOpcaoExtraItem>? opcoesExtras,
    String? formaPagamento,
    String? condicoesPagamento,
    String? prazoEntrega,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? orcamentoId,
    int? orcamentoNumero,
  }) =>
      PedidoItem(
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
        orcamentoId: orcamentoId ?? this.orcamentoId,
        orcamentoNumero: orcamentoNumero ?? this.orcamentoNumero,
      );

  Map<String, Object?> toMap() {
    final map = <String, Object?>{
      'cliente': cliente,
      'status': status,
      'produtoId': produtoId,
      'materiais': materiais.map((e) => e.toMap()).toList(),
      'despesasAdicionais': despesasAdicionais.map((e) => e.toMap()).toList(),
      'opcoesExtras': opcoesExtras.map((e) => e.toMap()).toList(),
      'formaPagamento': formaPagamento,
      'condicoesPagamento': condicoesPagamento,
      'prazoEntrega': prazoEntrega,
    };
    
    if (numero != null) {
      map['numero'] = numero;
    }
    
    return map;
  }

  static PedidoItem? tryFromMap(Map<String, Object?> map) {
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
      
      final orcamentoId = map['orcamentoId'];
      final orcamentoData = map['orcamento'];
      int? orcamentoNumero;
      if (orcamentoData != null && orcamentoData is Map) {
        final orcMap = orcamentoData as Map<String, dynamic>;
        orcamentoNumero = orcMap['numero'] != null ? int.tryParse(orcMap['numero'].toString()) : null;
      }

      if (id == null || cliente is! String || status is! String || 
          produtoId == null || produtoData == null || formaPagamento is! String ||
          condicoesPagamento is! String || prazoEntrega is! String) {
        return null;
      }

      final produtoMap = produtoData as Map<String, dynamic>;
      final produtoNome = produtoMap['nome'] as String?;

      if (produtoNome == null) return null;

      final materiais = <PedidoMaterialItem>[];
      if (materiaisData is List) {
        for (final m in materiaisData) {
          if (m is Map) {
            final item = PedidoMaterialItem.tryFromMap(m.map((k, v) => MapEntry(k.toString(), v)));
            if (item != null) materiais.add(item);
          }
        }
      }

      final despesasAdicionais = <PedidoDespesaAdicionalItem>[];
      if (despesasData is List) {
        for (final d in despesasData) {
          if (d is Map) {
            final item = PedidoDespesaAdicionalItem.tryFromMap(d.map((k, v) => MapEntry(k.toString(), v)));
            if (item != null) despesasAdicionais.add(item);
          }
        }
      }

      final opcoesExtras = <PedidoOpcaoExtraItem>[];
      if (opcoesExtrasData is List) {
        for (final o in opcoesExtrasData) {
          if (o is Map) {
            final item = PedidoOpcaoExtraItem.tryFromMap(o.map((k, v) => MapEntry(k.toString(), v)));
            if (item != null) opcoesExtras.add(item);
          }
        }
      }

      return PedidoItem(
        id: int.parse(id.toString()),
        cliente: cliente.trim(),
        numero: numero != null ? int.parse(numero.toString()) : null,
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
        orcamentoId: orcamentoId != null ? int.tryParse(orcamentoId.toString()) : null,
        orcamentoNumero: orcamentoNumero,
      );
    } catch (e) {
      return null;
    }
  }

  static List<PedidoItem> decodeList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final out = <PedidoItem>[];
    for (final e in decoded) {
      if (e is Map) {
        final map = e.map((k, v) => MapEntry(k.toString(), v));
        final item = tryFromMap(map);
        if (item != null) out.add(item);
      }
    }
    return out;
  }
}