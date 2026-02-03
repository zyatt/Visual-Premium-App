const service = require('../services/orcamento.service');

class OrcamentoController {
  async listar(req, res) {
    try {
      const orcamentos = await service.listar();
      res.json(orcamentos);
    } catch (e) {
      res.status(400).json({ error: e.message });
    }
  }

  async buscarPorId(req, res) {
    try {
      const orcamento = await service.buscarPorId(+req.params.id, req.user);
      res.json(orcamento);
    } catch (e) {
      res.status(404).json({ error: e.message });
    }
  }

  async criar(req, res) {
    try {
      const orcamento = await service.criar(req.body, req.user); // ✅ PASSAR req.user
      res.json(orcamento);
    } catch (e) {
      res.status(400).json({ error: e.message });
    }
  }

  async atualizar(req, res) {
    try {
      const orcamento = await service.atualizar(+req.params.id, req.body, req.user); // ✅ PASSAR req.user
      res.json(orcamento);
    } catch (e) {
      res.status(400).json({ error: e.message });
    }
  }

  async atualizarStatus(req, res) {
    try {
      const { status, produtoId, cliente, numero } = req.body;
      
      if (!status) {
        return res.status(400).json({ error: 'Status é obrigatório' });
      }
      
      const orcamento = await service.atualizarStatus(
        +req.params.id,
        status,
        { produtoId, cliente, numero },
        req.user // ✅ PASSAR req.user
      );
      
      res.json(orcamento);
    } catch (e) {
      res.status(400).json({ error: e.message });
    }
  }

  async deletar(req, res) {
    try {
      await service.deletar(+req.params.id, req.user); // ✅ PASSAR req.user
      res.json({ message: 'Orçamento deletado com sucesso' });
    } catch (e) {
      res.status(400).json({ error: e.message });
    }
  }

  async listarProdutos(req, res) {
    try {
      const produtos = await service.listarProdutos();
      res.json(produtos);
    } catch (e) {
      res.status(400).json({ error: e.message });
    }
  }
}

module.exports = new OrcamentoController();