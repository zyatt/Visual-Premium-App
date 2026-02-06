const prisma = require('../config/prisma');
const logService = require('./log.service');

class ProdutoService {
  listar() {
    return prisma.produto.findMany({
      include: { 
        materiais: { include: { material: true } },
        opcoesExtras: true,
        avisos: {
          include: {
            material: true,      // ✅ Incluir material associado
            opcaoExtra: true     // ✅ NOVO: Incluir opção extra associada
          },
          orderBy: { createdAt: 'desc' }
        }
      },
    });
  }

  async criar({ nome, materiais, opcoesExtras, avisos }, user) {
    const nomeNormalizado = nome.trim().toLowerCase();
    const existente = await prisma.produto.findFirst({
      where: {
        nome: {
          mode: 'insensitive',
          equals: nome.trim(),
        },
      },
    });

    if (existente) {
      throw new Error('Já existe um produto com este nome');
    }

    // Validar materiais duplicados
    if (materiais && materiais.length > 0) {
      const materialIds = materiais.map(m => +m.materialId);
      const uniqueIds = new Set(materialIds);
      
      if (materialIds.length !== uniqueIds.size) {
        throw new Error('Não é permitido adicionar o mesmo material mais de uma vez');
      }
    }

    // Validar opções extras duplicadas
    if (opcoesExtras && opcoesExtras.length > 0) {
      const nomes = opcoesExtras.map(o => o.nome.trim().toLowerCase());
      const uniqueNomes = new Set(nomes);
      
      if (nomes.length !== uniqueNomes.size) {
        throw new Error('Não é permitido adicionar opções extras com o mesmo nome');
      }

      // Validar tipos válidos
      const tiposValidos = ['STRINGFLOAT', 'FLOATFLOAT', 'PERCENTFLOAT'];
      for (const opcao of opcoesExtras) {
        if (!tiposValidos.includes(opcao.tipo)) {
          throw new Error(`Tipo de opção extra inválido: ${opcao.tipo}`);
        }
      }
    }

    // ✅ Validar avisos
    if (avisos && avisos.length > 0) {
      const materiaisIds = (materiais || []).map(m => +m.materialId);
      const opcoesExtrasIds = (opcoesExtras || []).map((o, idx) => idx); // IDs temporários
      
      for (const aviso of avisos) {
        // Validar mensagem
        if (!aviso.mensagem || aviso.mensagem.trim() === '') {
          throw new Error('Avisos não podem ter mensagem vazia');
        }
        
        // ✅ NOVO: Validar que tem no máximo uma atribuição
        const temMaterial = aviso.materialId !== null && aviso.materialId !== undefined;
        const temOpcaoExtra = aviso.opcaoExtraId !== null && aviso.opcaoExtraId !== undefined;
        
        if (temMaterial && temOpcaoExtra) {
          throw new Error('Um aviso não pode estar associado simultaneamente a um material e a uma opção extra');
        }
        
        // ✅ Se materialId foi fornecido, validar se existe nos materiais do produto
        if (temMaterial) {
          const materialIdNum = +aviso.materialId;
          if (!materiaisIds.includes(materialIdNum)) {
            throw new Error('Não é possível associar um aviso a um material que não pertence ao produto');
          }
        }
        
        // ✅ NOVO: Se opcaoExtraId foi fornecido, validar se existe nas opções do produto
        // Nota: Na criação, opcaoExtraId será null pois as opções ainda não foram criadas
        // A atribuição será feita após a criação usando o nome da opção
      }
    }

    const produto = await prisma.produto.create({
      data: {
        nome: nome.trim(),
        materiais: {
          create: (materiais || []).map(m => ({
            material: { connect: { id: +m.materialId } },
          })),
        },
        opcoesExtras: {
          create: (opcoesExtras || []).map(o => ({
            nome: o.nome.trim(),
            tipo: o.tipo,
          })),
        },
        avisos: {
          create: (avisos || []).map(a => ({
            mensagem: a.mensagem.trim(),
            materialId: a.materialId ? +a.materialId : null,
            opcaoExtraId: a.opcaoExtraId ? +a.opcaoExtraId : null,  // ✅ NOVO
          })),
        },
      },
      include: { 
        materiais: { include: { material: true } },
        opcoesExtras: true,
        avisos: {
          include: {
            material: true,
            opcaoExtra: true  // ✅ NOVO
          },
          orderBy: { createdAt: 'desc' }
        }
      },
    });

    await logService.registrar({
      usuarioId: user?.id || 1,
      usuarioNome: user?.nome || 'Sistema',
      acao: 'CRIAR',
      entidade: 'PRODUTO',
      entidadeId: produto.id,
      descricao: `Criou o produto "${produto.nome}"`,
      detalhes: produto,
    });

    return produto;
  }

