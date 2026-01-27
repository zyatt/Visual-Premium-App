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
        },
        despesasAdicionais: true
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
        },
        despesasAdicionais: true
      }
    });

    if (!orcamento) {
      throw new Error('Orçamento não encontrado');
    }

    return orcamento;
  }

  async criar(data) {
    const { 
      cliente, 
      numero, 
      produtoId, 
      materiais,
      despesasAdicionais,
      frete,
      freteDesc,
      freteValor,
      caminhaoMunck,
      caminhaoMunckHoras,
      caminhaoMunckValorHora
    } = data;

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

    // Converte strings booleanas para boolean
    const freteBool = frete === true || frete === 'true';
    const caminhaoMunckBool = caminhaoMunck === true || caminhaoMunck === 'true';

    // Valida frete
    if (freteBool) {
      if (!freteDesc || freteDesc.trim() === '') {
        throw new Error('Descrição do frete é obrigatória');
      }
      if (!freteValor || freteValor <= 0) {
        throw new Error('Valor do frete deve ser maior que zero');
      }
    }

    // Valida caminhão munck
    if (caminhaoMunckBool) {
      if (!caminhaoMunckHoras || caminhaoMunckHoras <= 0) {
        throw new Error('Quantidade de horas do caminhão munck deve ser maior que zero');
      }
      if (!caminhaoMunckValorHora || caminhaoMunckValorHora <= 0) {
        throw new Error('Valor por hora do caminhão munck deve ser maior que zero');
      }
    }

    // Valida despesas adicionais
    const despesasValidadas = [];
    if (despesasAdicionais && Array.isArray(despesasAdicionais) && despesasAdicionais.length > 0) {
      for (const despesa of despesasAdicionais) {
        if (!despesa.descricao || despesa.descricao.trim() === '') {
          throw new Error('Descrição da despesa adicional é obrigatória');
        }
        if (!despesa.valor || despesa.valor <= 0) {
          throw new Error('Valor da despesa adicional deve ser maior que zero');
        }
        despesasValidadas.push({
          descricao: despesa.descricao.trim(),
          valor: parseFloat(despesa.valor)
        });
      }
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
        frete: freteBool,
        freteDesc: freteBool ? freteDesc : null,
        freteValor: freteBool ? parseFloat(freteValor) : null,
        caminhaoMunck: caminhaoMunckBool,
        caminhaoMunckHoras: caminhaoMunckBool ? parseFloat(caminhaoMunckHoras) : null,
        caminhaoMunckValorHora: caminhaoMunckBool ? parseFloat(caminhaoMunckValorHora) : null,
        materiais: {
          create: materiaisValidados
        },
        despesasAdicionais: {
          create: despesasValidadas
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
        },
        despesasAdicionais: true
      }
    });

    return orcamento;
  }

  async atualizar(id, data) {
    const { 
      cliente, 
      numero, 
      produtoId, 
      materiais, 
      status,
      despesasAdicionais,
      frete,
      freteDesc,
      freteValor,
      caminhaoMunck,
      caminhaoMunckHoras,
      caminhaoMunckValorHora
    } = data;

    // Verifica se o orçamento existe
    const orcamentoExistente = await prisma.orcamento.findUnique({
      where: { id }
    });

    if (!orcamentoExistente) {
      throw new Error('Orçamento não encontrado');
    }

    // Converte strings booleanas para boolean
    const freteBool = frete === true || frete === 'true';
    const caminhaoMunckBool = caminhaoMunck === true || caminhaoMunck === 'true';

    // Valida frete
    if (freteBool) {
      if (!freteDesc || freteDesc.trim() === '') {
        throw new Error('Descrição do frete é obrigatória');
      }
      if (!freteValor || freteValor <= 0) {
        throw new Error('Valor do frete deve ser maior que zero');
      }
    }

    // Valida caminhão munck
    if (caminhaoMunckBool) {
      if (!caminhaoMunckHoras || caminhaoMunckHoras <= 0) {
        throw new Error('Quantidade de horas do caminhão munck deve ser maior que zero');
      }
      if (!caminhaoMunckValorHora || caminhaoMunckValorHora <= 0) {
        throw new Error('Valor por hora do caminhão munck deve ser maior que zero');
      }
    }

    // Valida despesas adicionais
    let despesasValidadas;
    if (despesasAdicionais !== undefined) {
      despesasValidadas = [];
      if (Array.isArray(despesasAdicionais) && despesasAdicionais.length > 0) {
        for (const despesa of despesasAdicionais) {
          if (!despesa.descricao || despesa.descricao.trim() === '') {
            throw new Error('Descrição da despesa adicional é obrigatória');
          }
          if (!despesa.valor || despesa.valor <= 0) {
            throw new Error('Valor da despesa adicional deve ser maior que zero');
          }
          despesasValidadas.push({
            descricao: despesa.descricao.trim(),
            valor: parseFloat(despesa.valor)
          });
        }
      }
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

    // Remove despesas antigas antes de atualizar
    if (despesasValidadas !== undefined) {
      await prisma.despesaAdicional.deleteMany({
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
        frete: frete !== undefined ? freteBool : undefined,
        freteDesc: freteBool ? freteDesc : null,
        freteValor: freteBool ? parseFloat(freteValor) : null,
        caminhaoMunck: caminhaoMunck !== undefined ? caminhaoMunckBool : undefined,
        caminhaoMunckHoras: caminhaoMunckBool ? parseFloat(caminhaoMunckHoras) : null,
        caminhaoMunckValorHora: caminhaoMunckBool ? parseFloat(caminhaoMunckValorHora) : null,
        materiais: materiaisValidados ? {
          create: materiaisValidados
        } : undefined,
        despesasAdicionais: despesasValidadas !== undefined ? {
          create: despesasValidadas
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
        },
        despesasAdicionais: true
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
        },
        despesasAdicionais: true
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

    await prisma.despesaAdicional.deleteMany({
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