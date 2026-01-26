const prisma = require('../config/prisma');

class MaterialService {
  listar() {
    return prisma.material.findMany();
  }

  criar(data) {
    // Valida e converte quantidade para string
    const { nome, custo, unidade, quantidade } = data;
    
    if (!nome || !custo || !unidade || !quantidade) {
      throw new Error('Todos os campos são obrigatórios');
    }

    // Valida quantidade baseado na unidade
    let quantidadeStr;
    if (unidade === 'Kg') {
      // Permite decimal
      const qty = parseFloat(quantidade);
      if (isNaN(qty) || qty < 0) {
        throw new Error('Quantidade inválida para Kg');
      }
      quantidadeStr = qty.toString();
    } else {
      // Apenas inteiros
      const qty = parseInt(quantidade);
      if (isNaN(qty) || qty < 0) {
        throw new Error('Quantidade deve ser um número inteiro');
      }
      quantidadeStr = qty.toString();
    }

    return prisma.material.create({
      data: {
        nome,
        custo: parseFloat(custo),
        unidade,
        quantidade: quantidadeStr,
      },
    });
  }

  atualizar(id, data) {
    const { nome, custo, unidade, quantidade } = data;

    // Valida quantidade baseado na unidade se fornecida
    let quantidadeStr;
    if (quantidade !== undefined) {
      if (unidade === 'Kg') {
        const qty = parseFloat(quantidade);
        if (isNaN(qty) || qty < 0) {
          throw new Error('Quantidade inválida para Kg');
        }
        quantidadeStr = qty.toString();
      } else {
        const qty = parseInt(quantidade);
        if (isNaN(qty) || qty < 0) {
          throw new Error('Quantidade deve ser um número inteiro');
        }
        quantidadeStr = qty.toString();
      }
    }

    return prisma.material.update({
      where: { id },
      data: {
        nome,
        custo: custo ? parseFloat(custo) : undefined,
        unidade,
        quantidade: quantidadeStr,
      },
    });
  }

  async deletar(id) {
    const usados = await prisma.produtoMaterial.findMany({
      where: { materialId: id },
      include: { produto: true },
    });

    if (usados.length) {
      return Promise.reject({
        message: 'Material em uso',
        error: 'Material em uso',
        produtos: usados.map(u => u.produto.nome),
      });
    }

    return prisma.material.delete({ where: { id } });
  }
}

module.exports = new MaterialService();