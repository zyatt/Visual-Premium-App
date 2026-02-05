const prisma = require('../config/prisma');
const logService = require('./log.service');

class OrcamentoService {
  async listar() {
    return prisma.orcamento.findMany({
      include: {
        produto: true, // ✅ Incluir produto para pegar o nome
        materiais: {
          include: {
            material: true
          }
        },
        despesasAdicionais: true,
        opcoesExtras: {
          include: {
            produtoOpcao: true // ✅ CRÍTICO: Incluir produtoOpcao para pegar nome e tipo
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
        produto: true, // ✅ Incluir produto
        materiais: {
          include: {
            material: true
          }
        },
        despesasAdicionais: true,
        opcoesExtras: {
          include: {
            produtoOpcao: true // ✅ CRÍTICO: Incluir produtoOpcao
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
    try {
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

      // Validar que numero é um inteiro válido
      const numeroInt = parseInt(numero);
      if (isNaN(numeroInt) || numeroInt <= 0) {
        throw new Error('Número do orçamento deve ser um valor inteiro positivo');
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

      // Verificar se já existe um orçamento com esse número
      const orcamentoExistente = await prisma.orcamento.findFirst({
        where: { numero: numeroInt }
      });

      if (orcamentoExistente) {
        throw new Error(`Já existe um orçamento com o número ${numeroInt}`);
      }

      // Verificar se o produto existe e buscar seus dados
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

      // Validar materiais - verificar se pertencem ao produto
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

      // Validar opções extras - verificar se pertencem ao produto
      const opcoesExtrasValidadas = [];
      if (opcoesExtras && Array.isArray(opcoesExtras) && opcoesExtras.length > 0) {
        for (const opcaoValor of opcoesExtras) {
          const opcaoExtra = produto.opcoesExtras.find(o => o.id === opcaoValor.produtoOpcaoId);
          
          if (!opcaoExtra) {
            throw new Error(`Opção extra ${opcaoValor.produtoOpcaoId} não pertence ao produto`);
          }

          // ✅ NOVO: Verificar se é um registro "Não" (todos os valores são null)
          const isNaoSelection = 
            (opcaoValor.valorString === null || opcaoValor.valorString === undefined) &&
            (opcaoValor.valorFloat1 === null || opcaoValor.valorFloat1 === undefined) &&
            (opcaoValor.valorFloat2 === null || opcaoValor.valorFloat2 === undefined);

          // ✅ MUDANÇA: Se for "Não", salvar com valores nulos sem validar
          if (isNaoSelection) {
            opcoesExtrasValidadas.push({
              produtoOpcaoId: opcaoValor.produtoOpcaoId,
              valorString: null,
              valorFloat1: null,
              valorFloat2: null
            });
            continue; // Pular validação de valores
          }

          // ✅ MUDANÇA: Só validar valores se não for "Não"
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

      const createData = {
        cliente: cliente.trim(),
        numero: numeroInt,
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
          produto: true, // ✅ Incluir produto
          materiais: {
            include: {
              material: true
            }
          },
          despesasAdicionais: true,
          opcoesExtras: {
            include: {
              produtoOpcao: true // ✅ CRÍTICO: Incluir produtoOpcao
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
    } catch (error) {
      console.error('Erro ao criar orçamento:', error);
      throw error;
    }
  }

  async atualizar(id, data, user) {
    try {
      const orcamentoAntigo = await prisma.orcamento.findUnique({
        where: { id },
        include: {
          produto: true,
          materiais: { include: { material: true } },
          despesasAdicionais: true,
          opcoesExtras: { include: { produtoOpcao: true } }
        }
      });

      if (!orcamentoAntigo) {
        throw new Error('Orçamento não encontrado');
      }

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

      const numeroInt = parseInt(numero);
      if (isNaN(numeroInt) || numeroInt <= 0) {
        throw new Error('Número do orçamento deve ser um valor inteiro positivo');
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

      // Verificar se já existe outro orçamento com esse número
      const orcamentoExistente = await prisma.orcamento.findFirst({
        where: { 
          numero: numeroInt,
          NOT: { id: id }
        }
      });

      if (orcamentoExistente) {
        throw new Error(`Já existe outro orçamento com o número ${numeroInt}`);
      }

      // Verificar se o produto existe
      const produto = await prisma.produto.findUnique({
        where: { id: produtoId },
        include: {
          materiais: { include: { material: true } },
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

          // Validar valores baseado no tipo (mesmo código de antes)
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

      // Deletar relacionamentos antigos
      await prisma.orcamentoMaterial.deleteMany({ where: { orcamentoId: id } });
      await prisma.despesaAdicional.deleteMany({ where: { orcamentoId: id } });
      await prisma.orcamentoOpcaoExtra.deleteMany({ where: { orcamentoId: id } });

      const updateData = {
        cliente: cliente.trim(),
        numero: numeroInt,
        produtoId,
        formaPagamento: formaPagamento.trim(),
        condicoesPagamento: condicoesPagamento.trim(),
        prazoEntrega: prazoEntrega.trim(),
      };

      // Adicionar materiais apenas se houver
      if (materiaisValidados.length > 0) {
        updateData.materiais = {
          create: materiaisValidados
        };
      }

      // Adicionar despesas apenas se houver
      if (despesasValidadas.length > 0) {
        updateData.despesasAdicionais = {
          create: despesasValidadas
        };
      }

      // Adicionar opções extras apenas se houver
      if (opcoesExtrasValidadas.length > 0) {
        updateData.opcoesExtras = {
          create: opcoesExtrasValidadas
        };
      }

      const orcamento = await prisma.orcamento.update({
        where: { id },
        data: updateData,
        include: {
          produto: true, // ✅ Incluir produto
          materiais: {
            include: {
              material: true
            }
          },
          despesasAdicionais: true,
          opcoesExtras: {
            include: {
              produtoOpcao: true // ✅ CRÍTICO: Incluir produtoOpcao
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
    } catch (error) {
      console.error('Erro ao atualizar orçamento:', error);
      throw error;
    }
  }

  async atualizarStatus(id, status, dadosAdicionais = {}, user) {
    try {
      const orcamento = await prisma.orcamento.findUnique({
        where: { id },
        include: {
          produto: true,
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
          
          // Atualizar o status do orçamento
          const orcamentoAtualizado = await tx.orcamento.update({
            where: { id },
            data: { status },
            include: {
              produto: true,
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
          produto: true,
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
    } catch (error) {
      console.error('Erro ao atualizar status do orçamento:', error);
      throw error;
    }
  }

  async deletar(id, user) {
    try {
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
    } catch (error) {
      console.error('Erro ao deletar orçamento:', error);
      throw error;
    }
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