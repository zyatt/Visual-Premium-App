const { Router } = require('express');

const orcamentoRoutes = require('./orcamento.routes');
const pedidoRoutes = require('./pedido.routes');
const produtoRoutes = require('./produto.routes');
const materialRoutes = require('./material.routes');

const routes = Router();

routes.use('/orcamentos', orcamentoRoutes);
routes.use('/pedidos', pedidoRoutes);
routes.use('/produtos', produtoRoutes);
routes.use('/materiais', materialRoutes);

module.exports = routes;
