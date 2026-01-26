const { Router } = require('express');
const PdfController = require('../controllers/pdf.controller');

const router = Router();

// Rota para gerar PDF de orçamento
router.get('/orcamento/:id', PdfController.gerarOrcamentoPdf);

// Rota para gerar PDF de pedido (futuro)
router.get('/pedido/:id', PdfController.gerarPedidoPdf);

module.exports = router;