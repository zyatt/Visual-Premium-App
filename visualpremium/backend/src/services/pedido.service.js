const prisma = require('../config/prisma');

class PedidoService {
  async listar() {
    return prisma.pedido.findMany({
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
    const pedido = await prisma.pedido.findUnique({
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

    if (!pedido) {
      throw new Error('Pedido não encontrado');
    }

    return pedido;
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
      caminhaoMunckValorHora,
      formaPagamento,
      condicoesPagamento,
      prazoEntrega
    } = data;

    // Verificar se o pedido existe
    const pedidoExistente = await prisma.pedido.findUnique({
      where: { id }
    });

    if (!pedidoExistente) {
      throw new Error('Pedido não encontrado');
    }

    // Validações condicionais
    if (formaPagamento !== undefined && (!formaPagamento || formaPagamento.trim() === '')) {
      throw new Error('Forma de pagamento é obrigatória');
    }

    if (condicoesPagamento !== undefined && (!condicoesPagamento || condicoesPagamento.trim() === '')) {
      throw new Error('Condições de pagamento são obrigatórias');
    }

    if (prazoEntrega !== undefined && (!prazoEntrega || prazoEntrega.trim() === '')) {
      throw new Error('Prazo de entrega é obrigatório');
    }

    const freteBool = frete === true || frete === 'true';
    const caminhaoMunckBool = caminhaoMunck === true || caminhaoMunck === 'true';

    if (frete !== undefined && freteBool) {
      if (!freteDesc || freteDesc.trim() === '') {
        throw new Error('Descrição do frete é obrigatória');
      }
      if (!freteValor || freteValor <= 0) {
        throw new Error('Valor do frete deve ser maior que zero');
      }
    }

    if (caminhaoMunck !== undefined && caminhaoMunckBool) {
      if (!caminhaoMunckHoras || caminhaoMunckHoras <= 0) {
        throw new Error('Quantidade de horas do caminhão munck deve ser maior que zero');
      }
      if (!caminhaoMunckValorHora || caminhaoMunckValorHora <= 0) {
        throw new Error('Valor por hora do caminhão munck deve ser maior que zero');
      }
    }

    // Validar despesas adicionais
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

    // Buscar produto se necessário
    let produto;
    if (produtoId && produtoId !== pedidoExistente.produtoId) {
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
        where: { id: pedidoExistente.produtoId },
        include: {
          materiais: {
            include: {
              material: true
            }
          }
        }
      });
    }

    // Validar materiais
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

    // Deletar materiais antigos se houver novos
    if (materiaisValidados) {
      await prisma.pedidoMaterial.deleteMany({
        where: { pedidoId: id }
      });
    }

    // Deletar despesas antigas se houver novas
    if (despesasValidadas !== undefined) {
      await prisma.pedidoDespesaAdicional.deleteMany({
        where: { pedidoId: id }
      });
    }

    // Preparar dados para atualização
    const updateData = {
      cliente: cliente ? cliente.trim() : undefined,
      numero: numero !== undefined ? (numero === 0 ? null : numero) : undefined,
      status: status || undefined,
      produtoId: produtoId || undefined,
      frete: frete !== undefined ? freteBool : undefined,
      freteDesc: frete !== undefined ? (freteBool ? freteDesc?.trim() : null) : undefined,
      freteValor: frete !== undefined ? (freteBool ? parseFloat(freteValor) : null) : undefined,
      caminhaoMunck: caminhaoMunck !== undefined ? caminhaoMunckBool : undefined,
      caminhaoMunckHoras: caminhaoMunck !== undefined ? (caminhaoMunckBool ? parseFloat(caminhaoMunckHoras) : null) : undefined,
      caminhaoMunckValorHora: caminhaoMunck !== undefined ? (caminhaoMunckBool ? parseFloat(caminhaoMunckValorHora) : null) : undefined,
      formaPagamento: formaPagamento ? formaPagamento.trim() : undefined,
      condicoesPagamento: condicoesPagamento ? condicoesPagamento.trim() : undefined,
      prazoEntrega: prazoEntrega ? prazoEntrega.trim() : undefined
    };

    // Adicionar materiais apenas se houver
    if (materiaisValidados && materiaisValidados.length > 0) {
      updateData.materiais = {
        create: materiaisValidados
      };
    }

    // Adicionar despesas apenas se houver
    if (despesasValidadas !== undefined && despesasValidadas.length > 0) {
      updateData.despesasAdicionais = {
        create: despesasValidadas
      };
    }

    // Atualizar pedido
    const pedido = await prisma.pedido.update({
      where: { id },
      data: updateData,
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

    return pedido;
  }

  async atualizarStatus(id, status) {
    const pedido = await prisma.pedido.findUnique({
      where: { id }
    });

    if (!pedido) {
      throw new Error('Pedido não encontrado');
    }

    if (!['Em Andamento', 'Finalizado', 'Cancelado'].includes(status)) {
      throw new Error('Status inválido');
    }

    return prisma.pedido.update({
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
    const pedido = await prisma.pedido.findUnique({
      where: { id }
    });

    if (!pedido) {
      throw new Error('Pedido não encontrado');
    }

    await prisma.pedidoMaterial.deleteMany({
      where: { pedidoId: id }
    });

    await prisma.pedidoDespesaAdicional.deleteMany({
      where: { pedidoId: id }
    });

    return prisma.pedido.delete({
      where: { id }
    });
  }
}

module.exports = new PedidoService();