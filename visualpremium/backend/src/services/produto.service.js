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
      const tiposValidos = ['STRING_FLOAT', 'FLOAT_FLOAT'];
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
      const tiposValidos = ['STRING_FLOAT', 'FLOAT_FLOAT'];
      for (const opcao of opcoesExtras) {
        if (!tiposValidos.includes(opcao.tipo)) {
          throw new Error(`Tipo de opção extra inválido: ${opcao.tipo}`);
        }
      }
    }

    // Deletar materiais e opções extras antigas
    await prisma.produtoMaterial.deleteMany({ where: { produtoId: id } });
    await prisma.produtoOpcaoExtra.deleteMany({ where: { produtoId: id } });

    const produto = await prisma.produto.update({
      where: { id },
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