const pdfService = require('../services/pdf.service');
const orcamentoService = require('../services/orcamento.service');
const pedidoService = require('../services/pedido.service');

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
      
      const pedido = await pedidoService.buscarPorId(+id);
      
      if (!pedido) {
        return res.status(404).json({ error: 'Pedido não encontrado' });
      }
      
      // Calcular total dos materiais
      const totalMateriais = pedido.materiais.reduce((sum, mat) => {
        const qty = parseFloat(mat.quantidade.toString().replace(',', '.'));
        return sum + (qty * mat.material.custo);
      }, 0);
      
      // Calcular total geral
      let totalGeral = totalMateriais;
      
      if (pedido.despesasAdicionais && pedido.despesasAdicionais.length > 0) {
        totalGeral += pedido.despesasAdicionais.reduce((sum, despesa) => sum + despesa.valor, 0);
      }
      
      if (pedido.frete && pedido.freteValor) {
        totalGeral += pedido.freteValor;
      }
      
      if (pedido.caminhaoMunck && pedido.caminhaoMunckHoras && pedido.caminhaoMunckValorHora) {
        totalGeral += pedido.caminhaoMunckHoras * pedido.caminhaoMunckValorHora;
      }
      
      // Preparar dados para o PDF
      const dadosPdf = {
        numero: pedido.numero || 'S/N', // Se não tiver número, mostra "S/N"
        cliente: pedido.cliente,
        produtoNome: pedido.produto.nome,
        formaPagamento: pedido.formaPagamento,
        condicoesPagamento: pedido.condicoesPagamento,
        prazoEntrega: pedido.prazoEntrega,
        materiais: pedido.materiais.map(m => ({
          materialNome: m.material.nome,
          materialUnidade: m.material.unidade,
          materialCusto: m.material.custo,
          quantidade: m.quantidade
        })),
        despesasAdicionais: pedido.despesasAdicionais && pedido.despesasAdicionais.length > 0
          ? pedido.despesasAdicionais.map(d => ({
              descricao: d.descricao,
              valor: d.valor
            }))
          : [],
        total: totalGeral,
        createdAt: pedido.createdAt,
        
        frete: pedido.frete || false,
        freteDesc: pedido.freteDesc,
        freteValor: pedido.freteValor,
        
        caminhaoMunck: pedido.caminhaoMunck || false,
        caminhaoMunckHoras: pedido.caminhaoMunckHoras,
        caminhaoMunckValorHora: pedido.caminhaoMunckValorHora
      };
      
      // Gerar PDF com tipo 'pedido'
      const pdfStream = pdfService.gerarDocumento(dadosPdf, 'pedido');
      
      // Configurar headers da resposta
      res.setHeader('Content-Type', 'application/pdf');
      
      // Nome do arquivo: se tiver número usa, senão usa o ID
      const nomeArquivo = pedido.numero 
        ? `pedido-${pedido.numero}.pdf` 
        : `pedido-${pedido.id}.pdf`;
      
      res.setHeader(
        'Content-Disposition', 
        `attachment; filename=${nomeArquivo}`
      );
      
      // Enviar o PDF
      pdfStream.pipe(res);
      
    } catch (e) {
      console.error('Erro ao gerar PDF do pedido:', e);
      res.status(500).json({ error: 'Erro ao gerar PDF: ' + e.message });
    }
  }
}

module.exports = new PdfController();