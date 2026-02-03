const { Router } = require('express');
const AuthController = require('../controllers/auth.controller');
const { authMiddleware } = require('../middlewares/auth.middleware');

const router = Router();

router.post('/login', AuthController.login);
router.get('/verify', authMiddleware, AuthController.verificarSessao);

module.exports = router;