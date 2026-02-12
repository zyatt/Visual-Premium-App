const { Router } = require('express');
const AlmoxarifadoController = require('../controllers/almoxarifado.controller');
const { authMiddleware } = require('../middlewares/auth.middleware');

const router = Router();

router.get('/', authMiddleware, AlmoxarifadoController.listar);
router.get('/:id', authMiddleware, AlmoxarifadoController.buscarPorId);
router.get('/pedido/:pedidoId', authMiddleware, AlmoxarifadoController.buscarPorPedido);
router.post('/pedido/:pedidoId', authMiddleware, AlmoxarifadoController.salvar);
router.post('/pedido/:pedidoId/finalizar', authMiddleware, AlmoxarifadoController.finalizar);

router.get('/relatorios/listar', authMiddleware, AlmoxarifadoController.listarRelatorios);
router.get('/relatorios/:id', authMiddleware, AlmoxarifadoController.buscarRelatorioPorId);

module.exports = router;