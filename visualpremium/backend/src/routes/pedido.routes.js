const { Router } = require('express');
const controller = require('../controllers/pedido.controller');

const router = Router();

router.get('/', controller.listar);
router.post('/', controller.criar);
router.put('/:id', controller.atualizar);
router.delete('/:id', controller.deletar);

module.exports = router;
