const prisma = require('../config/prisma');
const logService = require('./log.service');

class FaixaCustoMarkupService {
  async listar() {
    return prisma.faixaCustoMarkup.findMany({
      orderBy: { ordem: 'asc' }
    });
  }

  async criar(data, user) {
    const { custoAte, markup } = data;
    
    if (markup == null || markup < 0) {
      throw new Error('Markup deve ser maior ou igual a zero');
    }
    
    if (custoAte != null && custoAte <= 0) {
      throw new Error('Custo deve ser maior que zero');
    }

    const faixas = await this.listar();
    const ordem = faixas.length + 1;

    const faixa = await prisma.faixaCustoMarkup.create({
      data: {
        custoAte: custoAte || null,
        markup: parseFloat(markup),
        ordem
      }
    });

    await logService.registrar({
      usuarioId: user?.id || 1,
      usuarioNome: user?.nome || 'Sistema',
      acao: 'CRIAR',
      entidade: 'FAIXA_CUSTO_MARKUP',
      entidadeId: faixa.id,
      descricao: `Criou faixa de custo e markup`,
      detalhes: faixa,
    });

    return faixa;
  }

  async atualizar(id, data, user) {
    const { custoAte, markup } = data;
    
    if (markup == null || markup < 0) {
      throw new Error('Markup deve ser maior ou igual a zero');
    }
    
    if (custoAte != null && custoAte <= 0) {
      throw new Error('Custo deve ser maior que zero');
    }

    const faixaAtual = await prisma.faixaCustoMarkup.findUnique({
      where: { id }
    });

    if (!faixaAtual) {
      throw new Error('Faixa não encontrada');
    }

    const faixa = await prisma.faixaCustoMarkup.update({
      where: { id },
      data: {
        custoAte: custoAte || null,
        markup: parseFloat(markup)
      }
    });

    await logService.registrar({
      usuarioId: user?.id || 1,
      usuarioNome: user?.nome || 'Sistema',
      acao: 'EDITAR',
      entidade: 'FAIXA_CUSTO_MARKUP',
      entidadeId: id,
      descricao: `Editou faixa de custo e markup`,
      detalhes: { antes: faixaAtual, depois: faixa },
    });

    return faixa;
  }

  async deletar(id, user) {
    const faixa = await prisma.faixaCustoMarkup.findUnique({
      where: { id }
    });

    if (!faixa) {
      throw new Error('Faixa não encontrada');
    }

    await prisma.faixaCustoMarkup.delete({
      where: { id }
    });

    const faixas = await prisma.faixaCustoMarkup.findMany({
      orderBy: { ordem: 'asc' }
    });

    for (let i = 0; i < faixas.length; i++) {
      await prisma.faixaCustoMarkup.update({
        where: { id: faixas[i].id },
        data: { ordem: i + 1 }
      });
    }

    await logService.registrar({
      usuarioId: user?.id || 1,
      usuarioNome: user?.nome || 'Sistema',
      acao: 'DELETAR',
      entidade: 'FAIXA_CUSTO_MARKUP',
      entidadeId: id,
      descricao: `Excluiu faixa de custo e markup`,
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
    
    for (const faixa of faixas) {
      if (faixa.custoAte === null) {
        faixaAplicavel = faixa;
        break;
      } else if (custoTotal <= faixa.custoAte) {
        faixaAplicavel = faixa;
        break;
      }
    }

    if (!faixaAplicavel) {
      return null;
    }

    const valorSugerido = custoTotal * (1 + faixaAplicavel.markup / 100);
    
    return {
      custoTotal,
      markup: faixaAplicavel.markup,
      valorSugerido,
      faixaId: faixaAplicavel.id
    };
  }
}

module.exports = new FaixaCustoMarkupService();