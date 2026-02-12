const { Router } = require('express');

const orcamentoRoutes = require('./orcamento.routes');
const pedidoRoutes = require('./pedido.routes');
const produtoRoutes = require('./produto.routes');
const materialRoutes = require('./material.routes');
const pdfRoutes = require('./pdf.routes');
const pdfRelatorioRoutes = require('./pdfRelatorio.routes');
const usuarioRoutes = require('./usuario.routes');
const authRoutes = require('./auth.routes');
const logRoutes = require('./log.routes');
const almoxarifadoRoutes = require('./almoxarifado.routes');
const faixaCustoMargemRoutes = require('./faixaCustoMargem.routes');

const routes = Router();

routes.use('/orcamentos', orcamentoRoutes);
routes.use('/pedidos', pedidoRoutes);
routes.use('/produtos', produtoRoutes);
routes.use('/materiais', materialRoutes);
routes.use('/pdf', pdfRoutes);
routes.use('/pdf', pdfRelatorioRoutes);
routes.use('/usuarios', usuarioRoutes);
routes.use('/auth', authRoutes);
routes.use('/logs', logRoutes);
routes.use('/almoxarifado', almoxarifadoRoutes);
routes.use('/faixas-custo-margem', faixaCustoMargemRoutes);

module.exports = routes;