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
      
      // Calcular total dos materiais
      const totalMateriais = orcamento.materiais.reduce((sum, mat) => {
        const qty = parseFloat(mat.quantidade.toString().replace(',', '.'));
        return sum + (qty * mat.material.custo);
      }, 0);
      
      let totalGeral = totalMateriais;
      
      // Adicionar despesas adicionais
      if (orcamento.despesasAdicionais && orcamento.despesasAdicionais.length > 0) {
        totalGeral += orcamento.despesasAdicionais.reduce((sum, despesa) => sum + despesa.valor, 0);
      }
      
      // Adicionar opções extras
      if (orcamento.opcoesExtras && orcamento.opcoesExtras.length > 0) {
        orcamento.opcoesExtras.forEach(opcao => {
          if (opcao.valorFloat1) totalGeral += opcao.valorFloat1;
          if (opcao.valorFloat2) totalGeral += opcao.valorFloat2;
        });
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
        opcoesExtras: orcamento.opcoesExtras && orcamento.opcoesExtras.length > 0
          ? orcamento.opcoesExtras.map(o => ({
              nome: o.produtoOpcao.nome,
              tipo: o.produtoOpcao.tipo,
              valorString: o.valorString,
              valorFloat1: o.valorFloat1,
              valorFloat2: o.valorFloat2
            }))
          : [],
        total: totalGeral,
        createdAt: orcamento.createdAt
      };
      
      const pdfStream = pdfService.gerarDocumento(dadosPdf, 'orcamento');
      
      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader(
        'Content-Disposition', 
        `attachment; filename=orcamento-${orcamento.numero}.pdf`
      );
      
      pdfStream.pipe(res);
      
    } catch (e) {
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
      
      // Adicionar despesas adicionais
      if (pedido.despesasAdicionais && pedido.despesasAdicionais.length > 0) {
        totalGeral += pedido.despesasAdicionais.reduce((sum, despesa) => sum + despesa.valor, 0);
      }
      
      // Adicionar opções extras
      if (pedido.opcoesExtras && pedido.opcoesExtras.length > 0) {
        pedido.opcoesExtras.forEach(opcao => {
          if (opcao.valorFloat1) totalGeral += opcao.valorFloat1;
          if (opcao.valorFloat2) totalGeral += opcao.valorFloat2;
        });
      }
      
      // Adicionar frete
      if (pedido.frete && pedido.freteValor) {
        totalGeral += pedido.freteValor;
      }
      
      // Adicionar caminhão munck
      let caminhaoMunckHorasConvertidas = 0;
      let caminhaoMunckTotal = 0;
      
      if (pedido.caminhaoMunck && pedido.caminhaoMunckHoras && pedido.caminhaoMunckValorHora) {
        caminhaoMunckHorasConvertidas = pedido.caminhaoMunckHoras / 60; // Converter minutos para horas
        caminhaoMunckTotal = caminhaoMunckHorasConvertidas * pedido.caminhaoMunckValorHora;
        totalGeral += caminhaoMunckTotal;
      }
      
      // Debug: verificar o valor do número
      console.log('📄 Gerando PDF do Pedido:', {
        id: pedido.id,
        numero: pedido.numero,
        tipoNumero: typeof pedido.numero,
        numeroFinal: pedido.numero || 'S/N'
      });
      
      // Preparar dados para o PDF
      const dadosPdf = {
        numero: pedido.numero || 'S/N',
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
        opcoesExtras: pedido.opcoesExtras && pedido.opcoesExtras.length > 0
          ? pedido.opcoesExtras.map(o => ({
              nome: o.produtoOpcao.nome,
              tipo: o.produtoOpcao.tipo,
              valorString: o.valorString,
              valorFloat1: o.valorFloat1,
              valorFloat2: o.valorFloat2
            }))
          : [],
        total: totalGeral,
        createdAt: pedido.createdAt,
        
        frete: pedido.frete || false,
        freteDesc: pedido.freteDesc,
        freteValor: pedido.freteValor,
        
        caminhaoMunck: pedido.caminhaoMunck || false,
        caminhaoMunckHoras: caminhaoMunckHorasConvertidas, // Agora em horas
        caminhaoMunckValorHora: pedido.caminhaoMunckValorHora,
        caminhaoMunckTotal: caminhaoMunckTotal // Total calculado
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
      res.status(500).json({ error: 'Erro ao gerar PDF: ' + e.message });
    }
  }
}

module.exports = new PdfController();