  async atualizar(id, { nome, materiais, opcoesExtras, avisos }, user) {
    const produtoAntigo = await prisma.produto.findUnique({
      where: { id },
      include: { 
        materiais: { include: { material: true } },
        opcoesExtras: true,
        avisos: {
          include: {
            material: true,
            opcaoExtra: true  // ✅ NOVO
          }
        },
      },
    });

    if (!produtoAntigo) {
      throw new Error('Produto não encontrado');
    }

    const nomeNormalizado = nome.trim().toLowerCase();
    const existente = await prisma.produto.findFirst({
      where: {
        nome: {
          mode: 'insensitive',
          equals: nome.trim(),
        },
        NOT: {
          id: id,
        },
      },
    });

    if (existente) {
      throw new Error('Já existe um produto com este nome');
    }

    // Validar materiais duplicados
    if (materiais && materiais.length > 0) {
      const materialIds = materiais.map(m => +m.materialId);
      const uniqueIds = new Set(materialIds);
      
      if (materialIds.length !== uniqueIds.size) {
        throw new Error('Não é permitido adicionar o mesmo material mais de uma vez');
      }
    }

    // Validar opções extras duplicadas
    if (opcoesExtras && opcoesExtras.length > 0) {
      const nomes = opcoesExtras.map(o => o.nome.trim().toLowerCase());
      const uniqueNomes = new Set(nomes);
      
      if (nomes.length !== uniqueNomes.size) {
        throw new Error('Não é permitido adicionar opções extras com o mesmo nome');
      }

      // Validar tipos válidos
      const tiposValidos = ['STRINGFLOAT', 'FLOATFLOAT', 'PERCENTFLOAT'];
      for (const opcao of opcoesExtras) {
        if (!tiposValidos.includes(opcao.tipo)) {
          throw new Error(`Tipo de opção extra inválido: ${opcao.tipo}`);
        }
      }
    }

    // ✅ Validar avisos
    if (avisos && avisos.length > 0) {
      const materiaisIds = (materiais || []).map(m => +m.materialId);
      const opcoesExtrasIds = (opcoesExtras || [])
        .filter(o => o.id && o.id > 0 && o.id < 1000000)
        .map(o => +o.id);
      
      for (const aviso of avisos) {
        // Validar mensagem
        if (!aviso.mensagem || aviso.mensagem.trim() === '') {
          throw new Error('Avisos não podem ter mensagem vazia');
        }
        
        // ✅ NOVO: Validar que tem no máximo uma atribuição
        const temMaterial = aviso.materialId !== null && aviso.materialId !== undefined;
        const temOpcaoExtra = aviso.opcaoExtraId !== null && aviso.opcaoExtraId !== undefined;
        
        if (temMaterial && temOpcaoExtra) {
          throw new Error('Um aviso não pode estar associado simultaneamente a um material e a uma opção extra');
        }
        
        // ✅ Se materialId foi fornecido, validar se existe nos materiais do produto
        if (temMaterial) {
          const materialIdNum = +aviso.materialId;
          if (!materiaisIds.includes(materialIdNum)) {
            throw new Error('Não é possível associar um aviso a um material que não pertence ao produto');
          }
        }
        
        // ✅ NOVO: Se opcaoExtraId foi fornecido, validar se existe nas opções do produto
        if (temOpcaoExtra) {
          const opcaoExtraIdNum = +aviso.opcaoExtraId;
          if (!opcoesExtrasIds.includes(opcaoExtraIdNum)) {
            throw new Error('Não é possível associar um aviso a uma opção extra que não pertence ao produto');
          }
        }
      }
    }

    // ✅ VALIDAÇÃO ADICIONAL: Se um material está sendo removido, verificar se ele tem avisos atribuídos
    const materiaisAntigos = produtoAntigo.materiais.map(m => m.materialId);
    const materiaisNovos = (materiais || []).map(m => +m.materialId);
    const materiaisRemovidos = materiaisAntigos.filter(id => !materiaisNovos.includes(id));
    
    if (materiaisRemovidos.length > 0) {
      const avisosAfetados = produtoAntigo.avisos.filter(a => 
        a.materialId && materiaisRemovidos.includes(a.materialId)
      );
      
      if (avisosAfetados.length > 0) {
        const materiaisComAvisos = avisosAfetados
          .map(a => a.material?.nome)
          .filter((nome, idx, arr) => arr.indexOf(nome) === idx);
        
        throw new Error(
          `Não é possível remover os seguintes materiais pois eles têm avisos associados: ${materiaisComAvisos.join(', ')}. ` +
          `Remova os avisos primeiro ou reatribua-os a outro material.`
        );
      }
    }

    // ✅ NOVO: Se uma opção extra está sendo removida, verificar se ela tem avisos atribuídos
    const opcoesAntigasIds = produtoAntigo.opcoesExtras.map(o => o.id);
    const opcoesNovasIds = (opcoesExtras || [])
      .filter(o => o.id && o.id > 0 && o.id < 1000000)
      .map(o => +o.id);
    const opcoesRemovidas = opcoesAntigasIds.filter(id => !opcoesNovasIds.includes(id));
    
    if (opcoesRemovidas.length > 0) {
      const avisosAfetados = produtoAntigo.avisos.filter(a => 
        a.opcaoExtraId && opcoesRemovidas.includes(a.opcaoExtraId)
      );
      
      if (avisosAfetados.length > 0) {
        const opcoesComAvisos = avisosAfetados
          .map(a => a.opcaoExtra?.nome)
          .filter((nome, idx, arr) => arr.indexOf(nome) === idx);
        
        throw new Error(
          `Não é possível remover as seguintes opções extras pois elas têm avisos associados: ${opcoesComAvisos.join(', ')}. ` +
          `Remova os avisos primeiro ou reatribua-os a outra opção.`
        );
      }
    }

    // ✅ Atualização inteligente de opções extras e avisos
    const produto = await prisma.$transaction(async (tx) => {
      // 1. Processar opções extras
      const opcoesRecebidas = (opcoesExtras || []).map(o => ({
        id: o.id,
        nome: o.nome.trim(),
        tipo: o.tipo
      }));

      const opcoesCriar = [];
      const opcoesAtualizar = [];
      const opcoesDeletar = [];

      // Verificar uso em orçamentos e pedidos
      const opcoesEmUsoEmOrcamentos = await tx.orcamentoOpcaoExtra.findMany({
        where: {
          produtoOpcaoId: { in: opcoesAntigasIds }
        },
        select: { produtoOpcaoId: true },
        distinct: ['produtoOpcaoId']
      });
      
      const idsEmUsoEmOrcamentos = new Set(opcoesEmUsoEmOrcamentos.map(o => o.produtoOpcaoId));
      
      const opcoesEmUsoEmPedidos = await tx.pedidoOpcaoExtra.findMany({
        where: {
          produtoOpcaoId: { in: opcoesAntigasIds }
        },
        select: { produtoOpcaoId: true },
        distinct: ['produtoOpcaoId']
      });
      
      const idsEmUsoEmPedidos = new Set(opcoesEmUsoEmPedidos.map(o => o.produtoOpcaoId));
      const idsEmUso = new Set([...idsEmUsoEmOrcamentos, ...idsEmUsoEmPedidos]);

      for (const opcaoAntiga of produtoAntigo.opcoesExtras) {
        const opcaoNova = opcoesRecebidas.find(o => o.id === opcaoAntiga.id);
        
        if (opcaoNova) {
          const nomeChanged = opcaoAntiga.nome !== opcaoNova.nome;
          const tipoChanged = opcaoAntiga.tipo !== opcaoNova.tipo;
          
          if (nomeChanged || tipoChanged) {
            opcoesAtualizar.push({
              id: opcaoAntiga.id,
              nome: opcaoNova.nome,
              tipo: opcaoNova.tipo,
              emUso: idsEmUso.has(opcaoAntiga.id)
            });
          }
        } else {
          if (idsEmUso.has(opcaoAntiga.id)) {
            throw new Error(
              `Não é possível remover a opção "${opcaoAntiga.nome}" pois ela está sendo usada em orçamentos ou pedidos. ` +
              `Você pode editar o nome ou tipo desta opção, mas não removê-la.`
            );
          } else {
            opcoesDeletar.push(opcaoAntiga.id);
          }
        }
      }

      for (const opcaoNova of opcoesRecebidas) {
        if (!opcaoNova.id || opcaoNova.id >= 1000000) {
          opcoesCriar.push({
            nome: opcaoNova.nome,
            tipo: opcaoNova.tipo
          });
        }
      }
      
      // 2. ✅ Processar avisos (materialId OU opcaoExtraId podem ser null)
      const avisosRecebidos = (avisos || []).map(a => ({
        id: a.id,
        mensagem: a.mensagem.trim(),
        materialId: a.materialId ? +a.materialId : null,
        opcaoExtraId: a.opcaoExtraId ? +a.opcaoExtraId : null  // ✅ NOVO
      }));

      const avisosCriar = [];
      const avisosAtualizar = [];
      const avisosDeletar = [];

      // Identificar avisos para deletar e atualizar
      for (const avisoAntigo of produtoAntigo.avisos) {
        const avisoNovo = avisosRecebidos.find(a => a.id === avisoAntigo.id);
        
        if (avisoNovo) {
          const mensagemChanged = avisoAntigo.mensagem !== avisoNovo.mensagem;
          const materialChanged = avisoAntigo.materialId !== avisoNovo.materialId;
          const opcaoExtraChanged = avisoAntigo.opcaoExtraId !== avisoNovo.opcaoExtraId;  // ✅ NOVO
          
          if (mensagemChanged || materialChanged || opcaoExtraChanged) {
            avisosAtualizar.push({
              id: avisoAntigo.id,
              mensagem: avisoNovo.mensagem,
              materialId: avisoNovo.materialId,
              opcaoExtraId: avisoNovo.opcaoExtraId  // ✅ NOVO
            });
          }
        } else {
          avisosDeletar.push(avisoAntigo.id);
        }
      }

      // Identificar avisos novos
      for (const avisoNovo of avisosRecebidos) {
        const isNovoAviso = !avisoNovo.id || avisoNovo.id >= 1000000;
        
        if (isNovoAviso) {
          avisosCriar.push({
            mensagem: avisoNovo.mensagem,
            materialId: avisoNovo.materialId,
            opcaoExtraId: avisoNovo.opcaoExtraId  // ✅ NOVO
          });
        }
      }
      
      // 3. Executar operações
      
      // Deletar opções antigas não usadas
      if (opcoesDeletar.length > 0) {
        await tx.produtoOpcaoExtra.deleteMany({
          where: {
            id: { in: opcoesDeletar }
          }
        });
      }
      
      // Atualizar opções existentes
      for (const opcao of opcoesAtualizar) {
        await tx.produtoOpcaoExtra.update({
          where: { id: opcao.id },
          data: { 
            nome: opcao.nome,
            tipo: opcao.tipo 
          }
        });
      }

      // Deletar avisos antigos
      if (avisosDeletar.length > 0) {
        await tx.produtoAviso.deleteMany({
          where: {
            id: { in: avisosDeletar }
          }
        });
      }

      // ✅ Atualizar avisos existentes
      for (const aviso of avisosAtualizar) {
        await tx.produtoAviso.update({
          where: { id: aviso.id },
          data: { 
            mensagem: aviso.mensagem,
            materialId: aviso.materialId,
            opcaoExtraId: aviso.opcaoExtraId  // ✅ NOVO
          }
        });
      }
      
      // Deletar materiais antigos
      await tx.produtoMaterial.deleteMany({ where: { produtoId: id } });

      // 4. Atualizar o produto
      return await tx.produto.update({
        where: { id },
        data: {
          nome: nome.trim(),
          materiais: {
            create: (materiais || []).map(m => ({
              material: { connect: { id: +m.materialId } },
            })),
          },
          opcoesExtras: {
            create: opcoesCriar.map(o => ({
              nome: o.nome,
              tipo: o.tipo,
            })),
          },
          avisos: {
            create: avisosCriar.map(a => ({
              mensagem: a.mensagem,
              materialId: a.materialId,
              opcaoExtraId: a.opcaoExtraId  // ✅ NOVO
            })),
          },
        },
        include: { 
          materiais: { include: { material: true } },
          opcoesExtras: true,
          avisos: {
            include: {
              material: true,
              opcaoExtra: true  // ✅ NOVO
            },
            orderBy: { createdAt: 'desc' }
          }
        },
      });
    });

    await logService.registrar({
      usuarioId: user?.id || 1,
      usuarioNome: user?.nome || 'Sistema',
      acao: 'EDITAR',
      entidade: 'PRODUTO',
      entidadeId: id,
      descricao: `Editou o produto "${produto.nome}"`,
      detalhes: {
        antes: produtoAntigo,
        depois: produto,
      },
    });

    return produto;
  }

