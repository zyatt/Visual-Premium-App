const prisma = require('../config/prisma');
const logService = require('./log.service');
const faixaCustoService = require('../services/faixaCustoMargem.service');

class OrcamentoService {
  // Método auxiliar para verificar se o orçamento está completo
  verificarOrcamentoCompleto(data, produto) {
    const {
      cliente,
      numero,
      produtoId,
      formaPagamento,
      condicoesPagamento,
      prazoEntrega,
      materiais,
      opcoesExtras
    } = data;

    // Validações básicas obrigatórias
    if (!cliente || !numero || !produtoId) {
      return false;
    }

    if (!formaPagamento || formaPagamento.trim() === '') {
      return false;
    }

    if (!condicoesPagamento || condicoesPagamento.trim() === '') {
      return false;
    }

    if (!prazoEntrega || prazoEntrega.trim() === '') {
      return false;
    }

    // Validar materiais
    if (!materiais || materiais.length === 0) {
      return false;
    }

    // Verificar se todos os materiais do produto têm quantidade preenchida
    const materiaisValidos = produto.materiais.every(pm => {
      const materialPreenchido = materiais.find(m => m.materialId === pm.materialId);
      if (!materialPreenchido) return false;
      
      const quantidade = parseFloat(materialPreenchido.quantidade);
      return !isNaN(quantidade) && quantidade >= 0;
    });

    if (!materiaisValidos) {
      return false;
    }

    // Validar opções extras
    if (opcoesExtras && Array.isArray(opcoesExtras) && opcoesExtras.length > 0) {
      for (const opcaoValor of opcoesExtras) {
        const opcaoExtra = produto.opcoesExtras.find(o => o.id === opcaoValor.produtoOpcaoId);
        
        if (!opcaoExtra) continue;

        const isNaoSelection =
          opcaoValor.valorString === '__NAO_SELECIONADO__' ||
          (
            (opcaoValor.valorString === null || opcaoValor.valorString === undefined) &&
            (opcaoValor.valorFloat1 === null || opcaoValor.valorFloat1 === undefined) &&
            (opcaoValor.valorFloat2 === null || opcaoValor.valorFloat2 === undefined)
          );

        if (isNaoSelection) continue;

        // Validar STRINGFLOAT
        if (opcaoExtra.tipo === 'STRINGFLOAT') {
          if (!opcaoValor.valorString || opcaoValor.valorString.trim() === '') {
            return false;
          }
          if (opcaoValor.valorFloat1 == null || opcaoValor.valorFloat1 < 0) {
            return false;
          }
        }

        // Validar FLOATFLOAT
        if (opcaoExtra.tipo === 'FLOATFLOAT') {
          if (opcaoValor.valorFloat1 == null || opcaoValor.valorFloat1 < 0) {
            return false;
          }
          if (opcaoValor.valorFloat2 == null || opcaoValor.valorFloat2 < 0) {
            return false;
          }
        }

        // Validar PERCENTFLOAT
        if (opcaoExtra.tipo === 'PERCENTFLOAT') {
          if (opcaoValor.valorFloat1 == null || opcaoValor.valorFloat1 < 0 || opcaoValor.valorFloat1 > 100) {
            return false;
          }
        }
      }
    }

    return true;
  }

