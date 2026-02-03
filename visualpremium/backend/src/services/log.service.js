const prisma = require('../config/prisma');

class LogService {
  /**
   * Registra uma ação no sistema
   * @param {Object} params
   * @param {number} params.usuarioId - ID do usuário que executou a ação
   * @param {string} params.usuarioNome - Nome do usuário
   * @param {string} params.acao - Tipo de ação (CRIAR, EDITAR, DELETAR)
   * @param {string} params.entidade - Tipo de entidade (MATERIAL, PRODUTO, etc)
   * @param {number} params.entidadeId - ID da entidade afetada
   * @param {string} params.descricao - Descrição da ação
   * @param {Object} params.detalhes - Detalhes adicionais (opcional)
   */
  async registrar({ usuarioId, usuarioNome, acao, entidade, entidadeId, descricao, detalhes }) {
    try {
      await prisma.log.create({
        data: {
          usuarioId,
          usuarioNome,
          acao,
          entidade,
          entidadeId,
          descricao,
          detalhes: detalhes || null,
        },
      });
    } catch (error) {
      // Não lança erro para não interromper a operação principal
    }
  }

  /**
   * Lista logs com filtros e paginação
   */
  async listar({ page = 1, limit = 50, entidade, usuarioId, acao }) {
    try {
        
        const skip = (page - 1) * limit;
        
        const where = {};
        if (entidade) where.entidade = entidade;
        if (usuarioId) where.usuarioId = parseInt(usuarioId);
        if (acao) where.acao = acao;

        const [logs, total] = await Promise.all([
        prisma.log.findMany({
            where,
            orderBy: { createdAt: 'desc' },
            skip,
            take: limit,
        }),
        prisma.log.count({ where }),
        ]);

        return {
        logs,
        total,
        page,
        totalPages: Math.ceil(total / limit),
        };
    } catch (error) {
        throw error;
    }
    }
}

module.exports = new LogService();