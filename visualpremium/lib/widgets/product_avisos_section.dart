import 'package:flutter/material.dart';
import 'package:visualpremium/models/product_item.dart';
import 'package:visualpremium/theme.dart';

class ProductAvisosSection extends StatelessWidget {
  final List<ProductAviso> avisos;
  final List<ProductMaterial> materiais;
  final List<ProductOpcaoExtra> opcoesExtras;  // ✅ NOVO
  final Function(List<ProductAviso>) onAvisosChanged;

  const ProductAvisosSection({
    super.key,
    required this.avisos,
    required this.materiais,
    required this.opcoesExtras,  // ✅ NOVO
    required this.onAvisosChanged,
  });

  void _showAvisoEditor(BuildContext context, [ProductAviso? initial]) async {
    final result = await showDialog<ProductAviso>(
      context: context,
      builder: (dialogContext) {
        return _AvisoEditorDialog(
          initial: initial,
          materiais: materiais,
          opcoesExtras: opcoesExtras,  // ✅ NOVO
        );
      },
    );

    if (result != null) {
      final novosAvisos = List<ProductAviso>.from(avisos);
      if (initial != null) {
        final index = novosAvisos.indexWhere((a) => a.id == initial.id);
        if (index != -1) {
          novosAvisos[index] = result;
        }
      } else {
        novosAvisos.add(result);
      }
      onAvisosChanged(novosAvisos);
    }
  }

  void _removeAviso(BuildContext context, ProductAviso aviso) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.delete_outline, color: theme.colorScheme.error),
              const SizedBox(width: 12),
              const Text('Excluir aviso'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tem certeza que deseja excluir este aviso?',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ Mostrar material OU opção extra
                    if (aviso.temMaterialAtribuido)
                      Row(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 16,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              aviso.materialNome ?? '',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      )
                    else if (aviso.temOpcaoExtraAtribuida)
                      Row(
                        children: [
                          Icon(
                            Icons.settings_outlined,
                            size: 16,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              aviso.opcaoExtraNome ?? '',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Text(
                      aviso.mensagem,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                final novosAvisos = avisos.where((a) => a.id != aviso.id).toList();
                onAvisosChanged(novosAvisos);
              },
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
              ),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );
  }

  // ✅ Agrupar avisos por tipo (sem atribuição, material, opção extra)
  Map<String, List<ProductAviso>> _groupAvisos() {
    final Map<String, List<ProductAviso>> groups = {};
    
    // Avisos sem atribuição
    final avisosSemAtribuicao = avisos.where((a) => a.aguardandoAtribuicao).toList();
    if (avisosSemAtribuicao.isNotEmpty) {
      groups['_sem_atribuicao'] = avisosSemAtribuicao;
    }
    
    // Avisos por material
    for (final material in materiais) {
      final avisosMaterial = avisos.where((a) => a.materialId == material.materialId).toList();
      if (avisosMaterial.isNotEmpty) {
        groups['material_${material.materialId}'] = avisosMaterial;
      }
    }
    
    // ✅ NOVO: Avisos por opção extra
    for (final opcao in opcoesExtras) {
      final avisosOpcao = avisos.where((a) => a.opcaoExtraId == opcao.id).toList();
      if (avisosOpcao.isNotEmpty) {
        groups['opcao_${opcao.id}'] = avisosOpcao;
      }
    }
    
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avisosAgrupados = _groupAvisos();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    'Avisos específicos por material ou opção extra',  // ✅ Texto atualizado
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: (materiais.isEmpty && opcoesExtras.isEmpty)  // ✅ Verificar ambos
                ? null 
                : () => _showAvisoEditor(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Adicionar'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (avisos.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
            ),
            child: Center(
              child: Text(
                'Nenhum aviso cadastrado',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          )
        else
          ...avisosAgrupados.entries.map((entry) {
            final key = entry.key;
            final avisosGrupo = entry.value;
            
            String grupoTitulo;
            IconData grupoIcon;
            Color grupoColor;
            Color grupoContainerColor;
            
            if (key == '_sem_atribuicao') {
              grupoTitulo = 'Aguardando atribuição';
              grupoIcon = Icons.pending_outlined;
              grupoColor = theme.colorScheme.primary;
              grupoContainerColor = theme.colorScheme.primaryContainer.withValues(alpha: 0.3);
            } else if (key.startsWith('material_')) {
              final materialId = int.parse(key.replaceFirst('material_', ''));
              final material = materiais.firstWhere((m) => m.materialId == materialId);
              grupoTitulo = material.materialNome;
              grupoIcon = Icons.inventory_2_outlined;
              grupoColor = theme.colorScheme.error;
              grupoContainerColor = theme.colorScheme.errorContainer.withValues(alpha: 0.3);
            } else {  // ✅ NOVO: opção extra
              final opcaoId = int.parse(key.replaceFirst('opcao_', ''));
              final opcao = opcoesExtras.firstWhere((o) => o.id == opcaoId);
              grupoTitulo = opcao.nome;
              grupoIcon = Icons.settings_outlined;
              grupoColor = theme.colorScheme.error;
              grupoContainerColor = theme.colorScheme.errorContainer.withValues(alpha: 0.3);
            }
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      grupoIcon,
                      size: 18,
                      color: grupoColor,  // ✅ Usa cor específica
                    ),
                    const SizedBox(width: 8),
                    Text(
                      grupoTitulo,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: grupoColor,  // ✅ Usa cor específica
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: grupoContainerColor,  // ✅ Usa cor específica
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${avisosGrupo.length}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: grupoColor,  // ✅ Usa cor específica
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...avisosGrupo.map((aviso) {
                  // ✅ Determinar cores baseado no status de atribuição
                  final isNaoAtribuido = aviso.aguardandoAtribuicao;
                  final backgroundColor = isNaoAtribuido
                      ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15)
                      : theme.colorScheme.errorContainer.withValues(alpha: 0.1);
                  final borderColor = isNaoAtribuido
                      ? theme.colorScheme.primary.withValues(alpha: 0.3)
                      : theme.colorScheme.error.withValues(alpha: 0.2);
                  final iconColor = isNaoAtribuido
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: borderColor,
                      ),
                    ),
                    child: InkWell(
                      onTap: () => _showAvisoEditor(context, aviso),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              isNaoAtribuido ? Icons.pending_outlined : Icons.warning_amber_rounded,
                              size: 20,
                              color: iconColor,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                aviso.mensagem,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              tooltip: 'Excluir',
                              onPressed: () => _removeAviso(context, aviso),
                              color: iconColor.withValues(alpha: 0.7),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
              ],
            );
          }),
      ],
    );
  }
}

