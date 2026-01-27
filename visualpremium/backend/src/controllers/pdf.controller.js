const pdfService = require('../services/pdf.service');
const orcamentoService = require('../services/orcamento.service');

class PdfController {
  /**
   * Gera PDF de um orçamento
   */
  async gerarOrcamentoPdf(req, res) {
    try {
      const { id } = req.params;
      
      // Busca o orçamento completo
      const orcamento = await orcamentoService.buscarPorId(+id);
      
      if (!orcamento) {
        return res.status(404).json({ error: 'Orçamento não encontrado' });
      }
      
      // Calcula o total dos materiais
      const totalMateriais = orcamento.materiais.reduce((sum, mat) => {
        const qty = parseFloat(mat.quantidade.toString().replace(',', '.'));
        return sum + (qty * mat.material.custo);
      }, 0);
      
      // Calcula o total geral
      let totalGeral = totalMateriais;
      
      if (orcamento.despesaAdicional && orcamento.despesaAdicionalValor) {
        totalGeral += orcamento.despesaAdicionalValor;
      }
      
      if (orcamento.frete && orcamento.freteValor) {
        totalGeral += orcamento.freteValor;
      }
      
      if (orcamento.caminhaoMunck && orcamento.caminhaoMunckHoras && orcamento.caminhaoMunckValorHora) {
        totalGeral += orcamento.caminhaoMunckHoras * orcamento.caminhaoMunckValorHora;
      }
      
      // Prepara os dados para o PDF
      const dadosPdf = {
        numero: orcamento.numero,
        cliente: orcamento.cliente,
        produtoNome: orcamento.produto.nome,
        materiais: orcamento.materiais.map(m => ({
          materialNome: m.material.nome,
          materialUnidade: m.material.unidade,
          materialCusto: m.material.custo,
          quantidade: m.quantidade
        })),
        total: totalGeral,
        createdAt: orcamento.createdAt,
        
        // Informações adicionais
        despesaAdicional: orcamento.despesaAdicional || false,
        despesaAdicionalDesc: orcamento.despesaAdicionalDesc,
        despesaAdicionalValor: orcamento.despesaAdicionalValor,
        
        frete: orcamento.frete || false,
        freteDesc: orcamento.freteDesc,
        freteValor: orcamento.freteValor,
        
        caminhaoMunck: orcamento.caminhaoMunck || false,
        caminhaoMunckHoras: orcamento.caminhaoMunckHoras,
        caminhaoMunckValorHora: orcamento.caminhaoMunckValorHora
      };
      
      // Gera o PDF
      const pdfStream = pdfService.gerarDocumento(dadosPdf, 'orcamento');
      
      // Configura headers da resposta
      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader(
        'Content-Disposition', 
        `attachment; filename=orcamento-${orcamento.numero}.pdf`
      );
      
      // Envia o PDF
      pdfStream.pipe(res);
      
    } catch (e) {
      console.error('Erro ao gerar PDF:', e);
      res.status(500).json({ error: 'Erro ao gerar PDF: ' + e.message });
    }
  }
  
  /**
   * Gera PDF de um pedido (para implementação futura)
   */
  async gerarPedidoPdf(req, res) {
    try {
      const { id } = req.params;
      
      // TODO: Implementar busca de pedido quando a funcionalidade existir
      // const pedido = await pedidoService.buscarPorId(+id);
      
      return res.status(501).json({ 
        error: 'Funcionalidade de pedidos ainda não implementada' 
      });
      
    } catch (e) {
      console.error('Erro ao gerar PDF:', e);
      res.status(500).json({ error: 'Erro ao gerar PDF: ' + e.message });
    }
  }
}

module.exports = new PdfController();