const almoxarifadoService = require('../services/almoxarifado.service');

class AlmoxarifadoController {
  async listar(req, res) {
    try {
      const almoxarifados = await almoxarifadoService.listar();
      return res.status(200).json(almoxarifados);
    } catch (error) {
      console.error('Erro ao listar almoxarifados:', error);
      return res.status(500).json({ 
        error: 'Erro ao listar almoxarifados',
        message: error.message 
      });
    }
  }

  async buscarPorId(req, res) {
    try {
      const { id } = req.params;
      const almoxarifado = await almoxarifadoService.buscarPorId(parseInt(id));
      return res.status(200).json(almoxarifado);
    } catch (error) {
      console.error('Erro ao buscar almoxarifado:', error);
      if (error.message === 'Almoxarifado não encontrado') {
        return res.status(404).json({ 
          error: 'Almoxarifado não encontrado',
          message: error.message 
        });
      }
      return res.status(500).json({ 
        error: 'Erro ao buscar almoxarifado',
        message: error.message 
      });
    }
  }

  async buscarPorPedido(req, res) {
    try {
      const { pedidoId } = req.params;
      const almoxarifado = await almoxarifadoService.buscarPorPedido(parseInt(pedidoId));
      
      if (!almoxarifado) {
        return res.status(404).json({ 
          error: 'Almoxarifado não encontrado para este pedido',
          message: 'Almoxarifado não encontrado para este pedido'
        });
      }
      
      return res.status(200).json(almoxarifado);
    } catch (error) {
      console.error('Erro ao buscar almoxarifado por pedido:', error);
      return res.status(500).json({ 
        error: 'Erro ao buscar almoxarifado',
        message: error.message 
      });
    }
  }

  async salvar(req, res) {
    try {
      const { pedidoId } = req.params;
      const almoxarifado = await almoxarifadoService.salvar(
        parseInt(pedidoId),
        req.body,
        req.user
      );
      return res.status(200).json(almoxarifado);
    } catch (error) {
      console.error('Erro ao salvar almoxarifado:', error);
      
      if (
        error.message.includes('não encontrado') ||
        error.message.includes('não pertence') ||
        error.message.includes('inválido') ||
        error.message.includes('Apenas pedidos concluídos')
      ) {
        return res.status(400).json({ 
          error: error.message,
          message: error.message 
        });
      }
      
      return res.status(500).json({ 
        error: 'Erro ao salvar almoxarifado',
        message: error.message 
      });
    }
  }

  async finalizar(req, res) {
    try {
      const { pedidoId } = req.params;
      const resultado = await almoxarifadoService.finalizar(
        parseInt(pedidoId),
        req.user
      );
      return res.status(200).json(resultado);
    } catch (error) {
      console.error('Erro ao finalizar almoxarifado:', error);
      
      if (
        error.message === 'Almoxarifado não encontrado' ||
        error.message === 'Almoxarifado já finalizado'
      ) {
        return res.status(400).json({ 
          error: error.message,
          message: error.message 
        });
      }
      
      return res.status(500).json({ 
        error: 'Erro ao finalizar almoxarifado',
        message: error.message 
      });
    }
  }

  async listarRelatorios(req, res) {
    try {
      const relatorios = await almoxarifadoService.listarRelatorios();
      return res.status(200).json(relatorios);
    } catch (error) {
      console.error('Erro ao listar relatórios:', error);
      return res.status(500).json({ 
        error: 'Erro ao listar relatórios',
        message: error.message 
      });
    }
  }

  async buscarRelatorioPorId(req, res) {
    try {
      const { id } = req.params;
      const relatorio = await almoxarifadoService.buscarRelatorioPorId(parseInt(id));
      return res.status(200).json(relatorio);
    } catch (error) {
      console.error('Erro ao buscar relatório:', error);
      if (error.message === 'Relatório comparativo não encontrado') {
        return res.status(404).json({ 
          error: 'Relatório não encontrado',
          message: error.message 
        });
      }
      return res.status(500).json({ 
        error: 'Erro ao buscar relatório',
        message: error.message 
      });
    }
  }
}

module.exports = new AlmoxarifadoController();