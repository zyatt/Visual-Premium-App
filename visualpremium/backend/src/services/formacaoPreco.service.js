const prisma = require('../config/prisma');

class FormacaoPrecoService {
  /**
   * 1º - Calcular Custo do Minuto Produtivo (Cm)
   * Fórmula: Cm = ((Fp/Qf) / 176) / 60
   */
  async calcularCustoMinutoProdutivo() {
    const funcionarios = await prisma.folhaPagamento.findMany();
    
    if (funcionarios.length === 0) {
      return 0;
    }

    const fp = funcionarios.reduce((sum, f) => sum + f.totalComEncargos, 0);
    const qf = funcionarios.reduce((sum, f) => sum + f.quantidade, 0);
    
    if (qf === 0) {
      return 0;
    }

    // Cm = ((Fp/Qf) / 176) / 60
    // 176 = total de horas no mês
    // 60 = conversão para minutos
    const cm = ((fp / qf) / 176) / 60;
    
    return cm;
  }

  /**
   * 2º - Calcular Custo de Mão de Obra Produtiva
   * Fórmula: Custo MOP = Tempo_Produtivo * Cm
   */
  async calcularCustoMaoObra(tempoProdutivoMinutos) {
    const cm = await this.calcularCustoMinutoProdutivo();
    return tempoProdutivoMinutos * cm;
  }

  /**
   * 3º - Calcular Percentual sobre Custos Fixos (P)
   * Duas fórmulas:
   * - Sem colaboradores produtivos: P = (C × 100) / F
   * - Com colaboradores produtivos: P = ((C - CP) × 100) / F
   */
  async calcularPercentualCustoFixo() {
    const config = await prisma.configuracaoPreco.findFirst();
    
    if (!config) {
      throw new Error('Configuração de preço não encontrada. Configure em Configurações Avançadas.');
    }

    const { faturamentoMedio, custoOperacional, custoProdutivo } = config;
    
    if (faturamentoMedio === 0) {
      throw new Error('Faturamento médio não pode ser zero. Configure em Configurações Avançadas.');
    }

    let percentual;
    
    if (custoProdutivo && custoProdutivo > 0) {
      // Com colaboradores produtivos
      percentual = ((custoOperacional - custoProdutivo) * 100) / faturamentoMedio;
    } else {
      // Sem colaboradores produtivos
      percentual = (custoOperacional * 100) / faturamentoMedio;
    }
    
    return percentual / 100; // Retornar em decimal (ex: 0.1186 para 11.86%)
  }

  /**
   * 4º - Calcular Percentual sobre Venda (Pv)
   * Pv = Comissão + Impostos + Juros
   * Padrão: 5% + 12% + 2% = 19%
   */
  async calcularPercentualSobreVenda() {
    const config = await prisma.configuracaoPreco.findFirst();
    
    if (!config) {
      return 0.19; // Default: 19%
    }

    const { percentualComissao, percentualImpostos, percentualJuros } = config;
    
    const pv = (percentualComissao + percentualImpostos + percentualJuros) / 100;
    
    return pv;
  }

  /**
   * 5º - Calcular Vmm (Valor Matéria + Minuto)
   * Vmm = Custo_Materiais + Custo_MOP + Custo_Despesas + Custo_Opcoes_Extras
   */
  async calcularVmm(dados) {
    const {
      materiais,
      despesasAdicionais,
      opcoesExtras,
      tempoProdutivoMinutos = 0
    } = dados;

    let vmm = 0;

    // Somar materiais
    if (materiais && materiais.length > 0) {
      vmm += materiais.reduce((sum, m) => sum + (m.custo * m.quantidade), 0);
    }

    // Somar despesas adicionais (exceto __NAO_SELECIONADO__)
    if (despesasAdicionais && despesasAdicionais.length > 0) {
      vmm += despesasAdicionais
        .filter(d => d.descricao !== '__NAO_SELECIONADO__')
        .reduce((sum, d) => sum + d.valor, 0);
    }

    // Somar opções extras (exceto __NAO_SELECIONADO__ e PERCENTFLOAT)
    if (opcoesExtras && opcoesExtras.length > 0) {
      for (const opcao of opcoesExtras) {
        // Pular opções não selecionadas
        if (opcao.valorString === '__NAO_SELECIONADO__') {
          continue;
        }

        const produtoOpcao = await prisma.produtoOpcaoExtra.findUnique({
          where: { id: opcao.produtoOpcaoId }
        });

        if (!produtoOpcao) continue;

        // PERCENTFLOAT não entra no Vmm (é aplicado depois)
        if (produtoOpcao.tipo === 'PERCENTFLOAT') {
          continue;
        }

        if (produtoOpcao.tipo === 'STRINGFLOAT') {
          vmm += opcao.valorFloat1 || 0;
        } else if (produtoOpcao.tipo === 'FLOATFLOAT') {
          vmm += (opcao.valorFloat1 || 0) * (opcao.valorFloat2 || 0);
        }
      }
    }

    // Adicionar custo de mão de obra produtiva
    const custoMaoObra = await this.calcularCustoMaoObra(tempoProdutivoMinutos);
    vmm += custoMaoObra;

    return {
      vmm,
      custoMaoObra
    };
  }

  /**
   * 6º - Calcular Vb (Valor Base)
   * Fórmula: Vb = (Vmm / (1 - P)) + Vmm
   */
  async calcularVb(vmm) {
    const percentualCustoFixo = await this.calcularPercentualCustoFixo();
    const vb = (vmm / (1 - percentualCustoFixo)) + vmm;
    return vb;
  }

