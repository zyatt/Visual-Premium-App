const prisma = require('../config/prisma');
const logService = require('./log.service');

class FaixaCustoMargemService {
  async listar() {
    return prisma.faixaCustoMargem.findMany({
      orderBy: { ordem: 'asc' }
    });
  }

  async criar(data, user) {
    const { custoInicio, custoFim, margem } = data;
    
    if (margem == null || margem < 0) {
      throw new Error('Margem deve ser maior ou igual a 0');
    }
    
    if (custoInicio == null || custoInicio < 0) {
      throw new Error('Custo inicial deve ser maior ou igual a zero');
    }
    
    if (custoFim != null && custoFim <= custoInicio) {
      throw new Error('Custo final deve ser maior que o custo inicial');
    }

    // Validar sobreposição de faixas
    const faixas = await this.listar();
    for (const faixa of faixas) {
      const faixaInicio = faixa.custoInicio;
      const faixaFim = faixa.custoFim;
      
      // Verifica se há sobreposição
      if (custoFim === null) {
        // Nova faixa sem fim (infinito)
        if (faixaFim === null || custoInicio <= faixaFim) {
          throw new Error('Esta faixa sobrepõe uma faixa existente');
        }
      } else {
        // Nova faixa com fim definido
        if (faixaFim === null) {
          // Faixa existente sem fim
          if (custoFim >= faixaInicio) {
            throw new Error('Esta faixa sobrepõe uma faixa existente');
          }
        } else {
          // Ambas têm fim definido
          if (!(custoFim < faixaInicio || custoInicio > faixaFim)) {
            throw new Error('Esta faixa sobrepõe uma faixa existente');
          }
        }
      }
    }

    const ordem = faixas.length + 1;

    const faixa = await prisma.faixaCustoMargem.create({
      data: {
        custoInicio: parseFloat(custoInicio),
        custoFim: custoFim ? parseFloat(custoFim) : null,
        margem: parseFloat(margem),
        ordem
      }
    });

    await logService.registrar({
      usuarioId: user?.id || 1,
      usuarioNome: user?.nome || 'Sistema',
      acao: 'CRIAR',
      entidade: 'FAIXA_CUSTO_MARGEM',
      entidadeId: faixa.id,
      descricao: `Criou faixa de custo e margem`,
      detalhes: faixa,
    });

    return faixa;
  }

  async atualizar(id, data, user) {
    const { custoInicio, custoFim, margem } = data;
    
    if (margem == null || margem < 0) {
      throw new Error('Margem deve ser maior ou igual a 0');
    }
    
    if (custoInicio == null || custoInicio < 0) {
      throw new Error('Custo inicial deve ser maior ou igual a zero');
    }
    
    if (custoFim != null && custoFim <= custoInicio) {
      throw new Error('Custo final deve ser maior que o custo inicial');
    }

    const faixaAtual = await prisma.faixaCustoMargem.findUnique({
      where: { id }
    });

    if (!faixaAtual) {
      throw new Error('Faixa não encontrada');
    }

    // Validar sobreposição com outras faixas (exceto a atual)
    const faixas = await this.listar();
    for (const faixa of faixas) {
      if (faixa.id === id) continue; // Ignora a faixa sendo editada
      
      const faixaInicio = faixa.custoInicio;
      const faixaFim = faixa.custoFim;
      
      // Verifica se há sobreposição
      if (custoFim === null) {
        if (faixaFim === null || custoInicio <= faixaFim) {
          throw new Error('Esta faixa sobrepõe uma faixa existente');
        }
      } else {
        if (faixaFim === null) {
          if (custoFim >= faixaInicio) {
            throw new Error('Esta faixa sobrepõe uma faixa existente');
          }
        } else {
          if (!(custoFim < faixaInicio || custoInicio > faixaFim)) {
            throw new Error('Esta faixa sobrepõe uma faixa existente');
          }
        }
      }
    }

    const faixa = await prisma.faixaCustoMargem.update({
      where: { id },
      data: {
        custoInicio: parseFloat(custoInicio),
        custoFim: custoFim ? parseFloat(custoFim) : null,
        margem: parseFloat(margem)
      }
    });

    await logService.registrar({
      usuarioId: user?.id || 1,
      usuarioNome: user?.nome || 'Sistema',
      acao: 'EDITAR',
      entidade: 'FAIXA_CUSTO_MARGEM',
      entidadeId: id,
      descricao: `Editou faixa de custo e margem`,
      detalhes: { antes: faixaAtual, depois: faixa },
    });

    return faixa;
  }

  async deletar(id, user) {
    const faixa = await prisma.faixaCustoMargem.findUnique({
      where: { id }
    });

    if (!faixa) {
      throw new Error('Faixa não encontrada');
    }

    await prisma.faixaCustoMargem.delete({
      where: { id }
    });

    const faixas = await prisma.faixaCustoMargem.findMany({
      orderBy: { ordem: 'asc' }
    });

    for (let i = 0; i < faixas.length; i++) {
      await prisma.faixaCustoMargem.update({
        where: { id: faixas[i].id },
        data: { ordem: i + 1 }
      });
    }

    await logService.registrar({
      usuarioId: user?.id || 1,
      usuarioNome: user?.nome || 'Sistema',
      acao: 'DELETAR',
      entidade: 'FAIXA_CUSTO_MARGEM',
      entidadeId: id,
      descricao: `Excluiu faixa de custo e margem`,
      detalhes: faixa,
    });

    return faixa;
  }

  async calcularValorSugerido(custoTotal) {
    const faixas = await this.listar();
    
    if (faixas.length === 0) {
      return null;
    }

    let faixaAplicavel = null;
    
    // Procura a faixa que contém o custo total
    // Usa >= para início e < para fim (exceto quando fim é null)
    for (const faixa of faixas) {
      const dentroDoInicio = custoTotal >= faixa.custoInicio;
      const dentroDoFim = faixa.custoFim === null || custoTotal <= faixa.custoFim;

      if (dentroDoInicio && dentroDoFim) {
        faixaAplicavel = faixa;
        break;
      }
    }

    if (!faixaAplicavel) {
      return null;
    }

    // Cálculo com MARKUP (margem sobre custo): preço = custo × (1 + margem/100)
    // Exemplo: custo R$ 100, margem 400% → preço = 100 × (1 + 4) = 100 × 5 = R$ 500
    const valorSugerido = custoTotal * (1 + faixaAplicavel.margem / 100);
    
    return {
      custoTotal,
      margem: faixaAplicavel.margem,
      valorSugerido,
      faixaId: faixaAplicavel.id,
      custoInicio: faixaAplicavel.custoInicio,
      custoFim: faixaAplicavel.custoFim
    };
  }
}

module.exports = new FaixaCustoMargemService();