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
        despesasAdicionais: true,
        orcamento: {  // ✅ NOVO - Incluir orçamento relacionado
          select: {
            id: true,
            numero: true
          }
        }
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
        despesasAdicionais: true,
        orcamento: {  // ✅ NOVO - Incluir orçamento relacionado
          select: {
            id: true,
            numero: true
          }
        }
      }
    });

    if (!pedido) {
      throw new Error('Pedido não encontrado');
    }

    return pedido;
  }

  _calculateTotal(materiais, despesasAdicionais, frete, freteValor, caminhaoMunck, caminhaoMunckHoras, caminhaoMunckValorHora) {
    let total = 0;

    // Somar materiais - suporta tanto materiais do banco quanto novos materiais
    for (const mat of materiais) {
      const quantidade = parseFloat(mat.quantidade);
      // Tentar pegar custo de diferentes estruturas
      const custo = mat.material?.custo ?? mat.custo ?? 0;
      total += custo * quantidade;
    }

    // Somar despesas adicionais
    for (const desp of despesasAdicionais) {
      total += desp.valor;
    }

    // Somar frete
    if (frete && freteValor) {
      total += freteValor;
    }

    // Somar caminhão munck
    if (caminhaoMunck && caminhaoMunckHoras && caminhaoMunckValorHora) {
      total += caminhaoMunckHoras * caminhaoMunckValorHora;
    }

    return total;
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
      where: { id },
      include: {
        materiais: {
          include: {
            material: true
          }
        },
        despesasAdicionais: true
      }
    });

    if (!pedidoExistente) {
      throw new Error('Pedido não encontrado');
    }

    // ✅ VALIDAÇÃO DO NÚMERO DO PEDIDO
    if (numero !== undefined && numero !== null) {
      if (typeof numero !== 'number' || numero <= 0) {
        throw new Error('Número do pedido inválido');
      }
      
      const pedidoDuplicado = await prisma.pedido.findFirst({
        where: {
          numero: numero,
          id: { not: id }
        }
      });
      
      if (pedidoDuplicado) {
        throw new Error('Já existe um pedido com este número');
      }
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

    // ✅ PREPARAR DADOS - APENAS CAMPOS QUE EXISTEM NO SCHEMA
    const updateData = {};
    
    // Adicionar apenas campos que foram enviados e são válidos
    if (cliente !== undefined) updateData.cliente = cliente.trim();
    if (status !== undefined) updateData.status = status;
    if (produtoId !== undefined) updateData.produtoId = produtoId;
    if (numero !== undefined) updateData.numero = numero;
    
    // Campos de frete
    if (frete !== undefined) {
      updateData.frete = freteBool;
      if (freteBool) {
        updateData.freteDesc = freteDesc?.trim() || null;
        updateData.freteValor = parseFloat(freteValor) || null;
      } else {
        updateData.freteDesc = null;
        updateData.freteValor = null;
      }
    }
    
    // Campos de caminhão munck
    if (caminhaoMunck !== undefined) {
      updateData.caminhaoMunck = caminhaoMunckBool;
      if (caminhaoMunckBool) {
        updateData.caminhaoMunckHoras = parseFloat(caminhaoMunckHoras) || null;
        updateData.caminhaoMunckValorHora = parseFloat(caminhaoMunckValorHora) || null;
      } else {
        updateData.caminhaoMunckHoras = null;
        updateData.caminhaoMunckValorHora = null;
      }
    }
    
    // Outros campos
    if (formaPagamento !== undefined) updateData.formaPagamento = formaPagamento.trim();
    if (condicoesPagamento !== undefined) updateData.condicoesPagamento = condicoesPagamento.trim();
    if (prazoEntrega !== undefined) updateData.prazoEntrega = prazoEntrega.trim();

    // ✅ ATUALIZAR PEDIDO (sem total, será calculado automaticamente pelo Prisma)
    await prisma.pedido.update({
      where: { id },
      data: updateData
    });

    // ✅ CRIAR MATERIAIS SE HOUVER
    if (materiaisValidados && materiaisValidados.length > 0) {
      await prisma.pedidoMaterial.createMany({
        data: materiaisValidados.map(m => ({
          materialId: m.materialId,
          quantidade: m.quantidade,
          pedidoId: id
        }))
      });
    }

    // ✅ CRIAR DESPESAS SE HOUVER
    if (despesasValidadas && despesasValidadas.length > 0) {
      await prisma.pedidoDespesaAdicional.createMany({
        data: despesasValidadas.map(d => ({
          descricao: d.descricao,
          valor: d.valor,
          pedidoId: id
        }))
      });
    }

    // ✅ BUSCAR E RETORNAR PEDIDO COMPLETO ATUALIZADO
    return await prisma.pedido.findUnique({
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
        despesasAdicionais: true,
        orcamento: {  // ✅ NOVO - Incluir orçamento relacionado
          select: {
            id: true,
            numero: true
          }
        }
      }
    });
  }


  async atualizarStatus(id, status) {
    const pedido = await prisma.pedido.findUnique({
      where: { id }
    });

    if (!pedido) {
      throw new Error('Pedido não encontrado');
    }

    if (!['Em Andamento', 'Concluído', 'Cancelado'].includes(status)) {
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
        despesasAdicionais: true,
        orcamento: {  // ✅ NOVO - Incluir orçamento relacionado
          select: {
            id: true,
            numero: true
          }
        }
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