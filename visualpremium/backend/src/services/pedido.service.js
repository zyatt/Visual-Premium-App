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
        informacoesAdicionais: {
          orderBy: {
            data: 'desc'
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
        informacoesAdicionais: {
          orderBy: {
            data: 'desc'
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

  calcularTotalBase(materiais, despesasAdicionais) {
    let total = 0;
    
    if (materiais && materiais.length > 0) {
      for (const m of materiais) {
        const custo = parseFloat(m.custo) || 0;
        const quantidade = parseFloat(m.quantidade) || 0;
        total += custo * quantidade;
      }
    }
    
    if (despesasAdicionais && despesasAdicionais.length > 0) {
      for (const d of despesasAdicionais) {
        total += parseFloat(d.valor) || 0;
      }
    }
    
    return total;
  }

  async criar(data, user) {
    const { 
      cliente, 
      numero, 
      produtoId, 
      materiais,
      despesasAdicionais,
      opcoesExtras,
      informacoesAdicionais,
      formaPagamento,
      condicoesPagamento,
      prazoEntrega,
      orcamentoId
    } = data;

    if (!cliente || !produtoId) {
      throw new Error('Cliente e produto são obrigatórios');
    }

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
          quantidade: quantidadeNum,
          custo: material.material.custo,
        });
      }
    }

    const totalBase = this.calcularTotalBase(materiaisValidados, despesasValidadas);

    const opcoesExtrasValidadas = [];
    if (opcoesExtras && Array.isArray(opcoesExtras) && opcoesExtras.length > 0) {
      for (const opcaoValor of opcoesExtras) {
        const opcaoExtra = produto.opcoesExtras.find(o => o.id === opcaoValor.produtoOpcaoId);
        
        if (!opcaoExtra) {
          throw new Error(`Opção extra ${opcaoValor.produtoOpcaoId} não pertence ao produto`);
        }

        const isNaoSelection = 
          (opcaoValor.valorString === null || opcaoValor.valorString === undefined) &&
          (opcaoValor.valorFloat1 === null || opcaoValor.valorFloat1 === undefined) &&
          (opcaoValor.valorFloat2 === null || opcaoValor.valorFloat2 === undefined);

        if (isNaoSelection) {
          opcoesExtrasValidadas.push({
            produtoOpcaoId: opcaoValor.produtoOpcaoId,
            valorString: null,
            valorFloat1: null,
            valorFloat2: null
          });
          continue;
        }

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
          
          if (isNaN(valorFloat1) || valorFloat1 < 0 || valorFloat1 > 100) {
            throw new Error(`Percentual inválido para a opção "${opcaoExtra.nome}" (deve estar entre 0 e 100)`);
          }
          
          opcoesExtrasValidadas.push({
            produtoOpcaoId: opcaoValor.produtoOpcaoId,
            valorString: null,
            valorFloat1: valorFloat1,
            valorFloat2: totalBase
          });
        }
      }
    }

    const informacoesValidadas = [];
    if (informacoesAdicionais && Array.isArray(informacoesAdicionais) && informacoesAdicionais.length > 0) {
      for (const info of informacoesAdicionais) {
        if (!info.data || !info.descricao || info.descricao.trim() === '') {
          throw new Error('Data e descrição são obrigatórias para informações adicionais');
        }
        informacoesValidadas.push({
          data: new Date(info.data),
          descricao: info.descricao.trim()
        });
      }
    }

    const createData = {
      cliente: cliente.trim(),
      status: 'Em Andamento',
      produtoId: produtoId,
      formaPagamento: formaPagamento.trim(),
      condicoesPagamento: condicoesPagamento.trim(),
      prazoEntrega: prazoEntrega.trim()
    };

    if (numero !== undefined && numero !== null) {
      createData.numero = numero;
    }

    if (orcamentoId !== undefined && orcamentoId !== null) {
      createData.orcamentoId = orcamentoId;
    }

    if (materiaisValidados && materiaisValidados.length > 0) {
      createData.materiais = {
        create: materiaisValidados
      };
    }

    if (despesasValidadas.length > 0) {
      createData.despesasAdicionais = {
        create: despesasValidadas
      };
    }

    if (opcoesExtrasValidadas.length > 0) {
      createData.opcoesExtras = {
        create: opcoesExtrasValidadas
      };
    }

    if (informacoesValidadas.length > 0) {
      createData.informacoesAdicionais = {
        create: informacoesValidadas
      };
    }

    const pedidoCriado = await prisma.pedido.create({
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
        informacoesAdicionais: {
          orderBy: {
            data: 'desc'
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

    await logService.registrar({
      usuarioId: user?.id || 1,
      usuarioNome: user?.nome || 'Sistema',
      acao: 'CRIAR',
      entidade: 'PEDIDO',
      entidadeId: pedidoCriado.id,
      descricao: `Criou o pedido "${pedidoCriado.numero ? `#${pedidoCriado.numero}"` : `(ID: ${pedidoCriado.id})`}" para o cliente "${pedidoCriado.cliente}"`,
      detalhes: pedidoCriado,
    });

    return pedidoCriado;
  }

  async atualizar(id, data, user) {
    const pedidoAntigo = await this.buscarPorId(id);

    const { 
      cliente, 
      numero, 
      status,
      produtoId, 
      materiais,
      despesasAdicionais,
      opcoesExtras,
      informacoesAdicionais,
      formaPagamento,
      condicoesPagamento,
      prazoEntrega
    } = data;

    if (numero !== undefined && numero !== null && numero !== pedidoAntigo.numero) {
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

    if (formaPagamento !== undefined && (!formaPagamento || formaPagamento.trim() === '')) {
      throw new Error('Forma de pagamento é obrigatória');
    }

    if (condicoesPagamento !== undefined && (!condicoesPagamento || condicoesPagamento.trim() === '')) {
      throw new Error('Condições de pagamento são obrigatórias');
    }

    if (prazoEntrega !== undefined && (!prazoEntrega || prazoEntrega.trim() === '')) {
      throw new Error('Prazo de entrega é obrigatório');
    }

    let produto;
    if (produtoId !== undefined && produtoId !== pedidoAntigo.produtoId) {
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
        where: { id: pedidoAntigo.produtoId },
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

    let materiaisValidados;
    if (materiais !== undefined) {
      materiaisValidados = [];
      if (materiais.length > 0) {
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
            quantidade: quantidadeNum,
            custo: material.material.custo,
          });
        }
      }
    }

    const totalBase = this.calcularTotalBase(materiaisValidados, despesasValidadas);

    let opcoesExtrasValidadas;
    if (opcoesExtras !== undefined) {
      opcoesExtrasValidadas = [];
      if (Array.isArray(opcoesExtras) && opcoesExtras.length > 0) {
        for (const opcaoValor of opcoesExtras) {
          const opcaoExtra = produto.opcoesExtras.find(o => o.id === opcaoValor.produtoOpcaoId);
          
          if (!opcaoExtra) {
            throw new Error(`Opção extra ${opcaoValor.produtoOpcaoId} não pertence ao produto`);
          }

          const isNaoSelection = 
            (opcaoValor.valorString === null || opcaoValor.valorString === undefined) &&
            (opcaoValor.valorFloat1 === null || opcaoValor.valorFloat1 === undefined) &&
            (opcaoValor.valorFloat2 === null || opcaoValor.valorFloat2 === undefined);

          if (isNaoSelection) {
            opcoesExtrasValidadas.push({
              produtoOpcaoId: opcaoValor.produtoOpcaoId,
              valorString: null,
              valorFloat1: null,
              valorFloat2: null
            });
            continue;
          }

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
            
            if (isNaN(valorFloat1) || valorFloat1 < 0 || valorFloat1 > 100) {
              throw new Error(`Percentual inválido para a opção "${opcaoExtra.nome}" (deve estar entre 0 e 100)`);
            }
            
            opcoesExtrasValidadas.push({
              produtoOpcaoId: opcaoValor.produtoOpcaoId,
              valorString: null,
              valorFloat1: valorFloat1,
              valorFloat2: totalBase
            });
          }
        }
      }
    }

    let informacoesValidadas;
    if (informacoesAdicionais !== undefined) {
      informacoesValidadas = [];
      if (Array.isArray(informacoesAdicionais) && informacoesAdicionais.length > 0) {
        for (const info of informacoesAdicionais) {
          if (!info.data || !info.descricao || info.descricao.trim() === '') {
            throw new Error('Data e descrição são obrigatórias para informações adicionais');
          }
          informacoesValidadas.push({
            data: new Date(info.data),
            descricao: info.descricao.trim()
          });
        }
      }
    }

    if (materiaisValidados !== undefined) {
      await prisma.pedidoMaterial.deleteMany({
        where: { pedidoId: id }
      });
    }

    if (despesasValidadas !== undefined) {
      await prisma.pedidoDespesaAdicional.deleteMany({
        where: { pedidoId: id }
      });
    }

    if (opcoesExtrasValidadas !== undefined) {
      await prisma.pedidoOpcaoExtra.deleteMany({
        where: { pedidoId: id }
      });
    }

    if (informacoesValidadas !== undefined) {
      await prisma.pedidoInformacaoAdicional.deleteMany({
        where: { pedidoId: id }
      });
    }

    const updateData = {};
    
    if (cliente !== undefined) updateData.cliente = cliente.trim();
    if (status !== undefined) updateData.status = status;
    if (produtoId !== undefined) updateData.produtoId = produtoId;
    if (numero !== undefined) updateData.numero = numero;
   
    if (formaPagamento !== undefined) updateData.formaPagamento = formaPagamento.trim();
    if (condicoesPagamento !== undefined) updateData.condicoesPagamento = condicoesPagamento.trim();
    if (prazoEntrega !== undefined) updateData.prazoEntrega = prazoEntrega.trim();

    if (materiaisValidados !== undefined && materiaisValidados.length > 0) {
      updateData.materiais = {
        create: materiaisValidados
      };
    }

    if (despesasValidadas !== undefined && despesasValidadas.length > 0) {
      updateData.despesasAdicionais = {
        create: despesasValidadas
      };
    }

    if (opcoesExtrasValidadas !== undefined && opcoesExtrasValidadas.length > 0) {
      updateData.opcoesExtras = {
        create: opcoesExtrasValidadas
      };
    }

    if (informacoesValidadas !== undefined && informacoesValidadas.length > 0) {
      updateData.informacoesAdicionais = {
        create: informacoesValidadas
      };
    }

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
        informacoesAdicionais: {
          orderBy: {
            data: 'desc'
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
      where: { id },
      include: {
        almoxarifado: true,
        produto: true
      }
    });

    if (!pedido) {
      throw new Error('Pedido não encontrado');
    }

    if (!['Em Andamento', 'Concluído', 'Cancelado'].includes(status)) {
      throw new Error('Status inválido');
    }

    const statusAnterior = pedido.status;
    
    console.log(`[PEDIDO] Atualizando status do pedido ${id}:`);
    console.log(`  - Status anterior: ${statusAnterior}`);
    console.log(`  - Status novo: ${status}`);
    console.log(`  - Tem almoxarifado? ${!!pedido.almoxarifado}`);
    
    // Se o status está mudando para "Concluído" e não existe almoxarifado, criar
    if (status === 'Concluído' && statusAnterior !== 'Concluído' && !pedido.almoxarifado) {
      console.log(`[PEDIDO] Criando almoxarifado para o pedido ${id}...`);
      
      return await prisma.$transaction(async (tx) => {
        // Atualizar status do pedido
        const pedidoAtualizado = await tx.pedido.update({
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
            informacoesAdicionais: {
              orderBy: {
                data: 'desc'
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

        // Criar almoxarifado vazio
        const almoxarifado = await tx.almoxarifado.create({
          data: {
            pedidoId: id,
            status: 'Não Realizado'
          }
        });

        console.log(`[PEDIDO] Almoxarifado ${almoxarifado.id} criado com sucesso para o pedido ${id}`);

        await logService.registrar({
          usuarioId: user?.id || 1,
          usuarioNome: user?.nome || 'Sistema',
          acao: 'EDITAR',
          entidade: 'PEDIDO',
          entidadeId: id,
          descricao: `Alterou o status do pedido "${pedido.numero ? `#${pedido.numero}"` : `(ID: ${id})"`} de "${statusAnterior}" para "${status}" e criou almoxarifado`,
          detalhes: {
            statusAnterior,
            statusNovo: status,
            almoxarifadoCriado: true,
            almoxarifadoId: almoxarifado.id
          },
        });

        return pedidoAtualizado;
      });
    }

    console.log(`[PEDIDO] Atualizando apenas o status (sem criar almoxarifado)`);

    // Atualizar apenas o status
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
        informacoesAdicionais: {
          orderBy: {
            data: 'desc'
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
    const pedido = await prisma.pedido.findUnique({
      where: { id },
      include: {
        produto: true,
        materiais: { include: { material: true } },
        despesasAdicionais: true,
        opcoesExtras: { include: { produtoOpcao: true } },
        informacoesAdicionais: true
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

    await prisma.pedidoInformacaoAdicional.deleteMany({
      where: { pedidoId: id }
    });

    await prisma.pedido.delete({
      where: { id }
    });

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