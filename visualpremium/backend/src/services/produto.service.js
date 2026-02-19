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
            material: true,
            opcaoExtra: true,
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

    if (materiais && materiais.length > 0) {
      const materialIds = materiais.map(m => +m.materialId);
      const uniqueIds = new Set(materialIds);
      
      if (materialIds.length !== uniqueIds.size) {
        throw new Error('Não é permitido adicionar o mesmo material mais de uma vez');
      }
    }

    if (opcoesExtras && opcoesExtras.length > 0) {
      const nomes = opcoesExtras.map(o => o.nome.trim().toLowerCase());
      const uniqueNomes = new Set(nomes);
      
      if (nomes.length !== uniqueNomes.size) {
        throw new Error('Não é permitido adicionar opções extras com o mesmo nome');
      }

      const tiposValidos = ['STRINGFLOAT', 'FLOATFLOAT', 'PERCENTFLOAT'];
      for (const opcao of opcoesExtras) {
        if (!tiposValidos.includes(opcao.tipo)) {
          throw new Error(`Tipo de opção extra inválido: ${opcao.tipo}`);
        }
      }
    }

    if (avisos && avisos.length > 0) {
      const materiaisIds = (materiais || []).map(m => +m.materialId);
      
      for (const aviso of avisos) {
        if (!aviso.mensagem || aviso.mensagem.trim() === '') {
          throw new Error('Avisos não podem ter mensagem vazia');
        }
        
        const temMaterial = aviso.materialId !== null && aviso.materialId !== undefined;
        const temOpcaoExtra = aviso.opcaoExtraId !== null && aviso.opcaoExtraId !== undefined;
        
        if (temMaterial && temOpcaoExtra) {
          throw new Error('Um aviso não pode estar associado simultaneamente a um material e a uma opção extra');
        }
        
        if (temMaterial) {
          const materialIdNum = +aviso.materialId;
          if (!materiaisIds.includes(materialIdNum)) {
            throw new Error('Não é possível associar um aviso a um material que não pertence ao produto');
          }
        }
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
            opcaoExtraId: a.opcaoExtraId ? +a.opcaoExtraId : null,
          })),
        },
      },
      include: { 
        materiais: { include: { material: true } },
        opcoesExtras: true,
        avisos: {
          include: {
            material: true,
            opcaoExtra: true
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
            opcaoExtra: true
          }
        },
      },
    });

    if (!produtoAntigo) {
      throw new Error('Produto não encontrado');
    }

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

    if (materiais && materiais.length > 0) {
      const materialIds = materiais.map(m => +m.materialId);
      const uniqueIds = new Set(materialIds);
      
      if (materialIds.length !== uniqueIds.size) {
        throw new Error('Não é permitido adicionar o mesmo material mais de uma vez');
      }
    }

    if (opcoesExtras && opcoesExtras.length > 0) {
      const nomes = opcoesExtras.map(o => o.nome.trim().toLowerCase());
      const uniqueNomes = new Set(nomes);
      
      if (nomes.length !== uniqueNomes.size) {
        throw new Error('Não é permitido adicionar opções extras com o mesmo nome');
      }

      const tiposValidos = ['STRINGFLOAT', 'FLOATFLOAT', 'PERCENTFLOAT'];
      for (const opcao of opcoesExtras) {
        if (!tiposValidos.includes(opcao.tipo)) {
          throw new Error(`Tipo de opção extra inválido: ${opcao.tipo}`);
        }
      }
    }

    if (avisos && avisos.length > 0) {
      const materiaisIds = (materiais || []).map(m => +m.materialId);
      const opcoesExtrasIds = (opcoesExtras || [])
        .filter(o => o.id && o.id > 0 && o.id < 1000000)
        .map(o => +o.id);
      
      for (const aviso of avisos) {
        if (!aviso.mensagem || aviso.mensagem.trim() === '') {
          throw new Error('Avisos não podem ter mensagem vazia');
        }
        
        const temMaterial = aviso.materialId !== null && aviso.materialId !== undefined;
        const temOpcaoExtra = aviso.opcaoExtraId !== null && aviso.opcaoExtraId !== undefined;
        
        if (temMaterial && temOpcaoExtra) {
          throw new Error('Um aviso não pode estar associado simultaneamente a um material e a uma opção extra');
        }
        
        if (temMaterial) {
          const materialIdNum = +aviso.materialId;
          if (!materiaisIds.includes(materialIdNum)) {
            throw new Error('Não é possível associar um aviso a um material que não pertence ao produto');
          }
        }
        
        if (temOpcaoExtra) {
          const opcaoExtraIdNum = +aviso.opcaoExtraId;
          if (!opcoesExtrasIds.includes(opcaoExtraIdNum)) {
            throw new Error('Não é possível associar um aviso a uma opção extra que não pertence ao produto');
          }
        }
      }
    }

    const materiaisAntigos = produtoAntigo.materiais.map(m => m.materialId);
    const materiaisNovos = (materiais || []).map(m => +m.materialId);
    const materiaisRemovidos = materiaisAntigos.filter(id => !materiaisNovos.includes(id));
    
    if (materiaisRemovidos.length > 0) {
      // CORREÇÃO: Verificar apenas os avisos que ainda estão vinculados ao material
      // nos dados recebidos do frontend. Se o aviso foi desvinculado/removido pelo
      // usuário no frontend, ele virá sem materialId ou não virá na lista.
      const avisosRecebidosIds = new Set(
        (avisos || [])
          .filter(a => a.id && a.id > 0 && a.id < 1000000)
          .map(a => a.id)
      );
      
      // Um aviso do banco ainda "bloqueia" a remoção somente se:
      // 1. Ainda está vinculado ao material removido no banco, E
      // 2. O frontend NÃO o removeu (ainda está na lista) E
      // 3. O frontend NÃO o desvinculou (ainda tem o mesmo materialId no request)
      const avisosAfetados = produtoAntigo.avisos.filter(avisoAntigo => {
        if (!avisoAntigo.materialId || !materiaisRemovidos.includes(avisoAntigo.materialId)) {
          return false;
        }
        
        // Verificar se o frontend já tratou este aviso
        const avisoNoRequest = (avisos || []).find(a => a.id === avisoAntigo.id);
        
        if (!avisoNoRequest) {
          // Aviso foi removido pelo frontend - OK
          return false;
        }
        
        // Aviso ainda existe no request - verificar se foi desvinculado
        const materialIdNoRequest = avisoNoRequest.materialId 
          ? +avisoNoRequest.materialId 
          : null;
          
        if (materialIdNoRequest !== avisoAntigo.materialId) {
          // materialId foi alterado (desvinculado ou reatribuído) - OK
          return false;
        }
        
        // Aviso ainda está vinculado ao mesmo material removido - BLOQUEAR
        return true;
      });
      
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

    const opcoesAntigasIds = produtoAntigo.opcoesExtras.map(o => o.id);
    const opcoesNovasIds = (opcoesExtras || [])
      .filter(o => o.id && o.id > 0 && o.id < 1000000)
      .map(o => +o.id);
    const opcoesRemovidas = opcoesAntigasIds.filter(id => !opcoesNovasIds.includes(id));
    
    if (opcoesRemovidas.length > 0) {
      // Mesma lógica: verificar se o frontend já tratou os avisos afetados
      const avisosAfetados = produtoAntigo.avisos.filter(avisoAntigo => {
        if (!avisoAntigo.opcaoExtraId || !opcoesRemovidas.includes(avisoAntigo.opcaoExtraId)) {
          return false;
        }
        
        const avisoNoRequest = (avisos || []).find(a => a.id === avisoAntigo.id);
        
        if (!avisoNoRequest) {
          // Aviso foi removido pelo frontend - OK
          return false;
        }
        
        const opcaoExtraIdNoRequest = avisoNoRequest.opcaoExtraId 
          ? +avisoNoRequest.opcaoExtraId 
          : null;
          
        if (opcaoExtraIdNoRequest !== avisoAntigo.opcaoExtraId) {
          // opcaoExtraId foi alterado (desvinculado ou reatribuído) - OK
          return false;
        }
        
        // Aviso ainda está vinculado à mesma opção removida - BLOQUEAR
        return true;
      });
      
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

    const produto = await prisma.$transaction(async (tx) => {
      const opcoesRecebidas = (opcoesExtras || []).map(o => ({
        id: o.id,
        nome: o.nome.trim(),
        tipo: o.tipo
      }));

      const opcoesCriar = [];
      const opcoesAtualizar = [];
      const opcoesDeletar = [];

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
      
      const avisosRecebidos = (avisos || []).map(a => ({
        id: a.id,
        mensagem: a.mensagem.trim(),
        materialId: a.materialId ? +a.materialId : null,
        opcaoExtraId: a.opcaoExtraId ? +a.opcaoExtraId : null
      }));

      const avisosCriar = [];
      const avisosAtualizar = [];
      const avisosDeletar = [];

      for (const avisoAntigo of produtoAntigo.avisos) {
        const avisoNovo = avisosRecebidos.find(a => a.id === avisoAntigo.id);
        
        if (avisoNovo) {
          const mensagemChanged = avisoAntigo.mensagem !== avisoNovo.mensagem;
          const materialChanged = avisoAntigo.materialId !== avisoNovo.materialId;
          const opcaoExtraChanged = avisoAntigo.opcaoExtraId !== avisoNovo.opcaoExtraId;
          
          if (mensagemChanged || materialChanged || opcaoExtraChanged) {
            avisosAtualizar.push({
              id: avisoAntigo.id,
              mensagem: avisoNovo.mensagem,
              materialId: avisoNovo.materialId,
              opcaoExtraId: avisoNovo.opcaoExtraId
            });
          }
        } else {
          avisosDeletar.push(avisoAntigo.id);
        }
      }

      for (const avisoNovo of avisosRecebidos) {
        const isNovoAviso = !avisoNovo.id || avisoNovo.id >= 1000000;
        
        if (isNovoAviso) {
          avisosCriar.push({
            mensagem: avisoNovo.mensagem,
            materialId: avisoNovo.materialId,
            opcaoExtraId: avisoNovo.opcaoExtraId
          });
        }
      }
      
      if (opcoesDeletar.length > 0) {
        await tx.produtoOpcaoExtra.deleteMany({
          where: {
            id: { in: opcoesDeletar }
          }
        });
      }
      
      for (const opcao of opcoesAtualizar) {
        await tx.produtoOpcaoExtra.update({
          where: { id: opcao.id },
          data: { 
            nome: opcao.nome,
            tipo: opcao.tipo 
          }
        });
      }

      if (avisosDeletar.length > 0) {
        await tx.produtoAviso.deleteMany({
          where: {
            id: { in: avisosDeletar }
          }
        });
      }

      for (const aviso of avisosAtualizar) {
        await tx.produtoAviso.update({
          where: { id: aviso.id },
          data: { 
            mensagem: aviso.mensagem,
            materialId: aviso.materialId,
            opcaoExtraId: aviso.opcaoExtraId
          }
        });
      }
      
      await tx.produtoMaterial.deleteMany({ where: { produtoId: id } });

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
              opcaoExtraId: a.opcaoExtraId
            })),
          },
        },
        include: { 
          materiais: { include: { material: true } },
          opcoesExtras: true,
          avisos: {
            include: {
              material: true,
              opcaoExtra: true
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
            opcaoExtra: true
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