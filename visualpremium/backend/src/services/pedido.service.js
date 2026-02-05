const prisma = require('../config/prisma');
const logService = require('./log.service');

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
        },
        orcamento: {
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
        },
        orcamento: {
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
      prazoEntrega,
      orcamentoId
    } = data;

    // Validações básicas
    if (!cliente || !produtoId) {
      throw new Error('Cliente e produto são obrigatórios');
    }

    // Validar número se fornecido
    if (numero !== undefined && numero !== null) {
      if (typeof numero !== 'number' || numero <= 0) {
        throw new Error('Número do pedido inválido');
      }
      
      const pedidoDuplicado = await prisma.pedido.findFirst({
        where: { numero: numero }
      });
      
      if (pedidoDuplicado) {
        throw new Error('Já existe um pedido com este número');
      }
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

    // ✅ CORRIGIDO: Validar opções extras com tipos corretos (sem underscore)
    const opcoesExtrasValidadas = [];
    if (opcoesExtras && Array.isArray(opcoesExtras) && opcoesExtras.length > 0) {
      for (const opcaoValor of opcoesExtras) {
        const opcaoExtra = produto.opcoesExtras.find(o => o.id === opcaoValor.produtoOpcaoId);
        
        if (!opcaoExtra) {
          throw new Error(`Opção extra ${opcaoValor.produtoOpcaoId} não pertence ao produto`);
        }

        // ✅ NOVO: Verificar se é um registro "Não"
        const isNaoSelection = 
          (opcaoValor.valorString === null || opcaoValor.valorString === undefined) &&
          (opcaoValor.valorFloat1 === null || opcaoValor.valorFloat1 === undefined) &&
          (opcaoValor.valorFloat2 === null || opcaoValor.valorFloat2 === undefined);

        // ✅ MUDANÇA: Se for "Não", salvar com valores nulos
        if (isNaoSelection) {
          opcoesExtrasValidadas.push({
            produtoOpcaoId: opcaoValor.produtoOpcaoId,
            valorString: null,
            valorFloat1: null,
            valorFloat2: null
          });
          continue;
        }

        // Validar valores baseado no tipo (mesmo código anterior)
        if (opcaoExtra.tipo === 'STRINGFLOAT') {
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
        } else if (opcaoExtra.tipo === 'FLOATFLOAT') {
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
        } else if (opcaoExtra.tipo === 'PERCENTFLOAT') {
          const valorFloat1 = parseFloat(opcaoValor.valorFloat1);
          const valorFloat2 = parseFloat(opcaoValor.valorFloat2);
          
          if (isNaN(valorFloat1) || valorFloat1 < 0 || valorFloat1 > 100) {
            throw new Error(`Percentual inválido para a opção "${opcaoExtra.nome}" (deve estar entre 0 e 100)`);
          }
          if (isNaN(valorFloat2) || valorFloat2 < 0) {
            throw new Error(`Valor base inválido para a opção "${opcaoExtra.nome}"`);
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
      numero: numero || null,
      status: 'Em Andamento',
      produtoId,
      formaPagamento: formaPagamento.trim(),
      condicoesPagamento: condicoesPagamento.trim(),
      prazoEntrega: prazoEntrega.trim(),
     
      orcamentoId: orcamentoId || null
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

    // Criar pedido
    const pedido = await prisma.pedido.create({
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
        },
        orcamento: {
          select: {
            id: true,
            numero: true
          }
        }
      }
    });

    // REGISTRAR LOG DE CRIAÇÃO
    await logService.registrar({
      usuarioId: user?.id || 1,
      usuarioNome: user?.nome || 'Sistema',
      acao: 'CRIAR',
      entidade: 'PEDIDO',
      entidadeId: pedido.id,
      descricao: `Criou o pedido "${pedido.numero ? `#${pedido.numero}"` : `(ID: ${pedido.id})`}`,
      detalhes: pedido,
    });

    return pedido;
  }

  async atualizar(id, data, user) {
    // Buscar pedido antigo
    const pedidoAntigo = await prisma.pedido.findUnique({
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

    if (!pedidoAntigo) {
      throw new Error('Pedido não encontrado');
    }

    const { 
      cliente, 
      numero, 
      status,
      produtoId, 
      materiais,
      despesasAdicionais,
      opcoesExtras,
      formaPagamento,
      condicoesPagamento,
      prazoEntrega
    } = data;

    // Validar número se fornecido e diferente do atual
    if (numero !== undefined && numero !== null && numero !== pedidoAntigo.numero) {
      if (typeof numero !== 'number' || numero <= 0) {
        throw new Error('Número do pedido inválido');
      }
      
      const pedidoDuplicado = await prisma.pedido.findFirst({
        where: { 
          numero: numero,
          NOT: { id: id }
        }
      });
      
      if (pedidoDuplicado) {
        throw new Error('Já existe um pedido com este número');
      }
    }

    if (formaPagamento !== undefined && (!formaPagamento || formaPagamento.trim() === '')) {
      throw new Error('Forma de pagamento é obrigatória');
    }

    if (condicoesPagamento !== undefined && (!condicoesPagamento || condicoesPagamento.trim() === '')) {
      throw new Error('Condições de pagamento são obrigatórias');
    }

    if (prazoEntrega !== undefined && (!prazoEntrega || prazoEntrega.trim() === '')) {
      throw new Error('Prazo de entrega é obrigatório');
    }

    // Buscar produto se mudou
    let produto = pedidoAntigo.produto;
    let materiaisValidados = undefined;
    let despesasValidadas = undefined;
    let opcoesExtrasValidadas = undefined;

    if (produtoId && produtoId !== pedidoAntigo.produtoId) {
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
    }

    // Validar despesas adicionais se enviadas
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

    // Validar materiais se enviados
    if (materiais !== undefined) {
      materiaisValidados = [];
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
    }

    // ✅ CORRIGIDO: Validar opções extras se enviadas com tipos corretos
    if (opcoesExtras !== undefined) {
      opcoesExtrasValidadas = [];
      if (Array.isArray(opcoesExtras) && opcoesExtras.length > 0) {
        for (const opcaoValor of opcoesExtras) {
          const opcaoExtra = produto.opcoesExtras.find(o => o.id === opcaoValor.produtoOpcaoId);
          
          if (!opcaoExtra) {
            throw new Error(`Opção extra ${opcaoValor.produtoOpcaoId} não pertence ao produto`);
          }

          // Validar valores baseado no tipo
          if (opcaoExtra.tipo === 'STRINGFLOAT') {
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
          } else if (opcaoExtra.tipo === 'FLOATFLOAT') {
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
          } else if (opcaoExtra.tipo === 'PERCENTFLOAT') {
            // ✅ ADICIONADO: Validação para PERCENTFLOAT
            const valorFloat1 = parseFloat(opcaoValor.valorFloat1);
            const valorFloat2 = parseFloat(opcaoValor.valorFloat2);
            
            if (isNaN(valorFloat1) || valorFloat1 < 0 || valorFloat1 > 100) {
              throw new Error(`Percentual inválido para a opção "${opcaoExtra.nome}" (deve estar entre 0 e 100)`);
            }
            if (isNaN(valorFloat2) || valorFloat2 < 0) {
              throw new Error(`Valor base inválido para a opção "${opcaoExtra.nome}"`);
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

    // Deletar opções extras antigas se houver novas
    if (opcoesExtrasValidadas !== undefined) {
      await prisma.pedidoOpcaoExtra.deleteMany({
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
   
    // Outros campos
    if (formaPagamento !== undefined) updateData.formaPagamento = formaPagamento.trim();
    if (condicoesPagamento !== undefined) updateData.condicoesPagamento = condicoesPagamento.trim();
    if (prazoEntrega !== undefined) updateData.prazoEntrega = prazoEntrega.trim();

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

    // ✅ ATUALIZAR PEDIDO
    const pedidoAtualizado = await prisma.pedido.update({
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
        },
        orcamento: {
          select: {
            id: true,
            numero: true
          }
        }
      }
    });

    // REGISTRAR LOG DE EDIÇÃO
    await logService.registrar({
      usuarioId: user?.id || 1,
      usuarioNome: user?.nome || 'Sistema',
      acao: 'EDITAR',
      entidade: 'PEDIDO',
      entidadeId: id,
      descricao: `Editou o pedido "${pedidoAtualizado.numero ? `#${pedidoAtualizado.numero}"` : `(ID: ${id})`}`,
      detalhes: {
        antes: pedidoAntigo,
        depois: pedidoAtualizado,
      },
    });

    return pedidoAtualizado;
  }

  async atualizarStatus(id, status, user) {
    const pedido = await prisma.pedido.findUnique({
      where: { id }
    });

    if (!pedido) {
      throw new Error('Pedido não encontrado');
    }

    if (!['Em Andamento', 'Concluído', 'Cancelado'].includes(status)) {
      throw new Error('Status inválido');
    }

    const statusAnterior = pedido.status;
    const pedidoAtualizado = await prisma.pedido.update({
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
        },
        orcamento: {
          select: {
            id: true,
            numero: true
          }
        }
      }
    });

    // REGISTRAR LOG DE MUDANÇA DE STATUS
    await logService.registrar({
      usuarioId: user?.id || 1,
      usuarioNome: user?.nome || 'Sistema',
      acao: 'EDITAR',
      entidade: 'PEDIDO',
      entidadeId: id,
      descricao: `Alterou o status do pedido "${pedido.numero ? `#${pedido.numero}"` : `(ID: ${id})"`} de "${statusAnterior}" para "${status}"`,
      detalhes: {
        statusAnterior,
        statusNovo: status
      },
    });

    return pedidoAtualizado;
  }

  async deletar(id, user) {
    // Buscar dados antes de deletar
    const pedido = await prisma.pedido.findUnique({
      where: { id },
      include: {
        produto: true,
        materiais: { include: { material: true } },
        despesasAdicionais: true,
        opcoesExtras: { include: { produtoOpcao: true } }
      }
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

    await prisma.pedidoOpcaoExtra.deleteMany({
      where: { pedidoId: id }
    });

    await prisma.pedido.delete({
      where: { id }
    });

    // REGISTRAR LOG DE EXCLUSÃO
    await logService.registrar({
      usuarioId: user?.id || 1,
      usuarioNome: user?.nome || 'Sistema',
      acao: 'DELETAR',
      entidade: 'PEDIDO',
      entidadeId: id,
      descricao: `Excluiu o pedido "${pedido.numero ? `#${pedido.numero}"` : `(ID: ${id})"`}`,
      detalhes: pedido,
    });

    return pedido;
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

module.exports = new PedidoService();