const pdfService = require('../services/pdf.service');

class PdfController {
  async gerarOrcamentoPdf(req, res) {
    try {
      const { id } = req.params;
      const { pdfStream, numero } = await pdfService.gerarOrcamentoPdf(+id);
      
      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader('Content-Disposition', `attachment; filename=orcamento-${numero}.pdf`);
      
      pdfStream.pipe(res);
    } catch (e) {
      const status = e.message === 'Orçamento não encontrado' ? 404 : 500;
      res.status(status).json({ error: e.message });
    }
  }
  
  async gerarPedidoPdf(req, res) {
    try {
      const { id } = req.params;
      const { pdfStream, numero } = await pdfService.gerarPedidoPdf(+id);
      
      const nomeArquivo = numero ? `pedido-${numero}.pdf` : `pedido-${id}.pdf`;
      
      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader('Content-Disposition', `attachment; filename=${nomeArquivo}`);
      
      pdfStream.pipe(res);
    } catch (e) {
      const status = e.message === 'Pedido não encontrado' ? 404 : 500;
      res.status(status).json({ error: e.message });
    }
  }
}

module.exports = new PdfController();