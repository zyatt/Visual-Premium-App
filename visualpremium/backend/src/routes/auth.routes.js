const { Router } = require('express');
const AuthController = require('../controllers/auth.controller');

const router = Router();

router.post('/login', AuthController.login);
router.get('/verify', AuthController.verificarSessao);

module.exports = router;