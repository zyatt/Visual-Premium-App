const prisma = require('../config/prisma');

class ProdutoService {
  listar() {
    return prisma.produto.findMany({
      include: { materiais: { include: { material: true } } },
    });
  }

  async criar({ nome, materiais }) {
    // Validar nome duplicado
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

    return prisma.produto.create({
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
  }

  async atualizar(id, { nome, materiais }) {
    // Validar nome duplicado (exceto o próprio produto)
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

    await prisma.produtoMaterial.deleteMany({ where: { produtoId: id } });

    return prisma.produto.update({
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
  }

  async deletar(id) {
    await prisma.produtoMaterial.deleteMany({ where: { produtoId: id } });
    return prisma.produto.delete({ where: { id } });
  }
}

module.exports = new ProdutoService();