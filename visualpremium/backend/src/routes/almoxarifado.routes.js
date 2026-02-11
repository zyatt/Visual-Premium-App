const { Router } = require('express');
const AlmoxarifadoController = require('../controllers/almoxarifado.controller');
const { authMiddleware } = require('../middlewares/auth.middleware');

const router = Router();

router.get('/', authMiddleware, AlmoxarifadoController.listar);
router.get('/:id', authMiddleware, AlmoxarifadoController.buscarPorId);
router.get('/orcamento/:orcamentoId', authMiddleware, AlmoxarifadoController.buscarPorOrcamento);
router.post('/orcamento/:orcamentoId', authMiddleware, AlmoxarifadoController.salvar);
router.post('/orcamento/:orcamentoId/finalizar', authMiddleware, AlmoxarifadoController.finalizar);

router.get('/relatorios/listar', authMiddleware, AlmoxarifadoController.listarRelatorios);
router.get('/relatorios/:id', authMiddleware, AlmoxarifadoController.buscarRelatorioPorId);

module.exports = router;