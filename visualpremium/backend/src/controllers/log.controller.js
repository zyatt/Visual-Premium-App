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

  async deletar(req, res) {
    try {
      const { id } = req.params;
      await logService.deletar(id);
      return res.status(204).send();
    } catch (error) {
      return res.status(500).json({ error: 'Erro ao deletar log' });
    }
  }

  async deletarTodos(req, res) {
    try {
      const result = await logService.deletarTodos();
      return res.json({ message: `${result.count} logs deletados com sucesso` });
    } catch (error) {
      return res.status(500).json({ error: 'Erro ao deletar todos os logs' });
    }
  }
}

module.exports = new LogController();