const service = require('../services/usuario.service');

class UsuarioController {
  listar(req, res) {
    return service.listar()
      .then(res.json.bind(res))
      .catch(() => res.status(500).json({ error: 'Erro ao listar usuários' }));
  }

  buscarPorId(req, res) {
    return service.buscarPorId(+req.params.id)
      .then(res.json.bind(res))
      .catch(e => res.status(404).json({ error: e.message }));
  }

  criar(req, res) {
    return service.criar(req.body, req.user)
      .then(usuario => res.status(201).json(usuario))
      .catch(e => res.status(400).json({ error: e.message }));
  }

  atualizar(req, res) {
    return service.atualizar(+req.params.id, req.body, req.user)
      .then(res.json.bind(res))
      .catch(e => res.status(400).json({ error: e.message }));
  }

  deletar(req, res) {
    return service.deletar(+req.params.id, req.user)
      .then(() => res.status(204).send())
      .catch(e => res.status(400).json({ error: e.message }));
  }
}

module.exports = new UsuarioController();