// ✅ Dialog editor de avisos atualizado
class _AvisoEditorDialog extends StatefulWidget {
  final ProductAviso? initial;
  final List<ProductMaterial> materiais;
  final List<ProductOpcaoExtra> opcoesExtras;  // ✅ NOVO

  const _AvisoEditorDialog({
    this.initial,
    required this.materiais,
    required this.opcoesExtras,  // ✅ NOVO
  });

  @override
  State<_AvisoEditorDialog> createState() => _AvisoEditorDialogState();
}

class _AvisoEditorDialogState extends State<_AvisoEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _mensagemCtrl;
  late final FocusNode _mensagemFocusNode;
  
  // ✅ Tipo de atribuição: 'nenhum', 'material', ou 'opcaoExtra'
  late String _tipoAtribuicao;
  int? _selectedMaterialId;
  int? _selectedOpcaoExtraId;

  @override
  void initState() {
    super.initState();
    _mensagemCtrl = TextEditingController(text: widget.initial?.mensagem ?? '');
    _mensagemFocusNode = FocusNode();
    
    // ✅ Determinar tipo de atribuição inicial
    if (widget.initial?.materialId != null) {
      _tipoAtribuicao = 'material';
      _selectedMaterialId = widget.initial!.materialId;
    } else if (widget.initial?.opcaoExtraId != null) {
      _tipoAtribuicao = 'opcaoExtra';
      _selectedOpcaoExtraId = widget.initial!.opcaoExtraId;
    } else {
      _tipoAtribuicao = 'nenhum';
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mensagemFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _mensagemCtrl.dispose();
    _mensagemFocusNode.dispose();
    super.dispose();
  }

  String? _validateMensagem(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Digite a mensagem do aviso';
    }
    if (value.trim().length < 3) {
      return 'Mensagem muito curta';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // ✅ Obter material ou opção extra selecionada
    ProductMaterial? selectedMaterial;
    if (_tipoAtribuicao == 'material' && _selectedMaterialId != null) {
      try {
        selectedMaterial = widget.materiais.firstWhere(
          (m) => m.materialId == _selectedMaterialId
        );
      } catch (_) {}
    }
    
    ProductOpcaoExtra? selectedOpcaoExtra;
    if (_tipoAtribuicao == 'opcaoExtra' && _selectedOpcaoExtraId != null) {
      try {
        selectedOpcaoExtra = widget.opcoesExtras.firstWhere(
          (o) => o.id == _selectedOpcaoExtraId
        );
      } catch (_) {}
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Padding(
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
                      Icons.warning_amber_rounded,
                      color: theme.colorScheme.error,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.initial == null ? 'Novo aviso' : 'Editar aviso',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      tooltip: 'Fechar',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Este aviso será exibido quando o material ou opção extra for usado em orçamentos ou pedidos.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 20),
                
                // ✅ Tipo de atribuição
                Text(
                  'Atribuir a',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 8),
                
                // ✅ Radio buttons para escolher tipo
                Column(
                  children: [
                    RadioGroup<String>(
                      groupValue: _tipoAtribuicao,
                      onChanged: (value) {
                        setState(() {
                          _tipoAtribuicao = value!;

                          // efeitos colaterais ficam AQUI
                          if (value == 'material') {
                            _selectedMaterialId = widget.materiais.isNotEmpty
                                ? widget.materiais.first.materialId
                                : null;
                            _selectedOpcaoExtraId = null;
                          } else if (value == 'opcaoExtra') {
                            _selectedOpcaoExtraId = widget.opcoesExtras.isNotEmpty
                                ? widget.opcoesExtras.first.id
                                : null;
                            _selectedMaterialId = null;
                          } else {
                            _selectedMaterialId = null;
                            _selectedOpcaoExtraId = null;
                          }
                        });
                      },
                      child: Column(
                        children: [
                          const RadioListTile<String>(
                            title: Text('Nenhum'),
                            value: 'nenhum',
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          RadioListTile<String>(
                            title: const Text('Material'),
                            value: 'material',
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            enabled: widget.materiais.isNotEmpty,
                          ),
                          RadioListTile<String>(
                            title: const Text('Opção Extra'),
                            value: 'opcaoExtra',
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            enabled: widget.opcoesExtras.isNotEmpty,
                          ),
                        ],
                      ),
                    )

                  ],
                ),
                
                const SizedBox(height: 16),
                
                // ✅ Dropdown condicional baseado no tipo
                if (_tipoAtribuicao == 'material' && widget.materiais.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selecione o material',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedMaterialId,
                            isExpanded: true,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            borderRadius: BorderRadius.circular(8),
                            menuMaxHeight: 400,
                            items: widget.materiais.map((material) {
                              return DropdownMenuItem<int>(
                                value: material.materialId,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.inventory_2_outlined,
                                      size: 18,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        material.materialNome,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedMaterialId = value;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  )
                else if (_tipoAtribuicao == 'opcaoExtra' && widget.opcoesExtras.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selecione a opção extra',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedOpcaoExtraId,
                            isExpanded: true,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            borderRadius: BorderRadius.circular(8),
                            menuMaxHeight: 400,
                            items: widget.opcoesExtras.map((opcao) {
                              return DropdownMenuItem<int>(
                                value: opcao.id,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.settings_outlined,
                                      size: 18,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        opcao.nome,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedOpcaoExtraId = value;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                
                TextFormField(
                  controller: _mensagemCtrl,
                  focusNode: _mensagemFocusNode,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Mensagem do aviso *',
                    hintText: 'Ex: Este material requer prazo adicional de 48h para produção',
                    alignLabelWithHint: true,
                  ),
                  validator: _validateMensagem,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.18)),
                          foregroundColor: theme.colorScheme.onSurface,
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (!_formKey.currentState!.validate()) return;
                          
                          final now = DateTime.now();
                          final aviso = ProductAviso(
                            id: widget.initial?.id ?? now.microsecondsSinceEpoch,
                            mensagem: _mensagemCtrl.text.trim(),
                            materialId: _tipoAtribuicao == 'material' ? _selectedMaterialId : null,
                            materialNome: _tipoAtribuicao == 'material' ? selectedMaterial?.materialNome : null,
                            opcaoExtraId: _tipoAtribuicao == 'opcaoExtra' ? _selectedOpcaoExtraId : null,
                            opcaoExtraNome: _tipoAtribuicao == 'opcaoExtra' ? selectedOpcaoExtra?.nome : null,
                            createdAt: widget.initial?.createdAt ?? now,
                            updatedAt: now,
                          );
                          
                          Navigator.of(context).pop(aviso);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        ),
                        child: Text(widget.initial == null ? 'Adicionar' : 'Salvar'),
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