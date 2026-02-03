const { Router } = require('express');
const LogController = require('../controllers/log.controller');

const router = Router();

router.get('/', LogController.listar);

module.exports = router;