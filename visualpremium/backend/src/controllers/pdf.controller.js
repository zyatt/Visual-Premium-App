const pdfService = require('../services/pdf.service');
const orcamentoService = require('../services/orcamento.service');

class PdfController {
  async gerarOrcamentoPdf(req, res) {
    try {
      const { id } = req.params;
      
      const orcamento = await orcamentoService.buscarPorId(+id);
      
      if (!orcamento) {
        return res.status(404).json({ error: 'Orçamento não encontrado' });
      }
      
      const totalMateriais = orcamento.materiais.reduce((sum, mat) => {
        const qty = parseFloat(mat.quantidade.toString().replace(',', '.'));
        return sum + (qty * mat.material.custo);
      }, 0);
      
      let totalGeral = totalMateriais;
      
      if (orcamento.despesasAdicionais && orcamento.despesasAdicionais.length > 0) {
        totalGeral += orcamento.despesasAdicionais.reduce((sum, despesa) => sum + despesa.valor, 0);
      }
      
      if (orcamento.frete && orcamento.freteValor) {
        totalGeral += orcamento.freteValor;
      }
      
      if (orcamento.caminhaoMunck && orcamento.caminhaoMunckHoras && orcamento.caminhaoMunckValorHora) {
        totalGeral += orcamento.caminhaoMunckHoras * orcamento.caminhaoMunckValorHora;
      }
      
      const dadosPdf = {
        numero: orcamento.numero,
        cliente: orcamento.cliente,
        produtoNome: orcamento.produto.nome,
        formaPagamento: orcamento.formaPagamento,
        condicoesPagamento: orcamento.condicoesPagamento,
        prazoEntrega: orcamento.prazoEntrega,
        materiais: orcamento.materiais.map(m => ({
          materialNome: m.material.nome,
          materialUnidade: m.material.unidade,
          materialCusto: m.material.custo,
          quantidade: m.quantidade
        })),
        despesasAdicionais: orcamento.despesasAdicionais && orcamento.despesasAdicionais.length > 0
          ? orcamento.despesasAdicionais.map(d => ({
              descricao: d.descricao,
              valor: d.valor
            }))
          : [],
        total: totalGeral,
        createdAt: orcamento.createdAt,
        
        frete: orcamento.frete || false,
        freteDesc: orcamento.freteDesc,
        freteValor: orcamento.freteValor,
        
        caminhaoMunck: orcamento.caminhaoMunck || false,
        caminhaoMunckHoras: orcamento.caminhaoMunckHoras,
        caminhaoMunckValorHora: orcamento.caminhaoMunckValorHora
      };
      
      const pdfStream = pdfService.gerarDocumento(dadosPdf, 'orcamento');
      
      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader(
        'Content-Disposition', 
        `attachment; filename=orcamento-${orcamento.numero}.pdf`
      );
      
      pdfStream.pipe(res);
      
    } catch (e) {
      console.error('Erro ao gerar PDF:', e);
      res.status(500).json({ error: 'Erro ao gerar PDF: ' + e.message });
    }
  }
  
  async gerarPedidoPdf(req, res) {
    try {
      const { id } = req.params;
      
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