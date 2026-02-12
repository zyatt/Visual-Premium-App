const pdfRelatorioService = require('../services/pdfRelatorio.service');

class PdfRelatorioController {
  async gerarRelatorioPdf(req, res) {
    try {
      const { id } = req.params;
      const { pdfStream, numeroPedido } = await pdfRelatorioService.gerarRelatorioPdf(+id);
      
      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader('Content-Disposition', `attachment; filename=relatorio-${numeroPedido}.pdf`);
      
      pdfStream.on('error', (error) => {
        console.error('Erro ao gerar PDF:', error);
        if (!res.headersSent) {
          res.status(500).json({ error: 'Erro ao gerar PDF' });
        }
      });
      
      pdfStream.on('end', () => {
        res.end();
      });
      
      pdfStream.pipe(res);
    } catch (e) {
      console.error('Erro no controller de PDF:', e);
      const status = e.message === 'Relatório não encontrado' ? 404 : 500;
      if (!res.headersSent) {
        res.status(status).json({ error: e.message });
      }
    }
  }

  async gerarRelatorioPorAlmoxarifado(req, res) {
    try {
      const { almoxarifadoId } = req.params;
      console.log('📄 Gerando PDF para almoxarifado ID:', almoxarifadoId);
      
      const { pdfStream, numeroPedido } = await pdfRelatorioService.gerarRelatorioPdfPorAlmoxarifado(+almoxarifadoId);
      
      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader('Content-Disposition', `attachment; filename=relatorio-${numeroPedido}.pdf`);
      
      pdfStream.on('error', (error) => {
        console.error('Erro ao gerar PDF:', error);
        if (!res.headersSent) {
          res.status(500).json({ error: 'Erro ao gerar PDF' });
        }
      });
      
      pdfStream.on('end', () => {
        res.end();
      });
      
      pdfStream.pipe(res);
    } catch (e) {
      console.error('Erro no controller de PDF:', e);
      const status = e.message.includes('não encontrado') ? 404 : 500;
      if (!res.headersSent) {
        res.status(status).json({ error: e.message });
      }
    }
  }
}

module.exports = new PdfRelatorioController();