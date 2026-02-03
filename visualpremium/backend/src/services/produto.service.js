const prisma = require('../config/prisma');
const logService = require('./log.service');

class ProdutoService {
  listar() {
    return prisma.produto.findMany({
      include: { materiais: { include: { material: true } } },
    });
  }

  async criar({ nome, materiais }, user) { // ✅ ADICIONAR PARÂMETRO user
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

    const produto = await prisma.produto.create({
      data: {
        nome: nome.trim(),
        materiais: {
          create: (materiais || []).map(m => ({
            material: { connect: { id: +m.materialId } },
          })),
        },
      },
      include: { materiais: { include: { material: true } } },
    });

    // ✅ USAR DADOS DO USUÁRIO AUTENTICADO
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

  async atualizar(id, { nome, materiais }, user) { // ✅ ADICIONAR PARÂMETRO user
    const produtoAntigo = await prisma.produto.findUnique({
      where: { id },
      include: { materiais: { include: { material: true } } },
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

    if (materiais && materiais.length > 0) {
      const materialIds = materiais.map(m => +m.materialId);
      const uniqueIds = new Set(materialIds);
      
      if (materialIds.length !== uniqueIds.size) {
        throw new Error('Não é permitido adicionar o mesmo material mais de uma vez');
      }
    }

    await prisma.produtoMaterial.deleteMany({ where: { produtoId: id } });

    const produto = await prisma.produto.update({
      where: { id },
      data: {
        nome: nome.trim(),
        materiais: {
          create: (materiais || []).map(m => ({
            material: { connect: { id: +m.materialId } },
          })),
        },
      },
      include: { materiais: { include: { material: true } } },
    });

    // ✅ USAR DADOS DO USUÁRIO AUTENTICADO
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

  async deletar(id, user) { // ✅ ADICIONAR PARÂMETRO user
    const produto = await prisma.produto.findUnique({
      where: { id },
      include: { materiais: { include: { material: true } } },
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

      await prisma.produtoMaterial.deleteMany({ where: { produtoId: id } });
      await prisma.produto.delete({ where: { id } });

      // ✅ USAR DADOS DO USUÁRIO AUTENTICADO
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