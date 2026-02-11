import 'dart:convert';

class AlmoxarifadoMaterialItem {
  final int id;
  final int materialId;
  final String materialNome;
  final String materialUnidade;
  final double quantidade;
  final double custoRealizado;

  const AlmoxarifadoMaterialItem({
    required this.id,
    required this.materialId,
    required this.materialNome,
    required this.materialUnidade,
    required this.quantidade,
    required this.custoRealizado,
  });

  Map<String, Object?> toMap() => {
    'materialId': materialId,
    'quantidade': quantidade,
    'custoRealizado': custoRealizado,
  };

  static AlmoxarifadoMaterialItem? tryFromMap(Map<String, Object?> map) {
    try {
      final id = map['id'];
      final materialId = map['materialId'];
      final quantidade = map['quantidade'];
      final custoRealizado = map['custoRealizado'];
      final material = map['material'];

      if (id == null || materialId == null || quantidade == null || custoRealizado == null) {
        return null;
      }

      String materialNome = '';
      String materialUnidade = '';

      if (material != null && material is Map) {
        final materialMap = material as Map<String, dynamic>;
        materialNome = materialMap['nome'] as String? ?? '';
        materialUnidade = materialMap['unidade'] as String? ?? '';
      }

      return AlmoxarifadoMaterialItem(
        id: int.parse(id.toString()),
        materialId: int.parse(materialId.toString()),
        materialNome: materialNome,
        materialUnidade: materialUnidade,
        quantidade: (quantidade is int) ? quantidade.toDouble() : (quantidade as double),
        custoRealizado: (custoRealizado is int) ? custoRealizado.toDouble() : (custoRealizado as double),
      );
    } catch (e) {
      return null;
    }
  }
}

class AlmoxarifadoDespesaItem {
  final int id;
  final String descricao;
  final double valorRealizado;

  const AlmoxarifadoDespesaItem({
    required this.id,
    required this.descricao,
    required this.valorRealizado,
  });

  Map<String, Object?> toMap() => {
    'descricao': descricao,
    'valorRealizado': valorRealizado,
  };

  static AlmoxarifadoDespesaItem? tryFromMap(Map<String, Object?> map) {
    try {
      final id = map['id'];
      final descricao = map['descricao'];
      final valorRealizado = map['valorRealizado'];

      if (id == null || descricao is! String || valorRealizado == null) {
        return null;
      }

      return AlmoxarifadoDespesaItem(
        id: int.parse(id.toString()),
        descricao: descricao,
        valorRealizado: (valorRealizado is int) ? valorRealizado.toDouble() : (valorRealizado as double),
      );
    } catch (e) {
      return null;
    }
  }
}

class AlmoxarifadoItem {
  final int id;
  final int orcamentoId;
  final String status;
  final String? observacoes;
  final DateTime? finalizadoEm;
  final String? finalizadoPor;
  final List<AlmoxarifadoMaterialItem> materiais;
  final List<AlmoxarifadoDespesaItem> despesas;

  const AlmoxarifadoItem({
    required this.id,
    required this.orcamentoId,
    required this.status,
    this.observacoes,
    this.finalizadoEm,
    this.finalizadoPor,
    this.materiais = const [],
    this.despesas = const [],
  });

  bool get isRealizado => status == 'Realizado';

  Map<String, Object?> toMap() => {
    'orcamentoId': orcamentoId,
    'materiais': materiais.map((m) => m.toMap()).toList(),
    'despesasAdicionais': despesas.map((d) => d.toMap()).toList(),
    'observacoes': observacoes,
  };

  static AlmoxarifadoItem? tryFromMap(Map<String, Object?> map) {
    try {
      final id = map['id'];
      final orcamentoId = map['orcamentoId'];
      final status = map['status'];
      final observacoes = map['observacoes'] as String?;
      final finalizadoEm = map['finalizadoEm'];
      final finalizadoPor = map['finalizadoPor'] as String?;
      final materiaisData = map['materiais'];
      final despesasData = map['despesasAdicionais'];

      if (id == null || orcamentoId == null || status is! String) {
        return null;
      }

      final materiais = <AlmoxarifadoMaterialItem>[];
      if (materiaisData is List) {
        for (final m in materiaisData) {
          if (m is Map) {
            final item = AlmoxarifadoMaterialItem.tryFromMap(
              m.map((k, v) => MapEntry(k.toString(), v))
            );
            if (item != null) materiais.add(item);
          }
        }
      }

      final despesas = <AlmoxarifadoDespesaItem>[];
      if (despesasData is List) {
        for (final d in despesasData) {
          if (d is Map) {
            final item = AlmoxarifadoDespesaItem.tryFromMap(
              d.map((k, v) => MapEntry(k.toString(), v))
            );
            if (item != null) despesas.add(item);
          }
        }
      }

      return AlmoxarifadoItem(
        id: int.parse(id.toString()),
        orcamentoId: int.parse(orcamentoId.toString()),
        status: status,
        observacoes: observacoes,
        finalizadoEm: finalizadoEm != null ? DateTime.parse(finalizadoEm.toString()) : null,
        finalizadoPor: finalizadoPor,
        materiais: materiais,
        despesas: despesas,
      );
    } catch (e) {
      return null;
    }
  }

