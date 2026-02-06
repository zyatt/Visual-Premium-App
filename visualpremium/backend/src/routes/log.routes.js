const { Router } = require('express');
const LogController = require('../controllers/log.controller');
const { authMiddleware } = require('../middlewares/auth.middleware');
const { adminOnly } = require('../middlewares/role.middleware');

const router = Router();

router.get('/', authMiddleware, adminOnly, LogController.listar);

module.exports = router;