  async calcularValorSugerido(orcamento) {
    try {
      // ✅ Calcular total BASE (sem sobras)
      let custoTotalBase = 0;
      
      // Materiais (sem sobras)
      if (orcamento.materiais && orcamento.materiais.length > 0) {
        for (const mat of orcamento.materiais) {
          const custo = parseFloat(mat.custo) || 0;
          const quantidade = parseFloat(mat.quantidade) || 0;
          custoTotalBase += custo * quantidade;
        }
      }
      
      // Despesas adicionais
      if (orcamento.despesasAdicionais && orcamento.despesasAdicionais.length > 0) {
        for (const despesa of orcamento.despesasAdicionais) {
          if (despesa.descricao !== '__NAO_SELECIONADO__') {
            custoTotalBase += parseFloat(despesa.valor) || 0;
          }
        }
      }
      
      // Opções extras não-percentuais
      if (orcamento.opcoesExtras && orcamento.opcoesExtras.length > 0) {
        for (const opcao of orcamento.opcoesExtras) {
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

      // Base para percentual = materiais + despesas + opções extras não-percentuais (sem sobras)
      const custoBasePercentual = custoTotalBase;
      
      // Opções extras percentuais (aplicadas sobre materiais + despesas + opções extras, SEM sobras)
      if (orcamento.opcoesExtras && orcamento.opcoesExtras.length > 0) {
        for (const opcao of orcamento.opcoesExtras) {
          if (opcao.valorString === '__NAO_SELECIONADO__') continue;
          
          const tipo = opcao.produtoOpcao?.tipo || opcao.tipo;
          
          if (tipo === 'PERCENTFLOAT') {
            const percentual = parseFloat(opcao.valorFloat1) || 0;
            custoTotalBase += (percentual / 100.0) * custoBasePercentual;
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
      if (orcamento.materiais && orcamento.materiais.length > 0) {
        for (const mat of orcamento.materiais) {
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

  async listar() {
    const orcamentos = await prisma.orcamento.findMany({
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
        informacoesAdicionais: {
          orderBy: {
            data: 'desc'
          }
        }
      },
      orderBy: {
        createdAt: 'desc'
      }
    });

    const orcamentosComValorSugerido = await Promise.all(
      orcamentos.map(async (orcamento) => {
        const valorSugerido = await this.calcularValorSugerido(orcamento);
        return {
          ...orcamento,
          valorSugerido: valorSugerido?.valorSugerido || null
        };
      })
    );

    return orcamentosComValorSugerido;
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
        },
        informacoesAdicionais: {
          orderBy: {
            data: 'desc'
          }
        }
      }
    });

    if (!orcamento) {
      throw new Error('Orçamento não encontrado');
    }

    const valorSugerido = await this.calcularValorSugerido(orcamento);

    return {
      ...orcamento,
      valorSugerido: valorSugerido?.valorSugerido || null
    };
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
        prazoEntrega,
        rascunho
      } = data;

      // Validações básicas obrigatórias (sempre necessárias)
      if (!cliente || !numero || !produtoId) {
        throw new Error('Cliente, número e produto são obrigatórios');
      }

      const numeroInt = parseInt(numero);
      if (isNaN(numeroInt) || numeroInt <= 0) {
        throw new Error('Número do orçamento deve ser um valor inteiro positivo');
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

      const ehRascunho = rascunho !== false;

      if (!ehRascunho) {
        if (!formaPagamento || formaPagamento.trim() === '') {
          throw new Error('Forma de pagamento é obrigatória');
        }

        if (!condicoesPagamento || condicoesPagamento.trim() === '') {
          throw new Error('Condições de pagamento são obrigatórias');
        }

        if (!prazoEntrega || prazoEntrega.trim() === '') {
          throw new Error('Prazo de entrega é obrigatório');
        }
      }

      const despesasValidadas = [];
      if (despesasAdicionais && Array.isArray(despesasAdicionais) && despesasAdicionais.length > 0) {
        for (const despesa of despesasAdicionais) {
          if (despesa.descricao === '__NAO_SELECIONADO__' && despesa.valor === 0) {
            despesasValidadas.push({
              descricao: '__NAO_SELECIONADO__',
              valor: 0
            });
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

          const materialValidado = {
            materialId: m.materialId,
            quantidade: quantidadeNum,
            custo: material.material.custo,
          };
          
          if (m.alturaSobra !== undefined && m.alturaSobra !== null) {
            materialValidado.alturaSobra = parseFloat(m.alturaSobra);
          }
          if (m.larguraSobra !== undefined && m.larguraSobra !== null) {
            materialValidado.larguraSobra = parseFloat(m.larguraSobra);
          }
          if (m.valorSobra !== undefined && m.valorSobra !== null) {
            materialValidado.valorSobra = parseFloat(m.valorSobra);
          }

          materiaisValidados.push(materialValidado);
        }
      }

      const opcoesExtrasValidadas = [];
      if (opcoesExtras && Array.isArray(opcoesExtras) && opcoesExtras.length > 0) {
        const opcoesPrimeiraPassagem = [];

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
            opcoesPrimeiraPassagem.push({
              produtoOpcaoId: opcaoValor.produtoOpcaoId,
              valorString: '__NAO_SELECIONADO__',
              valorFloat1: null,
              valorFloat2: null,
              _tipo: opcaoExtra.tipo,
            });
            continue;
          }

          const obj = {
            produtoOpcaoId: opcaoValor.produtoOpcaoId,
            valorString: opcaoValor.valorString || null,
            valorFloat1: opcaoValor.valorFloat1 != null ? parseFloat(opcaoValor.valorFloat1) : null,
            valorFloat2: opcaoValor.valorFloat2 != null ? parseFloat(opcaoValor.valorFloat2) : null,
            _tipo: opcaoExtra.tipo,
          };

          opcoesPrimeiraPassagem.push(obj);
        }

        const opcoesNaoPercentuais = opcoesPrimeiraPassagem.filter(o =>
          (o._tipo === 'STRINGFLOAT' || o._tipo === 'FLOATFLOAT') &&
          o.valorString !== '__NAO_SELECIONADO__'
        );

        const baseParaPercentuais = this.calcularTotalBase(materiaisValidados, despesasValidadas, opcoesNaoPercentuais);

        for (const opcao of opcoesPrimeiraPassagem) {
          const { _tipo, ...opcaoSemTipo } = opcao;

          if (opcaoSemTipo.valorString === '__NAO_SELECIONADO__') {
            opcoesExtrasValidadas.push(opcaoSemTipo);
            continue;
          }

          if (!ehRascunho) {
            if (_tipo === 'STRINGFLOAT') {
              if (!opcaoSemTipo.valorString || opcaoSemTipo.valorString.trim() === '') {
                throw new Error(`Opção extra ${opcao.produtoOpcaoId} requer uma string`);
              }
              if (opcaoSemTipo.valorFloat1 == null || opcaoSemTipo.valorFloat1 < 0) {
                throw new Error(`Opção extra ${opcao.produtoOpcaoId} requer um valor numérico positivo`);
              }
            } else if (_tipo === 'FLOATFLOAT') {
              if (opcaoSemTipo.valorFloat1 == null || opcaoSemTipo.valorFloat1 < 0) {
                throw new Error(`Opção extra ${opcao.produtoOpcaoId} requer dois valores numéricos positivos (float1)`);
              }
              if (opcaoSemTipo.valorFloat2 == null || opcaoSemTipo.valorFloat2 < 0) {
                throw new Error(`Opção extra ${opcao.produtoOpcaoId} requer dois valores numéricos positivos (float2)`);
              }
            } else if (_tipo === 'PERCENTFLOAT') {
              if (opcaoSemTipo.valorFloat1 == null || opcaoSemTipo.valorFloat1 < 0 || opcaoSemTipo.valorFloat1 > 100) {
                throw new Error(`Opção extra ${opcao.produtoOpcaoId} requer um percentual entre 0 e 100`);
              }
              opcaoSemTipo.valorFloat2 = baseParaPercentuais;
            }
          } else {
            if (_tipo === 'PERCENTFLOAT' && opcaoSemTipo.valorFloat1 != null) {
              opcaoSemTipo.valorFloat2 = baseParaPercentuais;
            }
          }

          opcoesExtrasValidadas.push(opcaoSemTipo);
        }
      }

      const orcamento = await prisma.orcamento.create({
        data: {
          cliente: cliente.trim(),
          numero: numeroInt,
          produtoId,
          formaPagamento: ehRascunho 
            ? (formaPagamento || '').trim() 
            : ((formaPagamento || '').trim() || 'A definir'),
          condicoesPagamento: ehRascunho 
            ? (condicoesPagamento || '').trim() 
            : ((condicoesPagamento || '').trim() || 'A definir'),
          prazoEntrega: ehRascunho 
            ? (prazoEntrega || '').trim() 
            : ((prazoEntrega || '').trim() || 'A definir'),
          status: 'Pendente',
          rascunho: ehRascunho,
          materiais: materiaisValidados.length > 0 ? {
            create: materiaisValidados
          } : undefined,
          despesasAdicionais: despesasValidadas.length > 0 ? {
            create: despesasValidadas
          } : undefined,
          opcoesExtras: opcoesExtrasValidadas.length > 0 ? {
            create: opcoesExtrasValidadas
          } : undefined,
        },
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
          informacoesAdicionais: {
            orderBy: {
              data: 'desc'
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
        descricao: `Criou o orçamento "#${orcamento.numero}"${ehRascunho ? ' (rascunho)' : ' (finalizado)'}`,
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
      const orcamentoAtual = await prisma.orcamento.findUnique({
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
          informacoesAdicionais: {
            orderBy: {
              data: 'desc'
            }
          },
          pedido: true
        }
      });

      if (!orcamentoAtual) {
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
        prazoEntrega,
        informacoesAdicionais,
        rascunho
      } = data;

      if (!cliente || !numero || !produtoId) {
        throw new Error('Cliente, número e produto são obrigatórios');
      }

      const numeroInt = parseInt(numero);
      if (isNaN(numeroInt) || numeroInt <= 0) {
        throw new Error('Número do orçamento deve ser um valor inteiro positivo');
      }

      if (numeroInt !== orcamentoAtual.numero) {
        const orcamentoExistente = await prisma.orcamento.findFirst({
          where: { 
            numero: numeroInt,
            id: { not: id }
          }
        });

        if (orcamentoExistente) {
          throw new Error(`Já existe um orçamento com o número ${numeroInt}`);
        }
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

      const ehRascunho = rascunho !== false;

      if (!ehRascunho) {
        if (!formaPagamento || formaPagamento.trim() === '') {
          throw new Error('Forma de pagamento é obrigatória');
        }

        if (!condicoesPagamento || condicoesPagamento.trim() === '') {
          throw new Error('Condições de pagamento são obrigatórias');
        }

        if (!prazoEntrega || prazoEntrega.trim() === '') {
          throw new Error('Prazo de entrega é obrigatório');
        }
      }

      const despesasValidadas = [];
      if (despesasAdicionais && Array.isArray(despesasAdicionais) && despesasAdicionais.length > 0) {
        for (const despesa of despesasAdicionais) {
          if (despesa.descricao === '__NAO_SELECIONADO__' && despesa.valor === 0) {
            despesasValidadas.push({
              descricao: '__NAO_SELECIONADO__',
              valor: 0
            });
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

          const materialValidado = {
            materialId: m.materialId,
            quantidade: quantidadeNum,
            custo: material.material.custo,
          };
          
          if (m.alturaSobra !== undefined && m.alturaSobra !== null) {
            materialValidado.alturaSobra = parseFloat(m.alturaSobra);
          }
          if (m.larguraSobra !== undefined && m.larguraSobra !== null) {
            materialValidado.larguraSobra = parseFloat(m.larguraSobra);
          }
          if (m.quantidadeSobra !== undefined && m.quantidadeSobra !== null) {
            materialValidado.quantidadeSobra = parseFloat(m.quantidadeSobra);
          }
          if (m.valorSobra !== undefined && m.valorSobra !== null) {
            materialValidado.valorSobra = parseFloat(m.valorSobra);
          }

          materiaisValidados.push(materialValidado);
        }
      }

      const opcoesExtrasValidadas = [];
      if (opcoesExtras && Array.isArray(opcoesExtras) && opcoesExtras.length > 0) {
        const opcoesPrimeiraPassagem = [];

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
            opcoesPrimeiraPassagem.push({
              produtoOpcaoId: opcaoValor.produtoOpcaoId,
              valorString: '__NAO_SELECIONADO__',
              valorFloat1: null,
              valorFloat2: null,
              _tipo: opcaoExtra.tipo,
            });
            continue;
          }

          const obj = {
            produtoOpcaoId: opcaoValor.produtoOpcaoId,
            valorString: opcaoValor.valorString || null,
            valorFloat1: opcaoValor.valorFloat1 != null ? parseFloat(opcaoValor.valorFloat1) : null,
            valorFloat2: opcaoValor.valorFloat2 != null ? parseFloat(opcaoValor.valorFloat2) : null,
            _tipo: opcaoExtra.tipo,
          };

          opcoesPrimeiraPassagem.push(obj);
        }

        const opcoesNaoPercentuais = opcoesPrimeiraPassagem.filter(o =>
          (o._tipo === 'STRINGFLOAT' || o._tipo === 'FLOATFLOAT') &&
          o.valorString !== '__NAO_SELECIONADO__'
        );

        const baseParaPercentuais = this.calcularTotalBase(materiaisValidados, despesasValidadas, opcoesNaoPercentuais);

        for (const opcao of opcoesPrimeiraPassagem) {
          const { _tipo, ...opcaoSemTipo } = opcao;

          if (opcaoSemTipo.valorString === '__NAO_SELECIONADO__') {
            opcoesExtrasValidadas.push(opcaoSemTipo);
            continue;
          }

          if (!ehRascunho) {
            if (_tipo === 'STRINGFLOAT') {
              if (!opcaoSemTipo.valorString || opcaoSemTipo.valorString.trim() === '') {
                throw new Error(`Opção extra ${opcao.produtoOpcaoId} requer uma string`);
              }
              if (opcaoSemTipo.valorFloat1 == null || opcaoSemTipo.valorFloat1 < 0) {
                throw new Error(`Opção extra ${opcao.produtoOpcaoId} requer um valor numérico positivo`);
              }
            } else if (_tipo === 'FLOATFLOAT') {
              if (opcaoSemTipo.valorFloat1 == null || opcaoSemTipo.valorFloat1 < 0) {
                throw new Error(`Opção extra ${opcao.produtoOpcaoId} requer dois valores numéricos positivos (float1)`);
              }
              if (opcaoSemTipo.valorFloat2 == null || opcaoSemTipo.valorFloat2 < 0) {
                throw new Error(`Opção extra ${opcao.produtoOpcaoId} requer dois valores numéricos positivos (float2)`);
              }
            } else if (_tipo === 'PERCENTFLOAT') {
              if (opcaoSemTipo.valorFloat1 == null || opcaoSemTipo.valorFloat1 < 0 || opcaoSemTipo.valorFloat1 > 100) {
                throw new Error(`Opção extra ${opcao.produtoOpcaoId} requer um percentual entre 0 e 100`);
              }
              opcaoSemTipo.valorFloat2 = baseParaPercentuais;
            }
          } else {
            if (_tipo === 'PERCENTFLOAT' && opcaoSemTipo.valorFloat1 != null) {
              opcaoSemTipo.valorFloat2 = baseParaPercentuais;
            }
          }

          opcoesExtrasValidadas.push(opcaoSemTipo);
        }
      }

      const orcamentoAtualizado = await prisma.$transaction(async (tx) => {
        await tx.orcamentoMaterial.deleteMany({
          where: { orcamentoId: id }
        });
        await tx.despesaAdicional.deleteMany({
          where: { orcamentoId: id }
        });
        await tx.orcamentoOpcaoExtra.deleteMany({
          where: { orcamentoId: id }
        });

        if (informacoesAdicionais && Array.isArray(informacoesAdicionais)) {
          const informacoesExistentes = orcamentoAtual.informacoesAdicionais;
          const idsRecebidos = informacoesAdicionais
            .filter(info => info.id)
            .map(info => info.id);

          const idsParaDeletar = informacoesExistentes
            .filter(info => !idsRecebidos.includes(info.id))
            .map(info => info.id);

          if (idsParaDeletar.length > 0) {
            await tx.orcamentoInformacaoAdicional.deleteMany({
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
              const infoExistente = await tx.orcamentoInformacaoAdicional.findUnique({
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
                  await tx.orcamentoInformacaoAdicional.update({
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
                orcamentoId: id
              };

              if (info.createdAt) {
                createData.createdAt = new Date(info.createdAt);
              }

              await tx.orcamentoInformacaoAdicional.create({
                data: createData
              });
            }
          }
        } else {
          await tx.orcamentoInformacaoAdicional.deleteMany({
            where: { orcamentoId: id }
          });
        }

        const orc = await tx.orcamento.update({
          where: { id },
          data: {
            cliente: cliente.trim(),
            numero: numeroInt,
            produtoId,
            formaPagamento: ehRascunho 
              ? (formaPagamento || '').trim() 
              : ((formaPagamento || '').trim() || 'A definir'),
            condicoesPagamento: ehRascunho 
              ? (condicoesPagamento || '').trim() 
              : ((condicoesPagamento || '').trim() || 'A definir'),
            prazoEntrega: ehRascunho 
              ? (prazoEntrega || '').trim() 
              : ((prazoEntrega || '').trim() || 'A definir'),
            rascunho: ehRascunho,
            materiais: materiaisValidados.length > 0 ? {
              create: materiaisValidados
            } : undefined,
            despesasAdicionais: despesasValidadas.length > 0 ? {
              create: despesasValidadas
            } : undefined,
            opcoesExtras: opcoesExtrasValidadas.length > 0 ? {
              create: opcoesExtrasValidadas
            } : undefined,
          },
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
            informacoesAdicionais: {
              orderBy: {
                data: 'desc'
              }
            }
          }
        });

        if (orcamentoAtual.status === 'Aprovado' && orcamentoAtual.pedido) {
          const pedidoInfosExistentes = await tx.pedidoInformacaoAdicional.findMany({
            where: { pedidoId: orcamentoAtual.pedido.id }
          });

          const idsRecebidos = orc.informacoesAdicionais.map(info => info.id);
          const idsParaDeletar = pedidoInfosExistentes
            .filter(info => !idsRecebidos.includes(info.id))
            .map(info => info.id);

          if (idsParaDeletar.length > 0) {
            await tx.pedidoInformacaoAdicional.deleteMany({
              where: {
                id: { in: idsParaDeletar }
              }
            });
          }

          for (const info of orc.informacoesAdicionais) {
            const pedidoInfoExistente = pedidoInfosExistentes.find(pi => pi.id === info.id);

            const infoData = {
              data: info.data,
              descricao: info.descricao
            };

            if (pedidoInfoExistente) {
              const dataExistenteNormalizada = new Date(pedidoInfoExistente.data);
              dataExistenteNormalizada.setMilliseconds(0);
              dataExistenteNormalizada.setSeconds(0);
              
              const dataNovaNormalizada = new Date(infoData.data);
              dataNovaNormalizada.setMilliseconds(0);
              dataNovaNormalizada.setSeconds(0);
              
              const dataChanged = dataExistenteNormalizada.getTime() !== dataNovaNormalizada.getTime();
              const descricaoChanged = pedidoInfoExistente.descricao.trim() !== infoData.descricao.trim();
              
              if (dataChanged || descricaoChanged) {
                await tx.pedidoInformacaoAdicional.update({
                  where: { id: pedidoInfoExistente.id },
                  data: {
                    ...infoData,
                    createdAt: pedidoInfoExistente.createdAt,
                    updatedAt: new Date()
                  }
                });
              }
            } else {
              const createData = {
                ...infoData,
                pedidoId: orcamentoAtual.pedido.id
              };

              if (info.createdAt) {
                createData.createdAt = info.createdAt;
              }

              if (info.updatedAt) {
                createData.updatedAt = info.updatedAt;
              }

              await tx.pedidoInformacaoAdicional.create({
                data: createData
              });
            }
          }
        }

        return orc;
      });

      await logService.registrar({
        usuarioId: user?.id || 1,
        usuarioNome: user?.nome || 'Sistema',
        acao: 'EDITAR',
        entidade: 'ORCAMENTO',
        entidadeId: id,
        descricao: `Editou o orçamento "#${orcamentoAtualizado.numero}"${orcamentoAtual.pedido ? ' e o pedido foi atualizado' : ''}${ehRascunho ? ' (rascunho)' : ' (finalizado)'}`,
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
          informacoesAdicionais: {
            orderBy: {
              data: 'desc'
            }
          },
          pedido: true
        }
      });

      if (!orcamento) {
        throw new Error('Orçamento não encontrado');
      }

      if (orcamento.status === 'Aprovado' && user.role !== 'admin') {
        throw new Error('Apenas administradores podem alterar o status de orçamentos aprovados');
      }

      if (status === 'Aprovado' && orcamento.rascunho) {
        throw new Error('Não é possível aprovar um orçamento não finalizado.');
      }

      if (!['Pendente', 'Aprovado', 'Não Aprovado'].includes(status)) {
        throw new Error('Status inválido');
      }

      if (status === 'Aprovado' && !orcamento.pedido) {
        const pedidoData = {
          cliente: orcamento.cliente,
          numero: null,
          status: 'Pendente',
          produtoId: orcamento.produtoId,
          formaPagamento: orcamento.formaPagamento,
          condicoesPagamento: orcamento.condicoesPagamento,
          prazoEntrega: orcamento.prazoEntrega,
          orcamentoId: orcamento.id,
        };

        if(orcamento.materiais && orcamento.materiais.length > 0) {
          pedidoData.materiais = {
            create: orcamento.materiais.map(m => {
              const mat = {
                materialId: m.materialId,
                quantidade: m.quantidade,
                custo: m.custo,
              };
              if (m.alturaSobra !== null && m.alturaSobra !== undefined) mat.alturaSobra = m.alturaSobra;
              if (m.larguraSobra !== null && m.larguraSobra !== undefined) mat.larguraSobra = m.larguraSobra;
              if (m.valorSobra !== null && m.valorSobra !== undefined) mat.valorSobra = m.valorSobra;
              return mat;
            })
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

        if (orcamento.informacoesAdicionais && orcamento.informacoesAdicionais.length > 0) {
          pedidoData.informacoesAdicionais = {
            create: orcamento.informacoesAdicionais.map(i => ({
              data: i.data,
              descricao: i.descricao,
              createdAt: i.createdAt,
              updatedAt: i.updatedAt || i.createdAt
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
              },
              informacoesAdicionais: {
                orderBy: {
                  data: 'desc'
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
              },
              informacoesAdicionais: {
                orderBy: {
                  data: 'desc'
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
              opcoesExtrasTransferidas: pedidoCriado.opcoesExtras?.length || 0,
              informacoesAdicionaisTransferidas: pedidoCriado.informacoesAdicionais?.length || 0
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
          },
          informacoesAdicionais: {
            orderBy: {
              data: 'desc'
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
          opcoesExtras: { include: { produtoOpcao: true } },
          informacoesAdicionais: true
        }
      });

      if (!orcamento) {
        throw new Error('Orçamento não encontrado');
      }

      if (user.role !== 'admin') {
        throw new Error('Apenas administradores podem excluir orçamentos');
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

      await prisma.orcamentoInformacaoAdicional.deleteMany({
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
        descricao: `Excluiu o orçamento "#${orcamento.numero}"${orcamento.rascunho ? ' (rascunho)' : ''}`,
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