  static List<AlmoxarifadoItem> decodeList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final out = <AlmoxarifadoItem>[];
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

class RelatorioComparativoItem {
  final int id;
  final int almoxarifadoId;
  
  // Valores orçados
  final double totalOrcadoMateriais;
  final double totalOrcadoDespesas;
  final double totalOrcadoOpcoesExtras;
  final double totalOrcado;
  
  // Valores realizados
  final double totalRealizadoMateriais;
  final double totalRealizadoDespesas;
  final double totalRealizadoOpcoesExtras;
  final double totalRealizado;
  
  // Diferenças
  final double diferencaMateriais;
  final double diferencaDespesas;
  final double diferencaOpcoesExtras;
  final double diferencaTotal;
  
  // Percentuais
  final double percentualMateriais;
  final double percentualDespesas;
  final double percentualOpcoesExtras;
  final double percentualTotal;
  
  // Análise detalhada
  final Map<String, dynamic> analiseDetalhada;
  
  // Informações do orçamento (via join)
  final String? clienteNome;
  final int? numeroOrcamento;
  final String? produtoNome;
  final DateTime? finalizadoEm;

  const RelatorioComparativoItem({
    required this.id,
    required this.almoxarifadoId,
    required this.totalOrcadoMateriais,
    required this.totalOrcadoDespesas,
    required this.totalOrcadoOpcoesExtras,
    required this.totalOrcado,
    required this.totalRealizadoMateriais,
    required this.totalRealizadoDespesas,
    required this.totalRealizadoOpcoesExtras,
    required this.totalRealizado,
    required this.diferencaMateriais,
    required this.diferencaDespesas,
    required this.diferencaOpcoesExtras,
    required this.diferencaTotal,
    required this.percentualMateriais,
    required this.percentualDespesas,
    required this.percentualOpcoesExtras,
    required this.percentualTotal,
    required this.analiseDetalhada,
    this.clienteNome,
    this.numeroOrcamento,
    this.produtoNome,
    this.finalizadoEm,
  });

  bool get isPositivo => diferencaTotal < 0;
  bool get isNegativo => diferencaTotal > 0;
  
  String get statusTexto {
    if (isPositivo) return 'Economia';
    if (isNegativo) return 'Excedeu';
    return 'Conforme';
  }

  static RelatorioComparativoItem? tryFromMap(Map<String, Object?> map) {
    try {
      final id = map['id'];
      final almoxarifadoId = map['almoxarifadoId'];
      final almoxarifado = map['almoxarifado'];
      
      if (id == null || almoxarifadoId == null) {
        return null;
      }

      // Extrair informações do orçamento
      String? clienteNome;
      int? numeroOrcamento;
      String? produtoNome;
      DateTime? finalizadoEm;

      if (almoxarifado is Map) {
        final almoxMap = almoxarifado as Map<String, dynamic>;
        finalizadoEm = almoxMap['finalizadoEm'] != null 
          ? DateTime.parse(almoxMap['finalizadoEm'].toString())
          : null;
        
        final orcamento = almoxMap['orcamento'];
        if (orcamento is Map) {
          final orcMap = orcamento as Map<String, dynamic>;
          clienteNome = orcMap['cliente'] as String?;
          numeroOrcamento = orcMap['numero'] as int?;
          
          final produto = orcMap['produto'];
          if (produto is Map) {
            final prodMap = produto as Map<String, dynamic>;
            produtoNome = prodMap['nome'] as String?;
          }
        }
      }

      return RelatorioComparativoItem(
        id: int.parse(id.toString()),
        almoxarifadoId: int.parse(almoxarifadoId.toString()),
        totalOrcadoMateriais: _parseDouble(map['totalOrcadoMateriais']),
        totalOrcadoDespesas: _parseDouble(map['totalOrcadoDespesas']),
        totalOrcadoOpcoesExtras: _parseDouble(map['totalOrcadoOpcoesExtras']),
        totalOrcado: _parseDouble(map['totalOrcado']),
        totalRealizadoMateriais: _parseDouble(map['totalRealizadoMateriais']),
        totalRealizadoDespesas: _parseDouble(map['totalRealizadoDespesas']),
        totalRealizadoOpcoesExtras: _parseDouble(map['totalRealizadoOpcoesExtras']),
        totalRealizado: _parseDouble(map['totalRealizado']),
        diferencaMateriais: _parseDouble(map['diferencaMateriais']),
        diferencaDespesas: _parseDouble(map['diferencaDespesas']),
        diferencaOpcoesExtras: _parseDouble(map['diferencaOpcoesExtras']),
        diferencaTotal: _parseDouble(map['diferencaTotal']),
        percentualMateriais: _parseDouble(map['percentualMateriais']),
        percentualDespesas: _parseDouble(map['percentualDespesas']),
        percentualOpcoesExtras: _parseDouble(map['percentualOpcoesExtras']),
        percentualTotal: _parseDouble(map['percentualTotal']),
        analiseDetalhada: map['analiseDetalhada'] as Map<String, dynamic>? ?? {},
        clienteNome: clienteNome,
        numeroOrcamento: numeroOrcamento,
        produtoNome: produtoNome,
        finalizadoEm: finalizadoEm,
      );
    } catch (e) {
      return null;
    }
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return 0.0;
  }

  static List<RelatorioComparativoItem> decodeList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final out = <RelatorioComparativoItem>[];
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