  /**
   * 7º - Calcular Vam (Valor antes Markup)
   * Fórmula: Vam = Vb / (1 - Pv)
   */
  async calcularVam(vb) {
    const pv = await this.calcularPercentualSobreVenda();
    const vam = vb / (1 - pv);
    return vam;
  }

  /**
   * 8º - Calcular Vm (Valor com Markup)
   * Fórmula: Vm = Vam * Pm
   */
  calcularVm(vam, percentualMarkup) {
    const pm = percentualMarkup / 100; // Converter para decimal
    const vm = vam * pm;
    return vm;
  }

  /**
   * 9º - Aplicar Pv sobre Vm
   * Fórmula: Vm_final = Vm / (1 - Pv)
   */
  async calcularVmFinal(vm) {
    const pv = await this.calcularPercentualSobreVenda();
    const vmFinal = vm / (1 - pv);
    return vmFinal;
  }

  /**
   * 10º - Calcular Vv (Valor Final de Venda)
   * Fórmula: Vv = Vam + Vm_final
   */
  calcularVv(vam, vmFinal) {
    return vam + vmFinal;
  }

  /**
   * CÁLCULO COMPLETO DE FORMAÇÃO DE PREÇO
   */
  async calcularFormacaoPrecoCompleta(dados) {
    try {
      const {
        materiais,
        despesasAdicionais,
        opcoesExtras,
        tempoProdutivoMinutos = 0,
        percentualMarkup = null // Se null, usa o padrão da config
      } = dados;

      // Obter configuração
      const config = await prisma.configuracaoPreco.findFirst();
      const markupAUsar = percentualMarkup !== null ? percentualMarkup : (config?.markupPadrao || 40);

      // 1. Calcular custos base
      const cm = await this.calcularCustoMinutoProdutivo();
      const { vmm, custoMaoObra } = await this.calcularVmm(dados);

      // 2. Calcular valores intermediários
      const percentualCustoFixo = await this.calcularPercentualCustoFixo();
      const vb = await this.calcularVb(vmm);
      const pv = await this.calcularPercentualSobreVenda();
      const vam = await this.calcularVam(vb);

      // 3. Calcular markup
      const vm = this.calcularVm(vam, markupAUsar);
      const vmFinal = await this.calcularVmFinal(vm);

      // 4. Calcular valor final
      const vv = this.calcularVv(vam, vmFinal);

      // 5. Aplicar opções PERCENTFLOAT sobre o Vmm
      let valorOpcoesPercentuais = 0;
      if (opcoesExtras && opcoesExtras.length > 0) {
        for (const opcao of opcoesExtras) {
          if (opcao.valorString === '__NAO_SELECIONADO__') continue;

          const produtoOpcao = await prisma.produtoOpcaoExtra.findUnique({
            where: { id: opcao.produtoOpcaoId }
          });

          if (produtoOpcao?.tipo === 'PERCENTFLOAT' && opcao.valorFloat1) {
            valorOpcoesPercentuais += (opcao.valorFloat1 / 100) * vmm;
          }
        }
      }

      const vvComPercentuais = vv + valorOpcoesPercentuais;

      return {
        // Dados de entrada
        custoMinutoProdutivo: cm,
        custoMaoObraProducao: custoMaoObra,
        tempoProdutivoMinutos,
        
        // Cálculos intermediários
        valorMateriaMinuto: vmm,
        percentualCustoFixo: percentualCustoFixo * 100, // Converter para %
        valorBase: vb,
        percentualSobreVenda: pv * 100, // Converter para %
        valorAntesMarkup: vam,
        
        // Markup
        percentualMarkup: markupAUsar,
        valorComMarkup: vm,
        
        // Resultado final
        valorFinalVenda: vvComPercentuais,
        valorOpcoesPercentuais,
        
        // Breakdown detalhado
        breakdown: {
          custoMateriais: materiais?.reduce((sum, m) => sum + (m.custo * m.quantidade), 0) || 0,
          custoDespesas: despesasAdicionais
            ?.filter(d => d.descricao !== '__NAO_SELECIONADO__')
            .reduce((sum, d) => sum + d.valor, 0) || 0,
          custoMaoObra,
          custoOpcoesExtras: vmm - custoMaoObra - 
            (materiais?.reduce((sum, m) => sum + (m.custo * m.quantidade), 0) || 0) -
            (despesasAdicionais?.filter(d => d.descricao !== '__NAO_SELECIONADO__')
              .reduce((sum, d) => sum + d.valor, 0) || 0),
          valorOpcoesPercentuais
        }
      };
    } catch (error) {
      console.error('Erro ao calcular formação de preço:', error);
      throw error;
    }
  }

  /**
   * Validação de margem líquida
   * Conforme a tabela da imagem 3
   */
  validarMargemLiquida(resultado) {
    const { valorFinalVenda, breakdown } = resultado;
    
    const custoTotal = 
      breakdown.custoMateriais +
      breakdown.custoDespesas +
      breakdown.custoMaoObra +
      breakdown.custoOpcoesExtras +
      breakdown.valorOpcoesPercentuais;

    const margemLiquida = valorFinalVenda - custoTotal;
    const percentualMargem = (margemLiquida / valorFinalVenda) * 100;

    return {
      valorVenda: valorFinalVenda,
      custoTotal,
      margemLiquida,
      percentualMargem,
      breakdown: {
        materiaPrima: breakdown.custoMateriais,
        maoObraProducao: breakdown.custoMaoObra,
        custoFixo: 0, // Calcular se necessário
        impostos: 0,  // Calcular se necessário
        comissao: 0   // Calcular se necessário
      }
    };
  }
}

module.exports = new FormacaoPrecoService();