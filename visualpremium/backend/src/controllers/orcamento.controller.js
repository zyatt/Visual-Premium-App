const orcamentoService = require('../services/orcamento.service');

class OrcamentoController {
  async listar(req, res) {
    try {
      const orcamentos = await orcamentoService.listar();
      return res.status(200).json(orcamentos);
    } catch (error) {
      console.error('Erro ao listar orçamentos:', error);
      return res.status(500).json({ 
        error: 'Erro ao listar orçamentos',
        message: error.message 
      });
    }
  }

  async buscarPorId(req, res) {
    try {
      const { id } = req.params;
      const orcamento = await orcamentoService.buscarPorId(parseInt(id));
      return res.status(200).json(orcamento);
    } catch (error) {
      console.error('Erro ao buscar orçamento:', error);
      if (error.message === 'Orçamento não encontrado') {
        return res.status(404).json({ 
          error: 'Orçamento não encontrado',
          message: error.message 
        });
      }
      return res.status(500).json({ 
        error: 'Erro ao buscar orçamento',
        message: error.message 
      });
    }
  }

  async criar(req, res) {
    try {
      const orcamento = await orcamentoService.criar(req.body, req.user);
      return res.status(201).json(orcamento);
    } catch (error) {
      console.error('Erro ao criar orçamento:', error);
      
      if (
        error.message.includes('obrigatório') ||
        error.message.includes('inválid') ||
        error.message.includes('não encontrado') ||
        error.message.includes('não pertence') ||
        error.message.includes('já existe')
      ) {
        return res.status(400).json({ 
          error: error.message,
          message: error.message 
        });
      }
      
      return res.status(500).json({ 
        error: 'Erro ao criar orçamento',
        message: error.message 
      });
    }
  }

  async atualizar(req, res) {
    try {
      const { id } = req.params;
      const orcamento = await orcamentoService.atualizar(parseInt(id), req.body, req.user);
      return res.status(200).json(orcamento);
    } catch (error) {
      console.error('Erro ao atualizar orçamento:', error);
      
      if (error.message === 'Orçamento não encontrado') {
        return res.status(404).json({ 
          error: 'Orçamento não encontrado',
          message: error.message 
        });
      }
      
      if (
        error.message.includes('obrigatório') ||
        error.message.includes('inválid') ||
        error.message.includes('não encontrado') ||
        error.message.includes('não pertence')
      ) {
        return res.status(400).json({ 
          error: error.message,
          message: error.message 
        });
      }
      
      return res.status(500).json({ 
        error: 'Erro ao atualizar orçamento',
        message: error.message 
      });
    }
  }

  async atualizarStatus(req, res) {
    try {
      const { id } = req.params;
      const { status } = req.body;
      
      if (!status) {
        return res.status(400).json({ 
          error: 'Status é obrigatório',
          message: 'Status é obrigatório' 
        });
      }
      
      const orcamento = await orcamentoService.atualizarStatus(
        parseInt(id), 
        status, 
        req.user
      );
      
      return res.status(200).json(orcamento);
    } catch (error) {
      console.error('Erro ao atualizar status:', error);
      
      if (error.message === 'Orçamento não encontrado') {
        return res.status(404).json({ 
          error: 'Orçamento não encontrado',
          message: error.message 
        });
      }
      
      if (error.message.includes('inválid')) {
        return res.status(400).json({ 
          error: error.message,
          message: error.message 
        });
      }
      
      return res.status(500).json({ 
        error: 'Erro ao atualizar status',
        message: error.message 
      });
    }
  }

  async deletar(req, res) {
    try {
      const { id } = req.params;
      await orcamentoService.deletar(parseInt(id), req.user);
      return res.status(200).json({ 
        message: 'Orçamento excluído com sucesso' 
      });
    } catch (error) {
      console.error('Erro ao deletar orçamento:', error);
      
      if (error.message === 'Orçamento não encontrado') {
        return res.status(404).json({ 
          error: 'Orçamento não encontrado',
          message: error.message 
        });
      }
      
      return res.status(500).json({ 
        error: 'Erro ao deletar orçamento',
        message: error.message 
      });
    }
  }

  async listarProdutos(req, res) {
    try {
      const produtos = await orcamentoService.listarProdutos();
      return res.status(200).json(produtos);
    } catch (error) {
      console.error('Erro ao listar produtos:', error);
      return res.status(500).json({ 
        error: 'Erro ao listar produtos',
        message: error.message 
      });
    }
  }
}

module.exports = new OrcamentoController();