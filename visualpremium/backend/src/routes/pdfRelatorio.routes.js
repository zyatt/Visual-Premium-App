const express = require('express');
const router = express.Router();
const pdfRelatorioController = require('../controllers/pdfRelatorio.controller');

router.get('/relatorio/almoxarifado/:almoxarifadoId', pdfRelatorioController.gerarRelatorioPorAlmoxarifado);

router.get('/relatorio/:id', pdfRelatorioController.gerarRelatorioPdf);

module.exports = router;