  async deletar(id, user) {
    const produto = await prisma.produto.findUnique({
      where: { id },
      include: { 
        materiais: { include: { material: true } },
        opcoesExtras: true,
        avisos: {
          include: {
            material: true,
            opcaoExtra: true  // ✅ NOVO
          }
        },
      },
    });

    if (!produto) {
      throw new Error('Produto não encontrado');
    }

    try {
      const produtoComOrcamentos = await prisma.produto.findUnique({
        where: { id },
        include: {
          orcamentos: true
        }
      });

      if (produtoComOrcamentos && produtoComOrcamentos.orcamentos.length > 0) {
        throw new Error('Produto em uso: Este produto está sendo usado em um ou mais orçamentos e não pode ser excluído');
      }

      const produtoComPedidos = await prisma.produto.findUnique({
        where: { id },
        include: {
          pedidos: true
        }
      });

      if (produtoComPedidos && produtoComPedidos.pedidos.length > 0) {
        throw new Error('Produto em uso: Este produto está sendo usado em um ou mais pedidos e não pode ser excluído');
      }

      await prisma.produtoMaterial.deleteMany({ where: { produtoId: id } });
      await prisma.produto.delete({ where: { id } });

      await logService.registrar({
        usuarioId: user?.id || 1,
        usuarioNome: user?.nome || 'Sistema',
        acao: 'DELETAR',
        entidade: 'PRODUTO',
        entidadeId: id,
        descricao: `Excluiu o produto "${produto.nome}"`,
        detalhes: produto,
      });

      return produto;
    } catch (error) {
      if (error.code === 'P2003') {
        throw new Error('Produto em uso: Este produto está sendo usado em outros registros e não pode ser excluído');
      }
      throw error;
    }
  }
}

module.exports = new ProdutoService();