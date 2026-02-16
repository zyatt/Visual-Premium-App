const { Router } = require('express');
const ConfiguracaoPrecoController = require('../controllers/configuracaoPreco.controller');
const { authMiddleware } = require('../middlewares/auth.middleware');

const router = Router();

// Configuração geral
router.get('/config', authMiddleware, ConfiguracaoPrecoController.obterConfig);
router.put('/config', authMiddleware, ConfiguracaoPrecoController.atualizarConfig);

// Folha de pagamento
router.get('/folha-pagamento', authMiddleware, ConfiguracaoPrecoController.listarFolhaPagamento);
router.post('/folha-pagamento', authMiddleware, ConfiguracaoPrecoController.criarFolhaPagamento);
router.put('/folha-pagamento/:id', authMiddleware, ConfiguracaoPrecoController.atualizarFolhaPagamento);
router.delete('/folha-pagamento/:id', authMiddleware, ConfiguracaoPrecoController.deletarFolhaPagamento);

// Cálculo de preview
router.post('/calcular-preview', authMiddleware, ConfiguracaoPrecoController.calcularPreview);

module.exports = router;