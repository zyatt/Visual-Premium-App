import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:visualpremium/theme.dart';
import 'package:visualpremium/models/material_item.dart';
import 'package:visualpremium/data/imposto_sobra_repository.dart';

class SobraMaterialDialog extends StatefulWidget {
  final MaterialItem material;
  final double? alturaSobraInicial;
  final double? larguraSobraInicial;
  final double? quantidadeSobraInicial;
  
  const SobraMaterialDialog({
    super.key,
    required this.material,
    this.alturaSobraInicial,
    this.larguraSobraInicial,
    this.quantidadeSobraInicial,
  });

  @override
  State<SobraMaterialDialog> createState() => _SobraMaterialDialogState();
}

class _SobraMaterialDialogState extends State<SobraMaterialDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _alturaSobraCtrl;
  late final TextEditingController _larguraSobraCtrl;
  late final TextEditingController _quantidadeSobraCtrl;
  
  double? _valorSobraCalculado;
  double _percentualImposto = 18.0;
  
  // Determinar tipo de material baseado na unidade
  bool get _isM2 {
    final unit = widget.material.unit.toLowerCase();
    return unit == 'm²' || unit == 'm2';
  }
  
  bool get _isMetroLinear {
    final unit = widget.material.unit.toLowerCase();
    return unit == 'm/l' || unit == 'ml' || unit == 'metro linear';
  }
  
  @override
  void initState() {
    super.initState();
    
    _alturaSobraCtrl = TextEditingController(
      text: widget.alturaSobraInicial?.toString() ?? ''
    );
    _larguraSobraCtrl = TextEditingController(
      text: widget.larguraSobraInicial?.toString() ?? ''
    );
    _quantidadeSobraCtrl = TextEditingController(
      text: widget.quantidadeSobraInicial?.toString() ?? ''
    );
    
    _alturaSobraCtrl.addListener(_calcularSobra);
    _larguraSobraCtrl.addListener(_calcularSobra);
    _quantidadeSobraCtrl.addListener(_calcularSobra);
    
    _buscarPercentualImposto();
    
    // Calcular se já tem valores iniciais
    if (_isM2 && widget.alturaSobraInicial != null && widget.larguraSobraInicial != null) {
      _calcularSobra();
    } else if (!_isM2 && widget.quantidadeSobraInicial != null) {
      _calcularSobra();
    }
  }

  @override
  void dispose() {
    _alturaSobraCtrl.dispose();
    _larguraSobraCtrl.dispose();
    _quantidadeSobraCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscarPercentualImposto() async {
    try {
      final repository = ImpostoSobraRepository();
      final config = await repository.obter();
      if (mounted) {
        setState(() {
          final percentualRaw = config['percentualImposto'];
          if (percentualRaw is int) {
            _percentualImposto = percentualRaw.toDouble();
          } else if (percentualRaw is double) {
            _percentualImposto = percentualRaw;
          } else {
            _percentualImposto = 18.0;
          }
          
          if (_isM2 && widget.alturaSobraInicial != null && widget.larguraSobraInicial != null) {
            _calcularSobra();
          } else if (!_isM2 && widget.quantidadeSobraInicial != null) {
            _calcularSobra();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Erro ao buscar percentual de imposto: $e');
      }
    }
  }

  void _calcularSobra() {
    if (_isM2) {
      _calcularSobraM2();
    } else {
      _calcularSobraQuantidade();
    }
  }
  
  void _calcularSobraM2() {
    final alturaStr = _alturaSobraCtrl.text.trim().replaceAll(',', '.');
    final larguraStr = _larguraSobraCtrl.text.trim().replaceAll(',', '.');
    
    if (alturaStr.isEmpty || larguraStr.isEmpty) {
      setState(() => _valorSobraCalculado = null);
      return;
    }
    
    final alturaMm = double.tryParse(alturaStr);
    final larguraMm = double.tryParse(larguraStr);
    
    if (alturaMm == null || larguraMm == null || alturaMm <= 0 || larguraMm <= 0) {
      setState(() => _valorSobraCalculado = null);
      return;
    }
    
    // Calcular área da sobra em m²
    final areaM2 = (alturaMm * larguraMm) / 1000000.0;
    
    // Custo por m² do material
    final custoPorM2 = widget.material.costCents / 100.0;
    
    // Valor bruto da sobra
    final valorSobraBruto = areaM2 * custoPorM2;
    
    // Aplicar imposto
    final divisor = (100 - _percentualImposto) / 100;
    final valorSobraComImposto = divisor > 0 ? valorSobraBruto / divisor : valorSobraBruto;
    
    setState(() {
      _valorSobraCalculado = valorSobraComImposto;
    });
  }
  
  void _calcularSobraQuantidade() {
    final quantidadeStr = _quantidadeSobraCtrl.text.trim().replaceAll(',', '.');
    
    if (quantidadeStr.isEmpty) {
      setState(() => _valorSobraCalculado = null);
      return;
    }
    
    final quantidade = double.tryParse(quantidadeStr);
    
    if (quantidade == null || quantidade <= 0) {
      setState(() => _valorSobraCalculado = null);
      return;
    }
    
    // Custo por unidade do material
    final custoPorUnidade = widget.material.costCents / 100.0;
    
    // Para metro linear: entrada em mm, converter para metros para o cálculo de custo
    final quantidadeParaCalculo = _isMetroLinear ? quantidade / 1000.0 : quantidade;
    
    // Valor bruto da sobra
    final valorSobraBruto = quantidadeParaCalculo * custoPorUnidade;
    
    // Aplicar imposto
    final divisor = (100 - _percentualImposto) / 100;
    final valorSobraComImposto = divisor > 0 ? valorSobraBruto / divisor : valorSobraBruto;
    
    setState(() {
      _valorSobraCalculado = valorSobraComImposto;
    });
  }

  void _salvar() {
    if (!_formKey.currentState!.validate()) return;
    
    if (_isM2) {
      final alturaStr = _alturaSobraCtrl.text.trim().replaceAll(',', '.');
      final larguraStr = _larguraSobraCtrl.text.trim().replaceAll(',', '.');
      
      final alturaMm = double.tryParse(alturaStr);
      final larguraMm = double.tryParse(larguraStr);
      
      if (alturaMm == null || larguraMm == null) return;
      
      Navigator.of(context).pop({
        'alturaSobra': alturaMm,
        'larguraSobra': larguraMm,
        'quantidadeSobra': null,
        'valorSobra': _valorSobraCalculado ?? 0.0,
      });
    } else {
      final quantidadeStr = _quantidadeSobraCtrl.text.trim().replaceAll(',', '.');
      final quantidade = double.tryParse(quantidadeStr);
      
      if (quantidade == null) return;
      
      Navigator.of(context).pop({
        'alturaSobra': null,
        'larguraSobra': null,
        'quantidadeSobra': quantidade,
        'valorSobra': _valorSobraCalculado ?? 0.0,
      });
    }
  }

  void _removerSobra() {
    Navigator.of(context).pop({
      'alturaSobra': null,
      'larguraSobra': null,
      'quantidadeSobra': null,
      'valorSobra': null,
    });
  }
  
  String _getTituloSecao() {
    if (_isM2) {
      return 'Dimensões da Sobra (em milímetros)';
    } else if (_isMetroLinear) {
      return 'Comprimento da Sobra (em milímetros)';
    } else {
      return 'Quantidade da Sobra';
    }
  }
  
  String _getLabelQuantidade() {
    if (_isMetroLinear) {
      return 'Comprimento (mm)';
    }
    return 'Quantidade (${widget.material.unit})';
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValorInicial = (_isM2 && widget.alturaSobraInicial != null) || 
                            (!_isM2 && widget.quantidadeSobraInicial != null);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.content_cut,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Sobra de Material',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${widget.material.name} - ${widget.material.unit}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                Text(
                  _getTituloSecao(),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                
                // CAMPOS ADAPTATIVOS BASEADOS NA UNIDADE
                if (_isM2) ...[
                  // Para m²: Altura e Largura em MM
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _alturaSobraCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                          ],
                          decoration: InputDecoration(
                            labelText: 'Altura (mm)',
                            hintText: 'Ex: 500',
                            prefixIcon: Icon(
                              Icons.height,
                              color: theme.colorScheme.primary.withValues(alpha: 0.7),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Obrigatório';
                            }
                            final value = double.tryParse(v.replaceAll(',', '.'));
                            if (value == null || value <= 0) {
                              return 'Valor inválido';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _larguraSobraCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                          ],
                          decoration: InputDecoration(
                            labelText: 'Largura (mm)',
                            hintText: 'Ex: 300',
                            prefixIcon: Icon(
                              Icons.straighten,
                              color: theme.colorScheme.primary.withValues(alpha: 0.7),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Obrigatório';
                            }
                            final value = double.tryParse(v.replaceAll(',', '.'));
                            if (value == null || value <= 0) {
                              return 'Valor inválido';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Para outras unidades: Quantidade única
                  TextFormField(
                    controller: _quantidadeSobraCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                    ],
                    decoration: InputDecoration(
                      labelText: _getLabelQuantidade(),
                      prefixIcon: Icon(
                        _isMetroLinear ? Icons.straighten : Icons.inventory_2_outlined,
                        color: theme.colorScheme.primary.withValues(alpha: 0.7),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Obrigatório';
                      }
                      final value = double.tryParse(v.replaceAll(',', '.'));
                      if (value == null || value <= 0) {
                        return 'Valor inválido';
                      }
                      return null;
                    },
                  ),
                ],
                
                if (_valorSobraCalculado != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calculate, color: theme.colorScheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Cálculo da Sobra',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isM2
                              ? '• Área: ${((double.parse(_alturaSobraCtrl.text.replaceAll(',', '.')) * double.parse(_larguraSobraCtrl.text.replaceAll(',', '.'))) / 1000000).toStringAsFixed(4)} m²\n'
                                '• Custo do material: R\$ ${(widget.material.costCents / 100).toStringAsFixed(2)}/m²\n'
                                '• Imposto: $_percentualImposto%\n'
                                '• Valor da sobra: R\$ ${_valorSobraCalculado!.toStringAsFixed(2)}'
                              : '• Quantidade: ${_quantidadeSobraCtrl.text.replaceAll(',', '.')} ${_isMetroLinear ? 'mm' : widget.material.unit}\n'
                                '• Custo do material: R\$ ${(widget.material.costCents / 100).toStringAsFixed(2)}/${widget.material.unit}\n'
                                '• Valor bruto: R\$ ${(_isMetroLinear ? (double.parse(_quantidadeSobraCtrl.text.replaceAll(',', '.')) / 1000.0) : double.parse(_quantidadeSobraCtrl.text.replaceAll(',', '.'))) * (widget.material.costCents / 100) > 0 ? ((_isMetroLinear ? (double.parse(_quantidadeSobraCtrl.text.replaceAll(',', '.')) / 1000.0) : double.parse(_quantidadeSobraCtrl.text.replaceAll(',', '.'))) * (widget.material.costCents / 100)).toStringAsFixed(2) : "0.00"}\n'
                                '• Imposto: $_percentualImposto%\n'
                                '• Valor da sobra: R\$ ${_valorSobraCalculado!.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 24),
                
                Row(
                  children: [
                    if (hasValorInicial)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _removerSobra,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Remover Sobra'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    if (hasValorInicial) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                        ),
                        onPressed: _salvar,
                        child: const Text('Salvar Sobra'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}