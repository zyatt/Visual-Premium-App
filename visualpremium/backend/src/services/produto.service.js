const prisma = require('../config/prisma');

class ProdutoService {
  listar() {
    return prisma.produto.findMany({
      include: { materiais: { include: { material: true } } },
    });
  }

  async criar({ nome, materiais }) {
    return prisma.produto.create({
      data: {
        nome,
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
    await prisma.produtoMaterial.deleteMany({ where: { produtoId: id } });

    return prisma.produto.update({
      where: { id },
      data: {
        nome,
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
