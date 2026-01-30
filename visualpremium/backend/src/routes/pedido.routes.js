const { Router } = require('express');
const PedidoController = require('../controllers/pedido.controller');

const router = Router();

router.get('/', PedidoController.listar);
router.get('/:id', PedidoController.buscarPorId);
router.put('/:id', PedidoController.atualizar);
router.patch('/:id/status', PedidoController.atualizarStatus);
router.delete('/:id', PedidoController.deletar);

module.exports = router;