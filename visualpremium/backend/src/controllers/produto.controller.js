const service = require('../services/produto.service');

class ProdutoController {
  listar(req, res) {
    return service.listar().then(res.json.bind(res));
  }

  criar(req, res) {
    return service.criar(req.body)
      .then(res.json.bind(res))
      .catch(e => res.status(400).json({ error: e.message }));
  }

  atualizar(req, res) {
    return service.atualizar(+req.params.id, req.body)
      .then(res.json.bind(res))
      .catch(e => res.status(400).json({ error: e.message }));
  }

  deletar(req, res) {
    return service.deletar(+req.params.id)
      .then(() => res.json({ message: 'Produto deletado com sucesso' }))
      .catch(e => res.status(400).json({ error: e.message }));
  }
}

module.exports = new ProdutoController();
