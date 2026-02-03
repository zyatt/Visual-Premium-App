const { Router } = require('express');
const controller = require('../controllers/material.controller');
const { authMiddleware } = require('../middlewares/auth.middleware');

const router = Router();

router.get('/', authMiddleware, controller.listar);
router.post('/', authMiddleware, controller.criar);
router.put('/:id', authMiddleware, controller.atualizar);
router.delete('/:id', authMiddleware, controller.deletar);

module.exports = router;