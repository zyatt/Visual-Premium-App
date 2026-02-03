const LogService = require('../services/log.service');

class LogController {
  async listar(req, res) {
    try {
        console.log('📥 Recebendo requisição de logs:', req.query);
        
        const { page, limit, entidade, usuarioId, acao } = req.query;

        const resultado = await LogService.listar({
        page: page ? parseInt(page) : 1,
        limit: limit ? parseInt(limit) : 50,
        entidade,
        usuarioId,
        acao,
        });

        console.log('✅ Logs carregados:', resultado.logs.length, 'registros');
        return res.json(resultado);
    } catch (error) {
        console.error('❌ Erro ao listar logs:', error);
        return res.status(500).json({ 
        error: 'Erro ao listar logs',
        details: error.message 
        });
    }
    }
}

module.exports = new LogController();