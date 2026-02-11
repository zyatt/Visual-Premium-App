const service = require('../services/faixaCustoMarkup.service');

class FaixaCustoMarkupController {
  async listar(req, res) {
    try {
      const faixas = await service.listar();
      res.json(faixas);
    } catch (e) {
      res.status(400).json({ error: e.message });
    }
  }

  async criar(req, res) {
    try {
      const faixa = await service.criar(req.body, req.user);
      res.status(201).json(faixa);
    } catch (e) {
      res.status(400).json({ error: e.message });
    }
  }

  async atualizar(req, res) {
    try {
      const faixa = await service.atualizar(+req.params.id, req.body, req.user);
      res.json(faixa);
    } catch (e) {
      res.status(400).json({ error: e.message });
    }
  }

  async deletar(req, res) {
    try {
      await service.deletar(+req.params.id, req.user);
      res.json({ message: 'Faixa deletada com sucesso' });
    } catch (e) {
      res.status(400).json({ error: e.message });
    }
  }

  async calcularValorSugerido(req, res) {
    try {
      const { custoTotal } = req.body;
      
      if (!custoTotal || custoTotal <= 0) {
        return res.status(400).json({ error: 'Custo total deve ser maior que zero' });
      }

      const resultado = await service.calcularValorSugerido(parseFloat(custoTotal));
      
      if (!resultado) {
        return res.status(404).json({ error: 'Nenhuma faixa de markup configurada' });
      }

      res.json(resultado);
    } catch (e) {
      res.status(400).json({ error: e.message });
    }
  }
}

module.exports = new FaixaCustoMarkupController();