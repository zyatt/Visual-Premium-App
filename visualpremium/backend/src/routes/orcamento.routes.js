const { Router } = require('express');
const OrcamentoController = require('../controllers/orcamento.controller');

const router = Router();

router.get('/', OrcamentoController.listar);
router.get('/produtos', OrcamentoController.listarProdutos);
router.get('/:id', OrcamentoController.buscarPorId);
router.post('/', OrcamentoController.criar);
router.put('/:id', OrcamentoController.atualizar);
router.patch('/:id/status', OrcamentoController.atualizarStatus);
router.delete('/:id', OrcamentoController.deletar);

module.exports = router;