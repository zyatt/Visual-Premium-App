const { Router } = require('express');
const OrcamentoController = require('../controllers/orcamento.controller');
const { authMiddleware } = require('../middlewares/auth.middleware');

const router = Router();

router.get('/', authMiddleware, OrcamentoController.listar);
router.get('/produtos', authMiddleware, OrcamentoController.listarProdutos);
router.get('/:id', authMiddleware, OrcamentoController.buscarPorId);
router.post('/', authMiddleware, OrcamentoController.criar);
router.put('/:id', authMiddleware, OrcamentoController.atualizar);
router.patch('/:id/status', authMiddleware, OrcamentoController.atualizarStatus);
router.delete('/:id', authMiddleware, OrcamentoController.deletar);

module.exports = router;