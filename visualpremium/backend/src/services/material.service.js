const prisma = require('../config/prisma');

class MaterialService {
  listar() {
    return prisma.material.findMany();
  }

  async criar(data) {
    // Valida campos obrigatórios
    const { nome, custo, unidade, quantidade } = data;
    
    if (!nome || !custo || !unidade || !quantidade) {
      throw new Error('Todos os campos são obrigatórios');
    }

    // Validar nome duplicado
    const nomeNormalizado = nome.trim().toLowerCase();
    const existente = await prisma.material.findFirst({
      where: {
        nome: {
          mode: 'insensitive',
          equals: nome.trim(),
        },
      },
    });

    if (existente) {
      throw new Error('Já existe um material com este nome');
    }

    // Valida e converte quantidade baseado na unidade
    let quantidadeNum;
    if (unidade === 'Kg') {
      // Permite decimal
      quantidadeNum = parseFloat(quantidade);
      if (isNaN(quantidadeNum) || quantidadeNum < 0) {
        throw new Error('Quantidade inválida para Kg');
      }
    } else {
      // Apenas inteiros
      const qty = parseInt(quantidade);
      if (isNaN(qty) || qty < 0) {
        throw new Error('Quantidade deve ser um número inteiro');
      }
      quantidadeNum = qty;
    }

    return prisma.material.create({
      data: {
        nome: nome.trim(),
        custo: parseFloat(custo),
        unidade,
        quantidade: quantidadeNum,
      },
    });
  }

  async atualizar(id, data) {
    const { nome, custo, unidade, quantidade } = data;

    // Validar nome duplicado (exceto o próprio material)
    if (nome) {
      const nomeNormalizado = nome.trim().toLowerCase();
      const existente = await prisma.material.findFirst({
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
        throw new Error('Já existe um material com este nome');
      }
    }

    // Valida e converte quantidade baseado na unidade se fornecida
    let quantidadeNum;
    if (quantidade !== undefined) {
      if (unidade === 'Kg') {
        quantidadeNum = parseFloat(quantidade);
        if (isNaN(quantidadeNum) || quantidadeNum < 0) {
          throw new Error('Quantidade inválida para Kg');
        }
      } else {
        const qty = parseInt(quantidade);
        if (isNaN(qty) || qty < 0) {
          throw new Error('Quantidade deve ser um número inteiro');
        }
        quantidadeNum = qty;
      }
    }

    return prisma.material.update({
      where: { id },
      data: {
        nome: nome ? nome.trim() : undefined,
        custo: custo ? parseFloat(custo) : undefined,
        unidade,
        quantidade: quantidadeNum,
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