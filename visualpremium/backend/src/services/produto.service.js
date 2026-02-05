const prisma = require('../config/prisma');
const logService = require('./log.service');

class ProdutoService {
  listar() {
    return prisma.produto.findMany({
      include: { 
        materiais: { include: { material: true } },
        opcoesExtras: true,
      },
    });
  }

  async criar({ nome, materiais, opcoesExtras }, user) {
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
      },
      include: { 
        materiais: { include: { material: true } },
        opcoesExtras: true,
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

  async atualizar(id, { nome, materiais, opcoesExtras }, user) {
    const produtoAntigo = await prisma.produto.findUnique({
      where: { id },
      include: { 
        materiais: { include: { material: true } },
        opcoesExtras: true,
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

    // ✅ SOLUÇÃO COMPLETA: Atualização inteligente de opções extras
    const produto = await prisma.$transaction(async (tx) => {
      // 1. Identificar opções extras antigas
      const opcoesAntigasIds = produtoAntigo.opcoesExtras.map(o => o.id);
      
      // 2. Verificar quais opções antigas estão em uso em orçamentos
      const opcoesEmUsoEmOrcamentos = await tx.orcamentoOpcaoExtra.findMany({
        where: {
          produtoOpcaoId: { in: opcoesAntigasIds }
        },
        select: { produtoOpcaoId: true },
        distinct: ['produtoOpcaoId']
      });
      
      const idsEmUsoEmOrcamentos = new Set(opcoesEmUsoEmOrcamentos.map(o => o.produtoOpcaoId));
      
      // 3. Verificar quais opções antigas estão em uso em pedidos
      const opcoesEmUsoEmPedidos = await tx.pedidoOpcaoExtra.findMany({
        where: {
          produtoOpcaoId: { in: opcoesAntigasIds }
        },
        select: { produtoOpcaoId: true },
        distinct: ['produtoOpcaoId']
      });
      
      const idsEmUsoEmPedidos = new Set(opcoesEmUsoEmPedidos.map(o => o.produtoOpcaoId));
      
      // 4. Combinar IDs em uso
      const idsEmUso = new Set([...idsEmUsoEmOrcamentos, ...idsEmUsoEmPedidos]);
      
      // 5. Criar estrutura para mapeamento por ID
      // Precisamos trabalhar com IDs porque o nome pode mudar
      const opcoesRecebidas = (opcoesExtras || []).map(o => ({
        id: o.id, // ID da opção existente (se houver)
        nome: o.nome.trim(),
        tipo: o.tipo
      }));

      // 6. Identificar operações necessárias
      const opcoesCriar = [];
      const opcoesAtualizar = [];
      const opcoesDeletar = [];

      // Processar opções antigas
      for (const opcaoAntiga of produtoAntigo.opcoesExtras) {
        // Verificar se esta opção antiga ainda existe nas opções recebidas
        const opcaoNova = opcoesRecebidas.find(o => o.id === opcaoAntiga.id);
        
        if (opcaoNova) {
          // Opção existe tanto na versão antiga quanto na nova
          // Verificar se nome ou tipo mudaram
          const nomeChanged = opcaoAntiga.nome !== opcaoNova.nome;
          const tipoChanged = opcaoAntiga.tipo !== opcaoNova.tipo;
          
          if (nomeChanged || tipoChanged) {
            // ✅ PERMITE ATUALIZAR MESMO SE ESTIVER EM USO
            opcoesAtualizar.push({
              id: opcaoAntiga.id,
              nome: opcaoNova.nome,
              tipo: opcaoNova.tipo,
              emUso: idsEmUso.has(opcaoAntiga.id)
            });
          }
        } else {
          // Opção antiga não existe mais nas opções recebidas
          // Só pode deletar se NÃO estiver em uso
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

      // Processar opções novas (que não têm ID)
      for (const opcaoNova of opcoesRecebidas) {
        if (!opcaoNova.id) {
          // Opção completamente nova
          opcoesCriar.push({
            nome: opcaoNova.nome,
            tipo: opcaoNova.tipo
          });
        }
      }
      
      // 7. Executar operações

      // Deletar opções antigas não usadas
      if (opcoesDeletar.length > 0) {
        await tx.produtoOpcaoExtra.deleteMany({
          where: {
            id: { in: opcoesDeletar }
          }
        });
      }
      
      // Atualizar opções existentes (permite atualizar mesmo se estiver em uso)
      for (const opcao of opcoesAtualizar) {
        await tx.produtoOpcaoExtra.update({
          where: { id: opcao.id },
          data: { 
            nome: opcao.nome,
            tipo: opcao.tipo 
          }
        });
      }
      
      // Deletar materiais antigos (não têm FK em orçamentos/pedidos)
      await tx.produtoMaterial.deleteMany({ where: { produtoId: id } });

      // 8. Atualizar o produto
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
            // Criar apenas as opções REALMENTE NOVAS
            create: opcoesCriar.map(o => ({
              nome: o.nome,
              tipo: o.tipo,
            })),
          },
        },
        include: { 
          materiais: { include: { material: true } },
          opcoesExtras: true,
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
        throw new Error('Não é possível deletar este produto pois ele está sendo usado em orçamentos');
      }

      // Deletar relacionamentos (opcoesExtras será deletado automaticamente por cascade)
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
        throw new Error('Não é possível deletar este produto pois ele está sendo usado em outros registros');
      }
      throw error;
    }
  }
}

module.exports = new ProdutoService();