const impostoSobraService = require('../services/impostoSobra.service');

class ImpostoSobraController {
  async obter(req, res) {
    try {
      const config = await impostoSobraService.obter();
      return res.status(200).json(config);
    } catch (error) {
      console.error('Erro ao buscar configuração de imposto:', error);
      return res.status(500).json({ 
        error: 'Erro ao buscar configuração',
        message: error.message 
      });
    }
  }

  async atualizar(req, res) {
    try {
      const config = await impostoSobraService.atualizar(req.body, req.user);
      return res.status(200).json(config);
    } catch (error) {
      const isValidationError = 
        error.message.includes('obrigatório') ||
        error.message.includes('inválido') ||
        error.message.includes('deve estar');

      if (!isValidationError) {
        console.error('Erro ao atualizar configuração de imposto:', error);
      }

      if (isValidationError) {
        return res.status(400).json({ 
          error: error.message,
          message: error.message 
        });
      }
      
      return res.status(500).json({ 
        error: 'Erro ao atualizar configuração',
        message: error.message 
      });
    }
  }
}

module.exports = new ImpostoSobraController();