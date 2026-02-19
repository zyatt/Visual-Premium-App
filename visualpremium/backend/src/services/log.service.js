const prisma = require('../config/prisma');

class LogService {
  /**
   * @param {Object} params
   * @param {number} params.usuarioId
   * @param {string} params.usuarioNome
   * @param {string} params.acao
   * @param {string} params.entidade
   * @param {number} params.entidadeId
   * @param {string} params.descricao
   * @param {Object} params.detalhes
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
    }
  }

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

  async deletar(id) {
    try {
      await prisma.log.delete({
        where: { id: parseInt(id) },
      });
    } catch (error) {
      throw error;
    }
  }

  async deletarTodos() {
    try {
      const result = await prisma.log.deleteMany({});
      return { count: result.count };
    } catch (error) {
      throw error;
    }
  }
}

module.exports = new LogService();