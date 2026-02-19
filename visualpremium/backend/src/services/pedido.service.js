const prisma = require('../config/prisma');
const logService = require('./log.service');
const faixaCustoService = require('../services/faixaCustoMargem.service');

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

  async calcularValorSugerido(pedido) {
    try {
      // ✅ Calcular total BASE (sem sobras)
      let custoTotalBase = 0;
      
      // Materiais (sem sobras)
      if (pedido.materiais && pedido.materiais.length > 0) {
        for (const mat of pedido.materiais) {
          const custo = parseFloat(mat.custo) || 0;
          const quantidade = parseFloat(mat.quantidade) || 0;
          custoTotalBase += custo * quantidade;
        }
      }
      
      // Despesas adicionais
      if (pedido.despesasAdicionais && pedido.despesasAdicionais.length > 0) {
        for (const despesa of pedido.despesasAdicionais) {
          if (despesa.descricao !== '__NAO_SELECIONADO__') {
            custoTotalBase += parseFloat(despesa.valor) || 0;
          }
        }
      }
      
      // Opções extras não-percentuais
      if (pedido.opcoesExtras && pedido.opcoesExtras.length > 0) {
        for (const opcao of pedido.opcoesExtras) {
          if (opcao.valorString === '__NAO_SELECIONADO__') continue;
          
          const tipo = opcao.produtoOpcao?.tipo || opcao.tipo;
          
          if (tipo === 'STRINGFLOAT') {
            custoTotalBase += parseFloat(opcao.valorFloat1) || 0;
          } else if (tipo === 'FLOATFLOAT') {
            const valor1 = parseFloat(opcao.valorFloat1) || 0;
            const valor2 = parseFloat(opcao.valorFloat2) || 0;
            custoTotalBase += valor1 * valor2;
          }
        }
      }
      
      // Opções extras percentuais (aplicadas sobre a base)
      if (pedido.opcoesExtras && pedido.opcoesExtras.length > 0) {
        for (const opcao of pedido.opcoesExtras) {
          if (opcao.valorString === '__NAO_SELECIONADO__') continue;
          
          const tipo = opcao.produtoOpcao?.tipo || opcao.tipo;
          
          if (tipo === 'PERCENTFLOAT') {
            const percentual = parseFloat(opcao.valorFloat1) || 0;
            custoTotalBase += (percentual / 100.0) * custoTotalBase;
          }
        }
      }
      
      if (custoTotalBase <= 0) {
        return null;
      }
      
      // Buscar faixas de custo
      const faixas = await faixaCustoService.listar();
      
      if (!faixas || faixas.length === 0) {
        return null;
      }
      
      // Encontrar faixa aplicável baseada no custo BASE
      let faixaAplicavel = null;
      for (const faixa of faixas) {
        const dentroDoInicio = custoTotalBase >= faixa.custoInicio;
        const dentroDoFim = faixa.custoFim === null || custoTotalBase <= faixa.custoFim;
        
        if (dentroDoInicio && dentroDoFim) {
          faixaAplicavel = faixa;
          break;
        }
      }
      
      if (!faixaAplicavel) {
        return null;
      }
      
      const margem = parseFloat(faixaAplicavel.margem);
      
      // ✅ Aplicar margem sobre o custo BASE
      const valorComMargem = custoTotalBase * (margem / 100);
      
      // ✅ Calcular total de sobras separadamente
      let totalSobras = 0;
      if (pedido.materiais && pedido.materiais.length > 0) {
        for (const mat of pedido.materiais) {
          const valorSobra = parseFloat(mat.valorSobra) || 0;
          totalSobras += valorSobra;
        }
      }
      
      // ✅ Valor sugerido final = valor com margem + sobras
      const valorSugeridoFinal = valorComMargem + totalSobras;
      
      return {
        custoTotal: custoTotalBase,
        margem: margem,
        valorSugerido: valorSugeridoFinal,
        valorComMargem: valorComMargem,
        totalSobras: totalSobras,
        faixaId: faixaAplicavel.id,
        custoInicio: faixaAplicavel.custoInicio,
        custoFim: faixaAplicavel.custoFim,
      };
    } catch (error) {
      console.error('Erro ao calcular valor sugerido:', error);
      return null;
    }
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
        if (despesa.descricao === '__NAO_SELECIONADO__') {
          continue;
        }
        
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

        const matValidado = {
          materialId: m.materialId,
          quantidade: quantidadeNum,
          custo: material.material.custo,
        };

        if (m.alturaSobra !== undefined && m.alturaSobra !== null) {
          matValidado.alturaSobra = parseFloat(m.alturaSobra);
        } else if (m.quantidadeSobra !== undefined && m.quantidadeSobra !== null) {
          matValidado.alturaSobra = parseFloat(m.quantidadeSobra);
        }
        if (m.larguraSobra !== undefined && m.larguraSobra !== null) matValidado.larguraSobra = parseFloat(m.larguraSobra);
        if (m.valorSobra !== undefined && m.valorSobra !== null) matValidado.valorSobra = parseFloat(m.valorSobra);

        materiaisValidados.push(matValidado);
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
          opcaoValor.valorString === '__NAO_SELECIONADO__' ||
          (
            (opcaoValor.valorString === null || opcaoValor.valorString === undefined) &&
            (opcaoValor.valorFloat1 === null || opcaoValor.valorFloat1 === undefined) &&
            (opcaoValor.valorFloat2 === null || opcaoValor.valorFloat2 === undefined)
          );

        if (isNaoSelection) {
          opcoesExtrasValidadas.push({
            produtoOpcaoId: opcaoValor.produtoOpcaoId,
            valorString: '__NAO_SELECIONADO__',
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
      status: 'Pendente',
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
          if (despesa.descricao === '__NAO_SELECIONADO__') {
            continue;
          }
          
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

          const matValidadoAtualizar = {
            materialId: m.materialId,
            quantidade: quantidadeNum,
            custo: material.material.custo,
          };

          if (m.alturaSobra !== undefined && m.alturaSobra !== null) {
            matValidadoAtualizar.alturaSobra = parseFloat(m.alturaSobra);
          } else if (m.quantidadeSobra !== undefined && m.quantidadeSobra !== null) {
            matValidadoAtualizar.alturaSobra = parseFloat(m.quantidadeSobra);
          }
          if (m.larguraSobra !== undefined && m.larguraSobra !== null) matValidadoAtualizar.larguraSobra = parseFloat(m.larguraSobra);
          if (m.valorSobra !== undefined && m.valorSobra !== null) matValidadoAtualizar.valorSobra = parseFloat(m.valorSobra);

          materiaisValidados.push(matValidadoAtualizar);
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
            opcaoValor.valorString === '__NAO_SELECIONADO__' ||
            (
              (opcaoValor.valorString === null || opcaoValor.valorString === undefined) &&
              (opcaoValor.valorFloat1 === null || opcaoValor.valorFloat1 === undefined) &&
              (opcaoValor.valorFloat2 === null || opcaoValor.valorFloat2 === undefined)
            );

          if (isNaoSelection) {
            opcoesExtrasValidadas.push({
              produtoOpcaoId: opcaoValor.produtoOpcaoId,
              valorString: '__NAO_SELECIONADO__',
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

            // ✅ CORREÇÃO: preservar o valorFloat2 original (base salva no banco)
            // em vez de recalcular com o totalBase do request, que pode ser diferente
            const baseOriginal = (opcaoValor.valorFloat2 != null && opcaoValor.valorFloat2 !== undefined)
              ? parseFloat(opcaoValor.valorFloat2)
              : totalBase;
            
            opcoesExtrasValidadas.push({
              produtoOpcaoId: opcaoValor.produtoOpcaoId,
              valorString: null,
              valorFloat1: valorFloat1,
              valorFloat2: baseOriginal
            });
          }
        }
      }
    }

   const pedidoAtualizado = await prisma.$transaction(async (tx) => {
      if (materiaisValidados !== undefined) {
        await tx.pedidoMaterial.deleteMany({
          where: { pedidoId: id }
        });
      }

      if (despesasValidadas !== undefined) {
        await tx.pedidoDespesaAdicional.deleteMany({
          where: { pedidoId: id }
        });
      }

      if (opcoesExtrasValidadas !== undefined) {
        await tx.pedidoOpcaoExtra.deleteMany({
          where: { pedidoId: id }
        });
      }

      if (informacoesAdicionais !== undefined && Array.
        isArray(informacoesAdicionais)) {
        const informacoesExistentes = pedidoAntigo.informacoesAdicionais;
        const idsRecebidos = informacoesAdicionais
          .filter(info => info.id)
          .map(info => info.id);

        const idsParaDeletar = informacoesExistentes
          .filter(info => !idsRecebidos.includes(info.id))
          .map(info => info.id);

        if (idsParaDeletar.length > 0) {
          await tx.pedidoInformacaoAdicional.deleteMany({
            where: {
              id: { in: idsParaDeletar }
            }
          });
        }

        for (const info of informacoesAdicionais) {
          if (!info.data || !info.descricao || info.descricao.trim() === '') {
            throw new Error('Data e descrição são obrigatórias para informações adicionais');
          }

          const infoData = {
            data: new Date(info.data),
            descricao: info.descricao.trim()
          };

          if (info.id) {
            const infoExistente = await tx.pedidoInformacaoAdicional.findUnique({
              where: { id: info.id }
            });

            if (infoExistente) {
              const dataExistenteNormalizada = new Date(infoExistente.data);
              dataExistenteNormalizada.setMilliseconds(0);
              dataExistenteNormalizada.setSeconds(0);
              const dataNovaNormalizada = new Date(infoData.data);
              dataNovaNormalizada.setMilliseconds(0);
              dataNovaNormalizada.setSeconds(0);
              
              const dataChanged = dataExistenteNormalizada.getTime() !== dataNovaNormalizada.getTime();
              const descricaoChanged = infoExistente.descricao.trim() !== infoData.descricao.trim();
              
              if (dataChanged || descricaoChanged) {
                await tx.pedidoInformacaoAdicional.update({
                  where: { id: info.id },
                  data: {
                    ...infoData,
                    createdAt: infoExistente.createdAt,
                    updatedAt: new Date()
                  }
                });
              }
            }
          } else {
            const createData = {
              ...infoData,
              pedidoId: id
            };

            if (info.createdAt) {
              createData.createdAt = new Date(info.createdAt);
            }

            await tx.pedidoInformacaoAdicional.create({
              data: createData
            });
          }
        }
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

      return await tx.pedido.update({
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
    }); 

    await logService.registrar({
      usuarioId: user?.id || 1,
      usuarioNome: user?.nome || 'Sistema',
      acao: 'EDITAR',
      entidade: 'PEDIDO',
      entidadeId: id,
      descricao: `Concluiu o pedido "${pedidoAtualizado.numero ? `#${pedidoAtualizado.numero}"` : `(ID: ${id}) `}`,
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

    if (!['Pendente', 'Concluído', 'Cancelado'].includes(status)) {
      throw new Error('Status inválido');
    }

    const statusAnterior = pedido.status;
    
    console.log(`[PEDIDO] Atualizando status do pedido ${id}:`);
    console.log(`  - Status anterior: ${statusAnterior}`);
    console.log(`  - Status novo: ${status}`);
    console.log(`  - Tem almoxarifado? ${!!pedido.almoxarifado}`);
    
    if (status === 'Concluído' && statusAnterior !== 'Concluído' && !pedido.almoxarifado) {
      console.log(`[PEDIDO] Criando almoxarifado para o pedido ${id}...`);
      
      return await prisma.$transaction(async (tx) => {
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

    if (user.role !== 'admin') {
      throw new Error('Apenas administradores podem excluir pedidos');
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