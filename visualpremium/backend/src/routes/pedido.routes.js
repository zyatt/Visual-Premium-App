const { Router } = require('express');
const PedidoController = require('../controllers/pedido.controller');
const { authMiddleware } = require('../middlewares/auth.middleware');
const router = Router();

router.get('/', authMiddleware, PedidoController.listar);
router.get('/:id', authMiddleware, PedidoController.buscarPorId);
router.put('/:id', authMiddleware, PedidoController.atualizar);
router.patch('/:id/status', authMiddleware, PedidoController.atualizarStatus);
router.delete('/:id', authMiddleware, PedidoController.deletar);

module.exports = router;