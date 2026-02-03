import 'dart:convert';

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
  final String quantidade;

  const PedidoMaterialItem({
    required this.id,
    required this.materialId,
    required this.materialNome,
    required this.materialUnidade,
    required this.materialCusto,
    required this.quantidade,
  });

  double get total {
    final qty = double.tryParse(quantidade) ?? 0.0;
    return materialCusto * qty;
  }

  PedidoMaterialItem copyWith({
    int? id,
    int? materialId,
    String? materialNome,
    String? materialUnidade,
    double? materialCusto,
    String? quantidade,
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
      final quantidadeStr = quantidade.toString();

      return PedidoMaterialItem(
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

class PedidoItem {
  final int id;
  final String cliente;
  final int? numero;
  final String status;
  final int produtoId;
  final String produtoNome;
  final List<PedidoMaterialItem> materiais;
  final List<PedidoDespesaAdicionalItem> despesasAdicionais;
  final bool frete;
  final String? freteDesc;
  final double? freteValor;
  final bool caminhaoMunck;
  final double? caminhaoMunckHoras;
  final double? caminhaoMunckValorHora;
  final String formaPagamento;
  final String condicoesPagamento;
  final String prazoEntrega;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? orcamentoId;        // ✅ NOVO
  final int? orcamentoNumero;    // ✅ NOVO

  const PedidoItem({
    required this.id,
    required this.cliente,
    this.numero,
    required this.status,
    required this.produtoId,
    required this.produtoNome,
    required this.materiais,
    this.despesasAdicionais = const [],
    this.frete = false,
    this.freteDesc,
    this.freteValor,
    this.caminhaoMunck = false,
    this.caminhaoMunckHoras,
    this.caminhaoMunckValorHora,
    required this.formaPagamento,
    required this.condicoesPagamento,
    required this.prazoEntrega,
    required this.createdAt,
    required this.updatedAt,
    this.orcamentoId,        // ✅ NOVO
    this.orcamentoNumero,    // ✅ NOVO
  });

  double get totalMateriais {
    return materiais.fold(0.0, (sum, item) => sum + item.total);
  }

  double get totalDespesasAdicionais {
    return despesasAdicionais.fold(0.0, (sum, item) => sum + item.valor);
  }

  double get total {
    double t = totalMateriais;
    
    t += totalDespesasAdicionais;
    
    if (frete && freteValor != null) {
      t += freteValor!;
    }
    
    if (caminhaoMunck && caminhaoMunckHoras != null && caminhaoMunckValorHora != null) {
      t += caminhaoMunckHoras! * caminhaoMunckValorHora!;
    }
    
    return t;
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
    bool? frete,
    String? freteDesc,
    double? freteValor,
    bool? caminhaoMunck,
    double? caminhaoMunckHoras,
    double? caminhaoMunckValorHora,
    String? formaPagamento,
    String? condicoesPagamento,
    String? prazoEntrega,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? orcamentoId,        // ✅ NOVO
    int? orcamentoNumero,    // ✅ NOVO
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
        frete: frete ?? this.frete,
        freteDesc: freteDesc ?? this.freteDesc,
        freteValor: freteValor ?? this.freteValor,
        caminhaoMunck: caminhaoMunck ?? this.caminhaoMunck,
        caminhaoMunckHoras: caminhaoMunckHoras ?? this.caminhaoMunckHoras,
        caminhaoMunckValorHora: caminhaoMunckValorHora ?? this.caminhaoMunckValorHora,
        formaPagamento: formaPagamento ?? this.formaPagamento,
        condicoesPagamento: condicoesPagamento ?? this.condicoesPagamento,
        prazoEntrega: prazoEntrega ?? this.prazoEntrega,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        orcamentoId: orcamentoId ?? this.orcamentoId,              // ✅ NOVO
        orcamentoNumero: orcamentoNumero ?? this.orcamentoNumero,  // ✅ NOVO
      );

  Map<String, Object?> toMap() {
    final map = <String, Object?>{
      'cliente': cliente,
      'status': status,
      'produtoId': produtoId,
      'materiais': materiais.map((e) => e.toMap()).toList(),
      'despesasAdicionais': despesasAdicionais.map((e) => e.toMap()).toList(),
      'frete': frete,
      'freteDesc': frete ? freteDesc : null,
      'freteValor': frete ? freteValor : null,
      'caminhaoMunck': caminhaoMunck,
      'caminhaoMunckHoras': caminhaoMunck ? caminhaoMunckHoras : null,
      'caminhaoMunckValorHora': caminhaoMunck ? caminhaoMunckValorHora : null,
      'formaPagamento': formaPagamento,
      'condicoesPagamento': condicoesPagamento,
      'prazoEntrega': prazoEntrega,
    };
    
    // ✅ Só adiciona numero se não for null
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
      final createdAt = map['createdAt'];
      final updatedAt = map['updatedAt'];
      final formaPagamento = map['formaPagamento'];
      final condicoesPagamento = map['condicoesPagamento'];
      final prazoEntrega = map['prazoEntrega'];
      
      final frete = map['frete'] as bool? ?? false;
      final freteDesc = map['freteDesc'] as String?;
      final freteValor = map['freteValor'];
      final caminhaoMunck = map['caminhaoMunck'] as bool? ?? false;
      final caminhaoMunckHoras = map['caminhaoMunckHoras'];
      final caminhaoMunckValorHora = map['caminhaoMunckValorHora'];
      
      // ✅ NOVO - Extrair dados do orçamento
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

      return PedidoItem(
        id: int.parse(id.toString()),
        cliente: cliente.trim(),
        numero: numero != null ? int.parse(numero.toString()) : null,
        status: status.trim(),
        produtoId: int.parse(produtoId.toString()),
        produtoNome: produtoNome.trim(),
        materiais: materiais,
        despesasAdicionais: despesasAdicionais,
        frete: frete,
        freteDesc: freteDesc,
        freteValor: freteValor != null 
            ? (freteValor is int ? freteValor.toDouble() : freteValor as double)
            : null,
        caminhaoMunck: caminhaoMunck,
        caminhaoMunckHoras: caminhaoMunckHoras != null 
            ? (caminhaoMunckHoras is int ? caminhaoMunckHoras.toDouble() : caminhaoMunckHoras as double)
            : null,
        caminhaoMunckValorHora: caminhaoMunckValorHora != null 
            ? (caminhaoMunckValorHora is int ? caminhaoMunckValorHora.toDouble() : caminhaoMunckValorHora as double)
            : null,
        formaPagamento: formaPagamento.trim(),
        condicoesPagamento: condicoesPagamento.trim(),
        prazoEntrega: prazoEntrega.trim(),
        createdAt: createdAt != null ? DateTime.parse(createdAt.toString()) : DateTime.now(),
        updatedAt: updatedAt != null ? DateTime.parse(updatedAt.toString()) : DateTime.now(),
        orcamentoId: orcamentoId != null ? int.tryParse(orcamentoId.toString()) : null,  // ✅ NOVO
        orcamentoNumero: orcamentoNumero,  // ✅ NOVO
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