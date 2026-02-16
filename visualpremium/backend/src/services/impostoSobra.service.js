const prisma = require('../config/prisma');
const logService = require('./log.service');

class ImpostoSobraService {
  async obter() {
    let config = await prisma.configuracaoImpostoSobra.findFirst();
    
    if (!config) {
      // Criar configuração padrão se não existir
      config = await prisma.configuracaoImpostoSobra.create({
        data: {
          percentualImposto: 18.0,
        },
      });
    }
    
    return config;
  }

  async atualizar(data, user) {
    const { percentualImposto } = data;

    if (percentualImposto === undefined || percentualImposto === null) {
      throw new Error('Percentual de imposto é obrigatório');
    }

    const percentualNum = parseFloat(percentualImposto);
    
    if (isNaN(percentualNum)) {
      throw new Error('Percentual de imposto inválido');
    }

    if (percentualNum < 0 || percentualNum > 100) {
      throw new Error('Percentual de imposto deve estar entre 0 e 100');
    }

    // Buscar configuração existente
    let config = await prisma.configuracaoImpostoSobra.findFirst();
    
    const configAntiga = config ? { ...config } : null;

    if (config) {
      // Atualizar existente
      config = await prisma.configuracaoImpostoSobra.update({
        where: { id: config.id },
        data: {
          percentualImposto: percentualNum,
        },
      });
    } else {
      // Criar nova
      config = await prisma.configuracaoImpostoSobra.create({
        data: {
          percentualImposto: percentualNum,
        },
      });
    }

    await logService.registrar({
      usuarioId: user?.id || 1,
      usuarioNome: user?.nome || 'Sistema',
      acao: configAntiga ? 'EDITAR' : 'CRIAR',
      entidade: 'CONFIGURACAO_IMPOSTO_SOBRA',
      entidadeId: config.id,
      descricao: `${configAntiga ? 'Atualizou' : 'Criou'} configuração de imposto sobre sobras para ${percentualNum}%`,
      detalhes: {
        antes: configAntiga,
        depois: config,
      },
    });

    return config;
  }

  /**
   * Calcula o valor da sobra aplicando o percentual de imposto
   * @param {number} valorSobraBruto - Valor da sobra sem impostos
   * @returns {Promise<number>} - Valor da sobra com impostos aplicados
   */
  async calcularValorSobraComImposto(valorSobraBruto) {
    const config = await this.obter();
    const percentualImposto = config.percentualImposto;
    
    // Fórmula: valorSobra / (1 - (percentualImposto/100))
    // Exemplo: 18% -> 100 - 18 = 82 -> 0.82
    const divisor = (100 - percentualImposto) / 100;
    
    if (divisor <= 0) {
      throw new Error('Percentual de imposto inválido para cálculo');
    }
    
    return valorSobraBruto / divisor;
  }
}

module.exports = new ImpostoSobraService();