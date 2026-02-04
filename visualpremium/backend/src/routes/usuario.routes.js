const { Router } = require('express');
const UsuarioController = require('../controllers/usuario.controller');
const { authMiddleware } = require('../middlewares/auth.middleware');

const router = Router();

router.get('/', authMiddleware, UsuarioController.listar);
router.get('/:id', authMiddleware, UsuarioController.buscarPorId);
router.post('/', authMiddleware, UsuarioController.criar);
router.put('/:id', authMiddleware,  UsuarioController.atualizar);
router.delete('/:id', authMiddleware, UsuarioController.deletar);

module.exports = router;