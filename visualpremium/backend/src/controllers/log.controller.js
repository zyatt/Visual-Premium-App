const LogService = require('../services/log.service');

class LogController {
  async listar(req, res) {
    try {
        const { page, limit, entidade, usuarioId, acao } = req.query;

        const resultado = await LogService.listar({
        page: page ? parseInt(page) : 1,
        limit: limit ? parseInt(limit) : 50,
        entidade,
        usuarioId,
        acao,
        });

        return res.json(resultado);
    } catch (error) {
        return res.status(500).json({ 
        error: 'Erro ao listar logs',
        details: error.message 
        });
    }
    }
}

module.exports = new LogController();