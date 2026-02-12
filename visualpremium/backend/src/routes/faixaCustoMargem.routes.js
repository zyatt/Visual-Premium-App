const { Router } = require('express');
const FaixaCustoMargemController = require('../controllers/faixaCustoMargem.controller');
const { authMiddleware } = require('../middlewares/auth.middleware');
const router = Router();

router.get('/', authMiddleware, FaixaCustoMargemController.listar);
router.post('/', authMiddleware, FaixaCustoMargemController.criar);
router.post('/calcular', authMiddleware, FaixaCustoMargemController.calcularValorSugerido);
router.put('/:id', authMiddleware, FaixaCustoMargemController.atualizar);
router.delete('/:id', authMiddleware, FaixaCustoMargemController.deletar);

module.exports = router;