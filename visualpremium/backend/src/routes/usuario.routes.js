const { Router } = require('express');
const UsuarioController = require('../controllers/usuario.controller');
const { authMiddleware } = require('../middlewares/auth.middleware');
const { adminOnly } = require('../middlewares/role.middleware'); // ✅ NOVO

const router = Router();

router.get('/', authMiddleware, adminOnly, UsuarioController.listar);
router.get('/:id', authMiddleware, adminOnly, UsuarioController.buscarPorId);
router.post('/', authMiddleware, adminOnly, UsuarioController.criar);
router.put('/:id', authMiddleware, adminOnly, UsuarioController.atualizar);
router.delete('/:id', authMiddleware, adminOnly, UsuarioController.deletar);

module.exports = router;