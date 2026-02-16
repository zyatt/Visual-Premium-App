import 'dart:convert';

enum TipoOpcaoExtra {
  stringFloat,
  floatFloat,
  percentFloat,
}

class InformacaoAdicionalItem {
  final int id;
  final DateTime data;
  final String descricao;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const InformacaoAdicionalItem({
    required this.id,
    required this.data,
    required this.descricao,
    this.createdAt,
    this.updatedAt,
  });

  InformacaoAdicionalItem copyWith({
    int? id,
    DateTime? data,
    String? descricao,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      InformacaoAdicionalItem(
        id: id ?? this.id,
        data: data ?? this.data,
        descricao: descricao ?? this.descricao,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toMap() => {
        // ✅ Só envia o ID se for um ID real do banco (< 1 bilhão)
        // IDs temporários são timestamps enormes (> 1 trilhão) e não devem ser enviados
        if (id != 0 && id < 1000000000) 'id': id,
        'data': data.toIso8601String(),
        'descricao': descricao,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  static InformacaoAdicionalItem? tryFromMap(Map<String, Object?> map) {
    try {
      final id = map['id'];
      final data = map['data'];
      final descricao = map['descricao'];
      final createdAt = map['createdAt'];
      final updatedAt = map['updatedAt'];

      if (id == null || data == null || descricao is! String) {
        return null;
      }

      return InformacaoAdicionalItem(
        id: int.parse(id.toString()),
        data: DateTime.parse(data.toString()).toLocal(),
        descricao: descricao.trim(),
        createdAt: createdAt != null ? DateTime.parse(createdAt.toString()).toLocal() : null,
        updatedAt: updatedAt != null ? DateTime.parse(updatedAt.toString()).toLocal() : null,
      );
    } catch (e) {
      return null;
    }
  }
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

      final tipo = tipoStr == 'STRINGFLOAT' 
          ? TipoOpcaoExtra.stringFloat 
          : tipoStr == 'PERCENTFLOAT'
              ? TipoOpcaoExtra.percentFloat
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
  final double? altura;
  final double? largura;
  final double? alturaSobra;      // Para m²: altura em mm
  final double? larguraSobra;     // Para m²: largura em mm
  final double? quantidadeSobra;  // Para outras unidades: quantidade
  final double? valorSobra;       // Valor calculado com impostos

  const OrcamentoMaterialItem({
    required this.id,
    required this.materialId,
    required this.materialNome,
    required this.materialUnidade,
    required this.materialCusto,
    required this.quantidade,
    this.altura,
    this.largura,
    this.alturaSobra,
    this.larguraSobra,
    this.quantidadeSobra,
    this.valorSobra,
  });

  double get total {
    double baseTotal = materialCusto * quantidade;
    // Adiciona valor da sobra ao total
    if (valorSobra != null) {
      baseTotal += valorSobra!;
    }
    return baseTotal;
  }
  
  // Indica se o material tem sobra configurada
  bool get temSobra {
    // m² usa altura e largura
    if (materialUnidade.toLowerCase() == 'm²' || materialUnidade.toLowerCase() == 'm2') {
      return alturaSobra != null && larguraSobra != null && valorSobra != null;
    }
    // Outras unidades usam quantidade
    return quantidadeSobra != null && valorSobra != null;
  }

  OrcamentoMaterialItem copyWith({
    int? id,
    int? materialId,
    String? materialNome,
    String? materialUnidade,
    double? materialCusto,
    double? quantidade,
    double? altura,
    double? largura,
    double? alturaSobra,
    double? larguraSobra,
    double? quantidadeSobra,
    double? valorSobra,
    bool clearSobra = false,
  }) =>
      OrcamentoMaterialItem(
        id: id ?? this.id,
        materialId: materialId ?? this.materialId,
        materialNome: materialNome ?? this.materialNome,
        materialUnidade: materialUnidade ?? this.materialUnidade,
        materialCusto: materialCusto ?? this.materialCusto,
        quantidade: quantidade ?? this.quantidade,
        altura: altura ?? this.altura,
        largura: largura ?? this.largura,
        alturaSobra: clearSobra ? null : (alturaSobra ?? this.alturaSobra),
        larguraSobra: clearSobra ? null : (larguraSobra ?? this.larguraSobra),
        quantidadeSobra: clearSobra ? null : (quantidadeSobra ?? this.quantidadeSobra),
        valorSobra: clearSobra ? null : (valorSobra ?? this.valorSobra),
      );

  Map<String, Object?> toMap() {
    final map = {
      'materialId': materialId,
      'quantidade': quantidade,
    };
    
    // Adiciona campos de sobra se existirem
    if (alturaSobra != null) map['alturaSobra'] = alturaSobra!;
    if (larguraSobra != null) map['larguraSobra'] = larguraSobra!;
    if (quantidadeSobra != null) map['quantidadeSobra'] = quantidadeSobra!;
    if (valorSobra != null) map['valorSobra'] = valorSobra!;
    
    return map;
  }

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
      final unidade = materialMap['unidade'] as String?;

      if (nome == null || unidade == null) {
        return null;
      }

      final custoRaw = map['custo'] ?? materialMap['custo'];
      if (custoRaw == null) return null;

      final custoDouble = (custoRaw is int) ? custoRaw.toDouble() : (custoRaw is double ? custoRaw : 0.0);
      final quantidadeDouble = (quantidade is int) ? quantidade.toDouble() : (quantidade is double ? quantidade : 0.0);

      // Parse altura e largura do material
      double? altura;
      double? largura;
      
      final alturaRaw = materialMap['altura'];
      final larguraRaw = materialMap['largura'];
      
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

      // Parse campos de sobra
      double? alturaSobra;
      double? larguraSobra;
      double? quantidadeSobra;
      double? valorSobra;
      
      final alturaSobraRaw = map['alturaSobra'];
      final larguraSobraRaw = map['larguraSobra'];
      final quantidadeSobraRaw = map['quantidadeSobra'];
      final valorSobraRaw = map['valorSobra'];
      
      if (alturaSobraRaw != null) {
        if (alturaSobraRaw is num) {
          alturaSobra = alturaSobraRaw.toDouble();
        } else if (alturaSobraRaw is String) {
          alturaSobra = double.tryParse(alturaSobraRaw);
        }
      }
      
      if (larguraSobraRaw != null) {
        if (larguraSobraRaw is num) {
          larguraSobra = larguraSobraRaw.toDouble();
        } else if (larguraSobraRaw is String) {
          larguraSobra = double.tryParse(larguraSobraRaw);
        }
      }
      
      if (quantidadeSobraRaw != null) {
        if (quantidadeSobraRaw is num) {
          quantidadeSobra = quantidadeSobraRaw.toDouble();
        } else if (quantidadeSobraRaw is String) {
          quantidadeSobra = double.tryParse(quantidadeSobraRaw);
        }
      }
      
      if (valorSobraRaw != null) {
        if (valorSobraRaw is num) {
          valorSobra = valorSobraRaw.toDouble();
        } else if (valorSobraRaw is String) {
          valorSobra = double.tryParse(valorSobraRaw);
        }
      }

      return OrcamentoMaterialItem(
        id: int.parse(id.toString()),
        materialId: int.parse(materialId.toString()),
        materialNome: nome.trim(),
        materialUnidade: unidade.trim(),
        materialCusto: custoDouble,
        quantidade: quantidadeDouble,
        altura: altura,
        largura: largura,
        alturaSobra: alturaSobra,
        larguraSobra: larguraSobra,
        quantidadeSobra: quantidadeSobra,
        valorSobra: valorSobra,
      );
    } catch (e) {
      return null;
    }
  }
}

class ProdutoAvisoItem {
  final int id;
  final String mensagem;
  final int? materialId;
  final String? materialNome;
  final int? opcaoExtraId;
  final String? opcaoExtraNome;
  
  const ProdutoAvisoItem({
    required this.id,
    required this.mensagem,
    this.materialId,
    this.materialNome,
    this.opcaoExtraId,
    this.opcaoExtraNome,
  });

  bool get isAvisoGeral => materialId == null && opcaoExtraId == null;
  bool get isAvisoMaterial => materialId != null;
  bool get isAvisoOpcaoExtra => opcaoExtraId != null;

  static ProdutoAvisoItem? tryFromMap(Map<String, Object?> map) {
    try {
      final id = map['id'];
      final mensagem = map['mensagem'];
      final materialId = map['materialId'];
      final material = map['material'];
      final opcaoExtraId = map['opcaoExtraId'];
      final opcaoExtra = map['opcaoExtra'];

      if (id == null || mensagem is! String) {
        return null;
      }

      int? parsedMaterialId;
      String? materialNome;
      int? parsedOpcaoExtraId;
      String? opcaoExtraNome; 
      if (materialId != null) {
        parsedMaterialId = (materialId is int) 
            ? materialId 
            : int.tryParse(materialId.toString());
      }

      if (material is Map && material['nome'] != null) {
        materialNome = material['nome'].toString();
      }

      if (opcaoExtraId != null) {
        parsedOpcaoExtraId = (opcaoExtraId is int) 
            ? opcaoExtraId 
            : int.tryParse(opcaoExtraId.toString());
      }

      if (opcaoExtra is Map && opcaoExtra['nome'] != null) {
        opcaoExtraNome = opcaoExtra['nome'].toString();
      }

      return ProdutoAvisoItem(
        id: int.parse(id.toString()),
        mensagem: mensagem.trim(),
        materialId: parsedMaterialId,
        materialNome: materialNome,
        opcaoExtraId: parsedOpcaoExtraId,
        opcaoExtraNome: opcaoExtraNome,
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
  final double? altura;      // NOVO CAMPO
  final double? largura;     // NOVO CAMPO

  const ProdutoMaterialItem({
    required this.materialId,
    required this.materialNome,
    required this.materialUnidade,
    required this.materialCusto,
    this.altura,               // NOVO CAMPO
    this.largura,              // NOVO CAMPO
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

      // Parse altura e largura
      double? altura;
      double? largura;
      
      final alturaRaw = materialMap['altura'];
      final larguraRaw = materialMap['largura'];
      
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

      return ProdutoMaterialItem(
        materialId: int.parse(id.toString()),
        materialNome: nome.trim(),
        materialUnidade: unidade.trim(),
        materialCusto: custoDouble,
        altura: altura,
        largura: largura,
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
  final List<ProdutoAvisoItem> avisos;

  const ProdutoItem({
    required this.id,
    required this.nome,
    required this.materiais,
    required this.opcoesExtras,
    this.avisos = const [],
  });

  static ProdutoItem? tryFromMap(Map<String, Object?> map) {
    try {
      final id = map['id'];
      final nome = map['nome'];
      final materiaisData = map['materiais'];
      final opcoesExtrasData = map['opcoesExtras'];
      final avisosData = map['avisos'];

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

      final avisos = <ProdutoAvisoItem>[];
      if (avisosData is List) {
        for (final a in avisosData) {
          if (a is Map) {
            final item = ProdutoAvisoItem.tryFromMap(a.map((k, v) => MapEntry(k.toString(), v)));
            if (item != null) avisos.add(item);
          }
        }
      }

      return ProdutoItem(
        id: int.parse(id.toString()),
        nome: nome.trim(),
        materiais: materiais,
        opcoesExtras: opcoesExtras,
        avisos: avisos,
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
  final List<InformacaoAdicionalItem> informacoesAdicionais;
  final String formaPagamento;
  final String condicoesPagamento;
  final String prazoEntrega;
  final bool rascunho;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? valorSugerido;

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
    this.informacoesAdicionais = const [],
    required this.formaPagamento,
    required this.condicoesPagamento,
    required this.prazoEntrega,
    this.rascunho = false,
    required this.createdAt,
    required this.updatedAt,
    this.valorSugerido,
  });

  double get totalMateriais {
   return materiais.fold(0.0, (sum, item) => sum + item.total);
  }

  double get totalDespesasAdicionais {
    return despesasAdicionais.fold(0.0, (sum, item) => sum + item.valor);
  }

  /// Soma das opções extras não-percentuais (STRINGFLOAT + FLOATFLOAT).
  double get totalOpcoesExtrasNaoPercentuais {
    double total = 0.0;
    for (final opcao in opcoesExtras) {
      if (opcao.tipo == TipoOpcaoExtra.stringFloat) {
        total += opcao.valorFloat1 ?? 0.0;
      } else if (opcao.tipo == TipoOpcaoExtra.floatFloat) {
        final f1 = opcao.valorFloat1 ?? 0.0;
        final f2 = opcao.valorFloat2 ?? 0.0;
        total += f1 * f2;
      }
    }
    return total;
  }

  /// Base de cálculo para opções percentuais:
  /// materiais + despesas adicionais + opções extras não-percentuais.
  double get baseCalculoPercentual {
    return totalMateriais + totalDespesasAdicionais + totalOpcoesExtrasNaoPercentuais;
  }

  /// Soma de TODAS as opções extras, aplicando o percentual sobre a base completa.
  double get totalOpcoesExtras {
    double total = totalOpcoesExtrasNaoPercentuais;
    final base = baseCalculoPercentual;

    for (final opcao in opcoesExtras) {
      if (opcao.tipo == TipoOpcaoExtra.percentFloat) {
        final percentual = opcao.valorFloat1 ?? 0.0;
        total += (percentual / 100.0) * base;
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
    List<InformacaoAdicionalItem>? informacoesAdicionais,
    String? formaPagamento,
    String? condicoesPagamento,
    String? prazoEntrega,
    bool? rascunho,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? valorSugerido,
  }) {
    return OrcamentoItem(
      id: id ?? this.id,
      cliente: cliente ?? this.cliente,
      numero: numero ?? this.numero,
      status: status ?? this.status,
      produtoId: produtoId ?? this.produtoId,
      produtoNome: produtoNome ?? this.produtoNome,
      materiais: materiais ?? this.materiais,
      despesasAdicionais: despesasAdicionais ?? this.despesasAdicionais,
      opcoesExtras: opcoesExtras ?? this.opcoesExtras,
      informacoesAdicionais: informacoesAdicionais ?? this.informacoesAdicionais,
      formaPagamento: formaPagamento ?? this.formaPagamento,
      condicoesPagamento: condicoesPagamento ?? this.condicoesPagamento,
      prazoEntrega: prazoEntrega ?? this.prazoEntrega,
      rascunho: rascunho ?? this.rascunho,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      valorSugerido: valorSugerido ?? this.valorSugerido,
    );
  }

  Map<String, Object?> toMap({bool finalizar = false}) => {
        'cliente': cliente,
        'numero': numero,
        'status': status,
        'produtoId': produtoId,
        'materiais': materiais.map((e) => e.toMap()).toList(),
        'despesasAdicionais': despesasAdicionais.map((e) => e.toMap()).toList(),
        'opcoesExtras': opcoesExtras.map((e) => e.toMap()).toList(),
        'informacoesAdicionais': informacoesAdicionais.map((e) => e.toMap()).toList(),
        'formaPagamento': formaPagamento,
        'condicoesPagamento': condicoesPagamento,
        'prazoEntrega': prazoEntrega,
        'rascunho': rascunho, // ✅ ENVIAR O CAMPO RASCUNHO
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
      final informacoesAdicionaisData = map['informacoesAdicionais'];
      final createdAt = map['createdAt'];
      final updatedAt = map['updatedAt'];
      final formaPagamento = map['formaPagamento'];
      final condicoesPagamento = map['condicoesPagamento'];
      final prazoEntrega = map['prazoEntrega'];
      final rascunho = map['rascunho'];
      final valorSugeridoData = map['valorSugerido'];

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

      final informacoesAdicionais = <InformacaoAdicionalItem>[];
      if (informacoesAdicionaisData is List) {
        for (final i in informacoesAdicionaisData) {
          if (i is Map) {
            final item = InformacaoAdicionalItem.tryFromMap(i.map((k, v) => MapEntry(k.toString(), v)));
            if (item != null) informacoesAdicionais.add(item);
          }
        }
      }

      Map<String, dynamic>? valorSugerido;
      if (valorSugeridoData != null && valorSugeridoData is Map) {
        valorSugerido = Map<String, dynamic>.from(valorSugeridoData);
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
        informacoesAdicionais: informacoesAdicionais,
        formaPagamento: formaPagamento.trim(),
        condicoesPagamento: condicoesPagamento.trim(),
        prazoEntrega: prazoEntrega.trim(),
        rascunho: rascunho == true,
        createdAt: createdAt != null ? DateTime.parse(createdAt.toString()) : DateTime.now(),
        updatedAt: updatedAt != null ? DateTime.parse(updatedAt.toString()) : DateTime.now(),
        valorSugerido: valorSugerido,
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