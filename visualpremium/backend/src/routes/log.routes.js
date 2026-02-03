const { Router } = require('express');
const LogController = require('../controllers/log.controller');
const { authMiddleware } = require('../middlewares/auth.middleware');

const router = Router();

router.get('/', authMiddleware, LogController.listar);

module.exports = router;