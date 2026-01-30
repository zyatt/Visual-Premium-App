const service = require('../services/material.service');

class MaterialController {
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
      .then(res.json.bind(res))
      .catch(e => res.status(400).json(e));
  }
}

module.exports = new MaterialController();