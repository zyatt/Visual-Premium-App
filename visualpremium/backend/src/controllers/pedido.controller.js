const service = require('../services/pedido.service');

class PedidoController {
  async listar(req, res) {
    try {
      const pedidos = await service.listar();
      res.json(pedidos);
    } catch (e) {
      res.status(400).json({ error: e.message });
    }
  }

  async buscarPorId(req, res) {
    try {
      const pedido = await service.buscarPorId(+req.params.id, req.user);
      res.json(pedido);
    } catch (e) {
      res.status(404).json({ error: e.message });
    }
  }

  async atualizar(req, res) {
    try {
      const pedido = await service.atualizar(+req.params.id, req.body, req.user); // ✅ PASSAR req.user
      res.json(pedido);
    } catch (e) {
      res.status(400).json({ error: e.message });
    }
  }

  async atualizarStatus(req, res) {
    try {
      const { status } = req.body;
      const pedido = await service.atualizarStatus(+req.params.id, status, req.user); // ✅ PASSAR req.user
      res.json(pedido);
    } catch (e) {
      res.status(400).json({ error: e.message });
    }
  }

  async deletar(req, res) {
    try {
      await service.deletar(+req.params.id, req.user); // ✅ PASSAR req.user
      res.json({ message: 'Pedido deletado com sucesso' });
    } catch (e) {
      res.status(400).json({ error: e.message });
    }
  }
}

module.exports = new PedidoController();