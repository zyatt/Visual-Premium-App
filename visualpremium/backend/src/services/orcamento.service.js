const prisma = require('../config/prisma');
const logService = require('./log.service');

class OrcamentoService {
  async listar() {
    return prisma.orcamento.findMany({
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

    if (!orcamento) {
      throw new Error('Orçamento não encontrado');
    }

    return orcamento;
  }

  calcularTotalBase(materiais, despesasAdicionais, opcoesExtrasNaoPercentuais = []) {
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

    // Inclui opções extras não-percentuais (STRINGFLOAT e FLOATFLOAT) na base do cálculo percentual
    for (const opcao of opcoesExtrasNaoPercentuais) {
      if (opcao._tipo === 'STRINGFLOAT') {
        total += parseFloat(opcao.valorFloat1) || 0;
      } else if (opcao._tipo === 'FLOATFLOAT') {
        const f1 = parseFloat(opcao.valorFloat1) || 0;
        const f2 = parseFloat(opcao.valorFloat2) || 0;
        total += f1 * f2;
      }
    }

    return total;
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

      const orcamentoExistente = await prisma.orcamento.findFirst({
        where: { numero: numeroInt }
      });

      if (orcamentoExistente) {
        throw new Error(`Já existe um orçamento com o número ${numeroInt}`);
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

      // Primeira passagem: valida e coleta opções extras, separando percentuais das demais
      const opcoesExtrasValidadas = [];
      if (opcoesExtras && Array.isArray(opcoesExtras) && opcoesExtras.length > 0) {
        const opcoesPrimeiraPassagem = [];

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
            // CORREÇÃO: Salvar opções marcadas como "Não" no banco
            opcoesPrimeiraPassagem.push({
              tipo: opcaoExtra.tipo,
              isNaoSelection: true,
              dados: { produtoOpcaoId: opcaoValor.produtoOpcaoId, valorString: null, valorFloat1: null, valorFloat2: null }
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
            opcoesPrimeiraPassagem.push({
              tipo: 'STRINGFLOAT', isNaoSelection: false,
              dados: { produtoOpcaoId: opcaoValor.produtoOpcaoId, valorString: opcaoValor.valorString.trim(), valorFloat1: valorFloat1, valorFloat2: null }
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
            opcoesPrimeiraPassagem.push({
              tipo: 'FLOATFLOAT', isNaoSelection: false,
              dados: { produtoOpcaoId: opcaoValor.produtoOpcaoId, valorString: null, valorFloat1: valorFloat1, valorFloat2: valorFloat2 }
            });
          } else if (opcaoExtra.tipo === 'PERCENTFLOAT') {
            const valorFloat1 = parseFloat(opcaoValor.valorFloat1);
            if (isNaN(valorFloat1) || valorFloat1 < 0 || valorFloat1 > 100) {
              throw new Error(`Percentual inválido para a opção "${opcaoExtra.nome}" (deve estar entre 0 e 100)`);
            }
            // Percentuais ficam pendentes — precisam do totalBase completo
            opcoesPrimeiraPassagem.push({
              tipo: 'PERCENTFLOAT', isNaoSelection: false,
              percentual: valorFloat1,
              produtoOpcaoId: opcaoValor.produtoOpcaoId
            });
          }
        }

        // Calcula totalBase = materiais + despesas + opções extras não-percentuais
        const opcoesNaoPercentuaisParaBase = opcoesPrimeiraPassagem
          .filter(o => !o.isNaoSelection && (o.tipo === 'STRINGFLOAT' || o.tipo === 'FLOATFLOAT'))
          .map(o => ({ _tipo: o.tipo, valorFloat1: o.dados.valorFloat1, valorFloat2: o.dados.valorFloat2 }));

        const totalBase = this.calcularTotalBase(materiaisValidados, despesasValidadas, opcoesNaoPercentuaisParaBase);

        // Segunda passagem: resolve os PERCENTFLOAT com o totalBase completo
        for (const opcao of opcoesPrimeiraPassagem) {
          // CORREÇÃO: Incluir opções marcadas como "não" no banco de dados
          if (opcao.isNaoSelection) {
            opcoesExtrasValidadas.push(opcao.dados);
            continue;
          }

          if (opcao.tipo !== 'PERCENTFLOAT') {
            opcoesExtrasValidadas.push(opcao.dados);
          } else {
            opcoesExtrasValidadas.push({
              produtoOpcaoId: opcao.produtoOpcaoId,
              valorString: null,
              valorFloat1: opcao.percentual,
              valorFloat2: totalBase  // base completa: materiais + despesas + opções não-percentuais
            });
          }
        }
      }

      const createData = {
        cliente,
        numero: numeroInt,
        status: 'Pendente',
        produtoId,
        formaPagamento: formaPagamento.trim(),
        condicoesPagamento: condicoesPagamento.trim(),
        prazoEntrega: prazoEntrega.trim(),
      };

      if (materiaisValidados.length > 0) {
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

      const orcamento = await prisma.orcamento.create({
        data: createData,
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

      await logService.registrar({
        usuarioId: user?.id || 1,
        usuarioNome: user?.nome || 'Sistema',
        acao: 'CRIAR',
        entidade: 'ORCAMENTO',
        entidadeId: orcamento.id,
        descricao: `Criou o orçamento "#${orcamento.numero}"`,
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
      const { materiais, despesasAdicionais, opcoesExtras } = data;

      const orcamentoAtual = await prisma.orcamento.findUnique({
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

      if (!orcamentoAtual) {
        throw new Error('Orçamento não encontrado');
      }

      const produto = orcamentoAtual.produto;

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

      // Primeira passagem: valida e coleta opções extras, separando percentuais das demais
      const opcoesExtrasValidadas = [];
      if (opcoesExtras && Array.isArray(opcoesExtras) && opcoesExtras.length > 0) {
        const opcoesPrimeiraPassagem = [];

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
            // CORREÇÃO: Salvar opções marcadas como "Não" no banco
            opcoesPrimeiraPassagem.push({
              tipo: opcaoExtra.tipo,
              isNaoSelection: true,
              dados: { produtoOpcaoId: opcaoValor.produtoOpcaoId, valorString: null, valorFloat1: null, valorFloat2: null }
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
            opcoesPrimeiraPassagem.push({
              tipo: 'STRINGFLOAT', isNaoSelection: false,
              dados: { produtoOpcaoId: opcaoValor.produtoOpcaoId, valorString: opcaoValor.valorString.trim(), valorFloat1: valorFloat1, valorFloat2: null }
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
            opcoesPrimeiraPassagem.push({
              tipo: 'FLOATFLOAT', isNaoSelection: false,
              dados: { produtoOpcaoId: opcaoValor.produtoOpcaoId, valorString: null, valorFloat1: valorFloat1, valorFloat2: valorFloat2 }
            });
          } else if (opcaoExtra.tipo === 'PERCENTFLOAT') {
            const valorFloat1 = parseFloat(opcaoValor.valorFloat1);
            if (isNaN(valorFloat1) || valorFloat1 < 0 || valorFloat1 > 100) {
              throw new Error(`Percentual inválido para a opção "${opcaoExtra.nome}" (deve estar entre 0 e 100)`);
            }
            // Percentuais ficam pendentes — precisam do totalBase completo
            opcoesPrimeiraPassagem.push({
              tipo: 'PERCENTFLOAT', isNaoSelection: false,
              percentual: valorFloat1,
              produtoOpcaoId: opcaoValor.produtoOpcaoId
            });
          }
        }

        // Calcula totalBase = materiais + despesas + opções extras não-percentuais
        const opcoesNaoPercentuaisParaBase = opcoesPrimeiraPassagem
          .filter(o => !o.isNaoSelection && (o.tipo === 'STRINGFLOAT' || o.tipo === 'FLOATFLOAT'))
          .map(o => ({ _tipo: o.tipo, valorFloat1: o.dados.valorFloat1, valorFloat2: o.dados.valorFloat2 }));

        const totalBase = this.calcularTotalBase(materiaisValidados, despesasValidadas, opcoesNaoPercentuaisParaBase);

        // Segunda passagem: resolve os PERCENTFLOAT com o totalBase completo
        for (const opcao of opcoesPrimeiraPassagem) {
          // CORREÇÃO: Incluir opções marcadas como "não" no banco de dados
          if (opcao.isNaoSelection) {
            opcoesExtrasValidadas.push(opcao.dados);
            continue;
          }

          if (opcao.tipo !== 'PERCENTFLOAT') {
            opcoesExtrasValidadas.push(opcao.dados);
          } else {
            opcoesExtrasValidadas.push({
              produtoOpcaoId: opcao.produtoOpcaoId,
              valorString: null,
              valorFloat1: opcao.percentual,
              valorFloat2: totalBase  // base completa: materiais + despesas + opções não-percentuais
            });
          }
        }
      }

      const updateData = {};

      if (materiaisValidados.length > 0 || materiais === null) {
        await prisma.orcamentoMaterial.deleteMany({
          where: { orcamentoId: id }
        });
        
        if (materiaisValidados.length > 0) {
          updateData.materiais = {
            create: materiaisValidados
          };
        }
      }

      if (despesasValidadas.length > 0 || despesasAdicionais === null) {
        await prisma.despesaAdicional.deleteMany({
          where: { orcamentoId: id }
        });
        
        if (despesasValidadas.length > 0) {
          updateData.despesasAdicionais = {
            create: despesasValidadas
          };
        }
      }

      if (opcoesExtrasValidadas.length > 0 || opcoesExtras === null) {
        await prisma.orcamentoOpcaoExtra.deleteMany({
          where: { orcamentoId: id }
        });
        
        if (opcoesExtrasValidadas.length > 0) {
          updateData.opcoesExtras = {
            create: opcoesExtrasValidadas
          };
        }
      }

      const orcamentoAtualizado = await prisma.orcamento.update({
        where: { id },
        data: updateData,
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

      await logService.registrar({
        usuarioId: user?.id || 1,
        usuarioNome: user?.nome || 'Sistema',
        acao: 'EDITAR',
        entidade: 'ORCAMENTO',
        entidadeId: id,
        descricao: `Editou o orçamento "#${orcamentoAtualizado.numero}"`,
        detalhes: {
          antes: orcamentoAtual,
          depois: orcamentoAtualizado
        },
      });

      return orcamentoAtualizado;
    } catch (error) {
      console.error('Erro ao editar orçamento:', error);
      throw error;
    }
  }

  async editar(id, data, user) {
    return this.atualizar(id, data, user);
  }

  async atualizarStatus(id, status, user) {
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

        if(orcamento.materiais && orcamento.materiais.length > 0) {
          pedidoData.materiais = {
            create: orcamento.materiais.map(m => ({
              materialId: m.materialId,
              quantidade: m.quantidade,
              custo: m.custo,
            }))
          };
        }

        if (orcamento.despesasAdicionais && orcamento.despesasAdicionais.length > 0) {
          pedidoData.despesasAdicionais = {
            create: orcamento.despesasAdicionais.map(d => ({
              descricao: d.descricao,
              valor: d.valor
            }))
          };
        }

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

        return await prisma.$transaction(async (tx) => {
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
        opcoesExtras: true,
        avisos: {
          orderBy: { createdAt: 'desc' }
        },
      },
      orderBy: {
        nome: 'asc'
      }
    });
  }
}

module.exports = new OrcamentoService();