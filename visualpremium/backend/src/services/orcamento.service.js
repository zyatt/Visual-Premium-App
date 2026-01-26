const prisma = require('../config/prisma');

class OrcamentoService {
  async listar() {
    return prisma.orcamento.findMany({
      include: {
        produto: {
          include: {
            materiais: {
              include: {
                material: true
              }
            }
          }
        },
        materiais: {
          include: {
            material: true
          }
        }
      },
      orderBy: {
        createdAt: 'desc'
      }
    });
  }

  async buscarPorId(id) {
    const orcamento = await prisma.orcamento.findUnique({
      where: { id },
      include: {
        produto: {
          include: {
            materiais: {
              include: {
                material: true
              }
            }
          }
        },
        materiais: {
          include: {
            material: true
          }
        }
      }
    });

    if (!orcamento) {
      throw new Error('Orçamento não encontrado');
    }

    return orcamento;
  }

  async criar(data) {
    const { cliente, numero, produtoId, materiais } = data;

    if (!cliente || !numero || !produtoId) {
      throw new Error('Cliente, número e produto são obrigatórios');
    }

    // Verifica se o produto existe
    const produto = await prisma.produto.findUnique({
      where: { id: produtoId },
      include: {
        materiais: {
          include: {
            material: true
          }
        }
      }
    });

    if (!produto) {
      throw new Error('Produto não encontrado');
    }

    // Valida e converte quantidades dos materiais
    const materiaisValidados = [];
    if (materiais && materiais.length > 0) {
      for (const m of materiais) {
        const material = produto.materiais.find(pm => pm.materialId === m.materialId);
        if (!material) {
          throw new Error(`Material ${m.materialId} não pertence ao produto`);
        }

        const unidade = material.material.unidade;
        let quantidadeNum;

        // Converte quantidade para número (o Prisma espera Float)
        if (unidade === 'Kg') {
          quantidadeNum = parseFloat(m.quantidade);
          if (isNaN(quantidadeNum) || quantidadeNum < 0) {
            throw new Error(`Quantidade inválida para material ${material.material.nome}`);
          }
        } else {
          const qty = parseFloat(m.quantidade);
          if (isNaN(qty) || qty < 0) {
            throw new Error(`Quantidade inválida para material ${material.material.nome}`);
          }
          quantidadeNum = qty;
        }

        materiaisValidados.push({
          materialId: m.materialId,
          quantidade: quantidadeNum
        });
      }
    }

    // Cria o orçamento com status "Pendente"
    const orcamento = await prisma.orcamento.create({
      data: {
        cliente,
        numero,
        status: 'Pendente',
        produtoId,
        materiais: {
          create: materiaisValidados
        }
      },
      include: {
        produto: {
          include: {
            materiais: {
              include: {
                material: true
              }
            }
          }
        },
        materiais: {
          include: {
            material: true
          }
        }
      }
    });

    return orcamento;
  }

  async atualizar(id, data) {
    const { cliente, numero, produtoId, materiais, status } = data;

    // Verifica se o orçamento existe
    const orcamentoExistente = await prisma.orcamento.findUnique({
      where: { id }
    });

    if (!orcamentoExistente) {
      throw new Error('Orçamento não encontrado');
    }

    // Se mudou o produto, verifica se existe
    let produto;
    if (produtoId && produtoId !== orcamentoExistente.produtoId) {
      produto = await prisma.produto.findUnique({
        where: { id: produtoId },
        include: {
          materiais: {
            include: {
              material: true
            }
          }
        }
      });

      if (!produto) {
        throw new Error('Produto não encontrado');
      }
    } else {
      produto = await prisma.produto.findUnique({
        where: { id: orcamentoExistente.produtoId },
        include: {
          materiais: {
            include: {
              material: true
            }
          }
        }
      });
    }

    // Valida e converte quantidades dos materiais
    let materiaisValidados;
    if (materiais) {
      materiaisValidados = [];
      for (const m of materiais) {
        const material = produto.materiais.find(pm => pm.materialId === m.materialId);
        if (!material) {
          throw new Error(`Material ${m.materialId} não pertence ao produto`);
        }

        const unidade = material.material.unidade;
        let quantidadeNum;

        // Converte quantidade para número (o Prisma espera Float)
        if (unidade === 'Kg') {
          quantidadeNum = parseFloat(m.quantidade);
          if (isNaN(quantidadeNum) || quantidadeNum < 0) {
            throw new Error(`Quantidade inválida para material ${material.material.nome}`);
          }
        } else {
          const qty = parseFloat(m.quantidade);
          if (isNaN(qty) || qty < 0) {
            throw new Error(`Quantidade inválida para material ${material.material.nome}`);
          }
          quantidadeNum = qty;
        }

        materiaisValidados.push({
          materialId: m.materialId,
          quantidade: quantidadeNum
        });
      }
    }

    // Remove materiais antigos antes de atualizar
    if (materiaisValidados) {
      await prisma.orcamentoMaterial.deleteMany({
        where: { orcamentoId: id }
      });
    }

    // Atualiza o orçamento
    const orcamento = await prisma.orcamento.update({
      where: { id },
      data: {
        cliente: cliente || undefined,
        numero: numero || undefined,
        status: status || undefined,
        produtoId: produtoId || undefined,
        materiais: materiaisValidados ? {
          create: materiaisValidados
        } : undefined
      },
      include: {
        produto: {
          include: {
            materiais: {
              include: {
                material: true
              }
            }
          }
        },
        materiais: {
          include: {
            material: true
          }
        }
      }
    });

    return orcamento;
  }

  async atualizarStatus(id, status) {
    const orcamento = await prisma.orcamento.findUnique({
      where: { id }
    });

    if (!orcamento) {
      throw new Error('Orçamento não encontrado');
    }

    if (!['Pendente', 'Aprovado', 'Não Aprovado'].includes(status)) {
      throw new Error('Status inválido');
    }

    return prisma.orcamento.update({
      where: { id },
      data: { status },
      include: {
        produto: {
          include: {
            materiais: {
              include: {
                material: true
              }
            }
          }
        },
        materiais: {
          include: {
            material: true
          }
        }
      }
    });
  }

  async deletar(id) {
    const orcamento = await prisma.orcamento.findUnique({
      where: { id }
    });

    if (!orcamento) {
      throw new Error('Orçamento não encontrado');
    }

    await prisma.orcamentoMaterial.deleteMany({
      where: { orcamentoId: id }
    });

    return prisma.orcamento.delete({
      where: { id }
    });
  }

  async listarProdutos() {
    return prisma.produto.findMany({
      include: {
        materiais: {
          include: {
            material: true
          }
        }
      }
    });
  }
}

module.exports = new OrcamentoService();