const { Router } = require('express');
const FaixaCustoMarkupController = require('../controllers/faixaCustoMarkup.controller');
const { authMiddleware } = require('../middlewares/auth.middleware');
const router = Router();

router.get('/', authMiddleware, FaixaCustoMarkupController.listar);
router.post('/', authMiddleware, FaixaCustoMarkupController.criar);
router.post('/calcular', authMiddleware, FaixaCustoMarkupController.calcularValorSugerido);
router.put('/:id', authMiddleware, FaixaCustoMarkupController.atualizar);
router.delete('/:id', authMiddleware, FaixaCustoMarkupController.deletar);

module.exports = router;