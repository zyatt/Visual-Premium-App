const logService = require('../services/log.service');

class LogController {
  async listar(req, res) {
    try {
      const { page, limit, entidade, usuarioId, acao } = req.query;
      
      const result = await logService.listar({
        page: page ? parseInt(page) : 1,
        limit: limit ? parseInt(limit) : 50,
        entidade,
        usuarioId,
        acao,
      });

      return res.json(result);
    } catch (error) {
      return res.status(500).json({ error: 'Erro ao listar logs' });
    }
  }
}

module.exports = new LogController();