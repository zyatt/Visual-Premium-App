const { Router } = require('express');
const ChatController = require('../controllers/chat.controller');
const { authMiddleware } = require('../middlewares/auth.middleware');

const router = Router();

router.post('/mensagens', authMiddleware, ChatController.enviarMensagem);
router.get('/conversas', authMiddleware, ChatController.listarConversas);
router.get('/mensagens/:usuarioId', authMiddleware, ChatController.listarMensagens);
router.get('/nao-lidas', authMiddleware, ChatController.contarNaoLidas);
router.patch('/mensagens/:id/lida', authMiddleware, ChatController.marcarComoLida);

module.exports = router;