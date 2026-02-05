const prisma = require('../config/prisma');
const logService = require('./log.service');

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
            },
            opcoesExtras: true
          }
        },
        materiais: {
          include: {
            material: true
          }
        },
        despesasAdicionais: true,
        opcoesExtras: {
          include: {
            produtoOpcao: true
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
            },
            opcoesExtras: true
          }
        },
        materiais: {
          include: {
            material: true
          }
        },
        despesasAdicionais: true,
        opcoesExtras: {
          include: {
            produtoOpcao: true
          }
        }
      }
    });

    if (!orcamento) {
      throw new Error('Orçamento não encontrado');
    }

    return orcamento;
  }

  async criar(data, user) {
    const { 
      cliente, 
      numero, 
      produtoId, 
      materiais,
      despesasAdicionais,
      opcoesExtras,
      formaPagamento,
      condicoesPagamento,
      prazoEntrega
    } = data;

    // Validações básicas
    if (!cliente || !numero || !produtoId) {
      throw new Error('Cliente, número e produto são obrigatórios');
    }

    if (!formaPagamento || formaPagamento.trim() === '') {
      throw new Error('Forma de pagamento é obrigatória');
    }

    if (!condicoesPagamento || condicoesPagamento.trim() === '') {
      throw new Error('Condições de pagamento são obrigatórias');
    }

    if (!prazoEntrega || prazoEntrega.trim() === '') {
      throw new Error('Prazo de entrega é obrigatório');
    }

    // Verificar se o produto existe
    const produto = await prisma.produto.findUnique({
      where: { id: produtoId },
      include: {
        materiais: {
          include: {
            material: true
          }
        },
        opcoesExtras: true
      }
    });

    if (!produto) {
      throw new Error('Produto não encontrado');
    }

    // Validar despesas adicionais
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

    // Validar materiais
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

    // Validar opções extras
    const opcoesExtrasValidadas = [];
    if (opcoesExtras && Array.isArray(opcoesExtras) && opcoesExtras.length > 0) {
      for (const opcaoValor of opcoesExtras) {
        const opcaoExtra = produto.opcoesExtras.find(o => o.id === opcaoValor.produtoOpcaoId);
        
        if (!opcaoExtra) {
          throw new Error(`Opção extra ${opcaoValor.produtoOpcaoId} não pertence ao produto`);
        }

        // Validar valores baseado no tipo
        if (opcaoExtra.tipo === 'STRING_FLOAT') {
          if (!opcaoValor.valorString || opcaoValor.valorString.trim() === '') {
            throw new Error(`Valor texto é obrigatório para a opção "${opcaoExtra.nome}"`);
          }
          const valorFloat1 = parseFloat(opcaoValor.valorFloat1);
          if (isNaN(valorFloat1) || valorFloat1 < 0) {
            throw new Error(`Valor numérico inválido para a opção "${opcaoExtra.nome}"`);
          }
          opcoesExtrasValidadas.push({
            produtoOpcaoId: opcaoValor.produtoOpcaoId,
            valorString: opcaoValor.valorString.trim(),
            valorFloat1: valorFloat1,
            valorFloat2: null
          });
        } else if (opcaoExtra.tipo === 'FLOAT_FLOAT') {
          const valorFloat1 = parseFloat(opcaoValor.valorFloat1);
          const valorFloat2 = parseFloat(opcaoValor.valorFloat2);
          
          if (isNaN(valorFloat1) || valorFloat1 < 0) {
            throw new Error(`Primeiro valor numérico inválido para a opção "${opcaoExtra.nome}"`);
          }
          if (isNaN(valorFloat2) || valorFloat2 < 0) {
            throw new Error(`Segundo valor numérico inválido para a opção "${opcaoExtra.nome}"`);
          }
          
          opcoesExtrasValidadas.push({
            produtoOpcaoId: opcaoValor.produtoOpcaoId,
            valorString: null,
            valorFloat1: valorFloat1,
            valorFloat2: valorFloat2
          });
        }
      }
    }

    // Preparar dados para criação
    const createData = {
      cliente: cliente.trim(),
      numero,
      status: 'Pendente',
      produtoId,
      formaPagamento: formaPagamento.trim(),
      condicoesPagamento: condicoesPagamento.trim(),
      prazoEntrega: prazoEntrega.trim(),
    };

    // Adicionar materiais apenas se houver
    if (materiaisValidados.length > 0) {
      createData.materiais = {
        create: materiaisValidados
      };
    }

    // Adicionar despesas apenas se houver
    if (despesasValidadas.length > 0) {
      createData.despesasAdicionais = {
        create: despesasValidadas
      };
    }

    // Adicionar opções extras apenas se houver
    if (opcoesExtrasValidadas.length > 0) {
      createData.opcoesExtras = {
        create: opcoesExtrasValidadas
      };
    }

    // Criar orçamento
    const orcamento = await prisma.orcamento.create({
      data: createData,
      include: {
        produto: {
          include: {
            materiais: {
              include: {
                material: true
              }
            },
            opcoesExtras: true
          }
        },
        materiais: {
          include: {
            material: true
          }
        },
        despesasAdicionais: true,
        opcoesExtras: {
          include: {
            produtoOpcao: true
          }
        }
      }
    });

    // Registrar log de criação
    await logService.registrar({
      usuarioId: user?.id || 1,
      usuarioNome: user?.nome || 'Sistema',
      acao: 'CRIAR',
      entidade: 'ORCAMENTO',
      entidadeId: orcamento.id,
      descricao: `Criou o orçamento #${orcamento.numero}`,
      detalhes: orcamento,
    });

    return orcamento;
  }

  async atualizar(id, data, user) {
    const { 
      cliente, 
      numero, 
      produtoId, 
      materiais, 
      status,
      despesasAdicionais,
      opcoesExtras,
      formaPagamento,
      condicoesPagamento,
      prazoEntrega
    } = data;

    // Verificar se o orçamento existe e buscar dados antigos
    const orcamentoAntigo = await prisma.orcamento.findUnique({
      where: { id },
      include: {
        produto: {
          include: {opcoesExtras: true
          }
        },
        materiais: { include: { material: true } },
        despesasAdicionais: true,
        opcoesExtras: { include: { produtoOpcao: true } }
      }
    });

    if (!orcamentoAntigo) {
      throw new Error('Orçamento não encontrado');
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

    // Buscar produto se necessário
    let produto;
    if (produtoId && produtoId !== orcamentoAntigo.produtoId) {
      produto = await prisma.produto.findUnique({
        where: { id: produtoId },
        include: {
          materiais: {
            include: {
              material: true
            }
          },
          opcoesExtras: true
        }
      });

      if (!produto) {
        throw new Error('Produto não encontrado');
      }
    } else {
      produto = await prisma.produto.findUnique({
        where: { id: orcamentoAntigo.produtoId },
        include: {
          materiais: {
            include: {
              material: true
            }
          },
          opcoesExtras: true
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

    // Validar opções extras
    let opcoesExtrasValidadas;
    if (opcoesExtras !== undefined) {
      opcoesExtrasValidadas = [];
      if (Array.isArray(opcoesExtras) && opcoesExtras.length > 0) {
        for (const opcaoValor of opcoesExtras) {
          const opcaoExtra = produto.opcoesExtras.find(o => o.id === opcaoValor.produtoOpcaoId);
          
          if (!opcaoExtra) {
            throw new Error(`Opção extra ${opcaoValor.produtoOpcaoId} não pertence ao produto`);
          }

          // Validar valores baseado no tipo
          if (opcaoExtra.tipo === 'STRING_FLOAT') {
            if (!opcaoValor.valorString || opcaoValor.valorString.trim() === '') {
              throw new Error(`Valor texto é obrigatório para a opção "${opcaoExtra.nome}"`);
            }
            const valorFloat1 = parseFloat(opcaoValor.valorFloat1);
            if (isNaN(valorFloat1) || valorFloat1 < 0) {
              throw new Error(`Valor numérico inválido para a opção "${opcaoExtra.nome}"`);
            }
            opcoesExtrasValidadas.push({
              produtoOpcaoId: opcaoValor.produtoOpcaoId,
              valorString: opcaoValor.valorString.trim(),
              valorFloat1: valorFloat1,
              valorFloat2: null
            });
          } else if (opcaoExtra.tipo === 'FLOAT_FLOAT') {
            const valorFloat1 = parseFloat(opcaoValor.valorFloat1);
            const valorFloat2 = parseFloat(opcaoValor.valorFloat2);
            
            if (isNaN(valorFloat1) || valorFloat1 < 0) {
              throw new Error(`Primeiro valor numérico inválido para a opção "${opcaoExtra.nome}"`);
            }
            if (isNaN(valorFloat2) || valorFloat2 < 0) {
              throw new Error(`Segundo valor numérico inválido para a opção "${opcaoExtra.nome}"`);
            }
            
            opcoesExtrasValidadas.push({
              produtoOpcaoId: opcaoValor.produtoOpcaoId,
              valorString: null,
              valorFloat1: valorFloat1,
              valorFloat2: valorFloat2
            });
          }
        }
      }
    }

    // Deletar materiais antigos se houver novos
    if (materiaisValidados) {
      await prisma.orcamentoMaterial.deleteMany({
        where: { orcamentoId: id }
      });
    }

    // Deletar despesas antigas se houver novas
    if (despesasValidadas !== undefined) {
      await prisma.despesaAdicional.deleteMany({
        where: { orcamentoId: id }
      });
    }

    // Deletar opções extras antigas se houver novas
    if (opcoesExtrasValidadas !== undefined) {
      await prisma.orcamentoOpcaoExtra.deleteMany({
        where: { orcamentoId: id }
      });
    }

    // Preparar dados para atualização
    const updateData = {
      cliente: cliente ? cliente.trim() : undefined,
      numero: numero || undefined,
      status: status || undefined,
      produtoId: produtoId || undefined,
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

    // Adicionar opções extras apenas se houver
    if (opcoesExtrasValidadas !== undefined && opcoesExtrasValidadas.length > 0) {
      updateData.opcoesExtras = {
        create: opcoesExtrasValidadas
      };
    }

    // Atualizar orçamento
    const orcamento = await prisma.orcamento.update({
      where: { id },
      data: updateData,
      include: {
        produto: {
          include: {
            materiais: {
              include: {
                material: true
              }
            },
            opcoesExtras: true
          }
        },
        materiais: {
          include: {
            material: true
          }
        },
        despesasAdicionais: true,
        opcoesExtras: {
          include: {
            produtoOpcao: true
          }
        }
      }
    });

    // REGISTRAR LOG DE EDIÇÃO
    await logService.registrar({
      usuarioId: user?.id || 1,
      usuarioNome: user?.nome || 'Sistema',
      acao: 'EDITAR',
      entidade: 'ORCAMENTO',
      entidadeId: id,
      descricao: `Editou o orçamento "#${orcamento.numero}"`,
      detalhes: {
        antes: orcamentoAntigo,
        depois: orcamento,
      },
    });

    return orcamento;
  }

  async atualizarStatus(id, status, dadosAdicionais = {}, user) {
    const orcamento = await prisma.orcamento.findUnique({
      where: { id },
      include: {
        materiais: {
          include: {
            material: true
          }
        },
        despesasAdicionais: true,
        opcoesExtras: {
          include: {
            produtoOpcao: true
          }
        },
        pedido: true
      }
    });

    if (!orcamento) {
      throw new Error('Orçamento não encontrado');
    }

    if (!['Pendente', 'Aprovado', 'Não Aprovado'].includes(status)) {
      throw new Error('Status inválido');
    }

    // Se o status está sendo alterado para "Aprovado" e ainda não existe um pedido
    if (status === 'Aprovado' && !orcamento.pedido) {
      const pedidoData = {
        cliente: orcamento.cliente,
        numero: null,
        status: 'Em Andamento',
        produtoId: orcamento.produtoId,
        formaPagamento: orcamento.formaPagamento,
        condicoesPagamento: orcamento.condicoesPagamento,
        prazoEntrega: orcamento.prazoEntrega,
        orcamentoId: orcamento.id,
      };

      // Adicionar materiais do orçamento ao pedido
      if(orcamento.materiais && orcamento.materiais.length > 0) {
        pedidoData.materiais = {
          create: orcamento.materiais.map(m => ({
            materialId: m.materialId,
            quantidade: m.quantidade
          }))
        };
      }

      // Adicionar despesas adicionais do orçamento ao pedido
      if (orcamento.despesasAdicionais && orcamento.despesasAdicionais.length > 0) {
        pedidoData.despesasAdicionais = {
          create: orcamento.despesasAdicionais.map(d => ({
            descricao: d.descricao,
            valor: d.valor
          }))
        };
      }

      // Adicionar opções extras do orçamento ao pedido
      if (orcamento.opcoesExtras && orcamento.opcoesExtras.length > 0) {
        pedidoData.opcoesExtras = {
          create: orcamento.opcoesExtras.map(o => ({
            produtoOpcaoId: o.produtoOpcaoId,
            valorString: o.valorString,
            valorFloat1: o.valorFloat1,
            valorFloat2: o.valorFloat2
          }))
        };
      }

      // Criar o pedido em uma transação junto com a atualização do status
      return await prisma.$transaction(async (tx) => {
        // Criar o pedido
        const pedidoCriado = await tx.pedido.create({
          data: pedidoData,
          include: {
            materiais: {
              include: {
                material: true
              }
            },
            despesasAdicionais: true,
            opcoesExtras: {
              include: {
                produtoOpcao: true
              }
            }
          }
        });
        console.log('Pedido criado com opções extras:', {
          pedidoId: pedidoCriado.id,
          opcoesExtrasCount: pedidoCriado.opcoesExtras?.length || 0,
          opcoesExtras: pedidoCriado.opcoesExtras
        });
        // Atualizar o status do orçamento
        const orcamentoAtualizado = await tx.orcamento.update({
          where: { id },
          data: { status },
          include: {
            produto: {
              include: {
                materiais: {
                  include: {
                    material: true
                  }
                },
                opcoesExtras: true
              }
            },
            materiais: {
              include: {
                material: true
              }
            },
            despesasAdicionais: true,
            opcoesExtras: {
              include: {
                produtoOpcao: true
              }
            }
          }
        });

        // REGISTRAR LOG DE APROVAÇÃO E CRIAÇÃO DE PEDIDO
       await logService.registrar({
          usuarioId: user?.id || 1,
          usuarioNome: user?.nome || 'Sistema',
          acao: 'EDITAR',
          entidade: 'ORCAMENTO',
          entidadeId: id,
          descricao: `Aprovou o orçamento "#${orcamento.numero}" e um pedido foi criado`,
          detalhes: {
            statusAnterior: orcamento.status,
            statusNovo: status,
            pedidoCriado: pedidoCriado.id,
            opcoesExtrasTransferidas: pedidoCriado.opcoesExtras?.length || 0
          },
        });

        return orcamentoAtualizado;
      });
    }

    // Caso contrário, apenas atualizar o status
    const statusAnterior = orcamento.status;
    const orcamentoAtualizado = await prisma.orcamento.update({
      where: { id },
      data: { status },
      include: {
        produto: {
          include: {
            materiais: {
              include: {
                material: true
              }
            },
            opcoesExtras: true
          }
        },
        materiais: {
          include: {
            material: true
          }
        },
        despesasAdicionais: true,
        opcoesExtras: {
          include: {
            produtoOpcao: true
          }
        }
      }
    });

    // REGISTRAR LOG DE MUDANÇA DE STATUS
    await logService.registrar({
      usuarioId: user?.id || 1,
      usuarioNome: user?.nome || 'Sistema',
      acao: 'EDITAR',
      entidade: 'ORCAMENTO',
      entidadeId: id,
      descricao: `Alterou o status do orçamento "#${orcamento.numero}" de "${statusAnterior}" para "${status}"`,
      detalhes: {
        statusAnterior,
        statusNovo: status
      },
    });

    return orcamentoAtualizado;
  }

  async deletar(id, user) {
    // Buscar dados antes de deletar
    const orcamento = await prisma.orcamento.findUnique({
      where: { id },
      include: {
        produto: true,
        materiais: { include: { material: true } },
        despesasAdicionais: true,
        opcoesExtras: { include: { produtoOpcao: true } }
      }
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

    await prisma.orcamentoOpcaoExtra.deleteMany({
      where: { orcamentoId: id }
    });

    await prisma.orcamento.delete({
      where: { id }
    });

    // REGISTRAR LOG DE EXCLUSÃO
    await logService.registrar({
      usuarioId: user?.id || 1,
      usuarioNome: user?.nome || 'Sistema',
      acao: 'DELETAR',
      entidade: 'ORCAMENTO',
      entidadeId: id,
      descricao: `Excluiu o orçamento "#${orcamento.numero}"`,
      detalhes: orcamento,
    });
    
    return orcamento;
  }

  async listarProdutos() {
    return prisma.produto.findMany({
      include: {
        materiais: {
          include: {
            material: true
          }
        },
        opcoesExtras: true
      },
      orderBy: {
        nome: 'asc'
      }
    });
  }
}

module.exports = new OrcamentoService();