const { Router } = require('express');
const ImpostoSobraController = require('../controllers/impostoSobra.controller');
const { authMiddleware} = require('../middlewares/auth.middleware');

const router = Router();

router.get('/', authMiddleware, ImpostoSobraController.obter);
router.put('/', authMiddleware, ImpostoSobraController.atualizar);

module.exports = router;