const orcamentoService = require('./orcamento.service');
const pedidoService = require('./pedido.service');
const pdfLayout = require('../pdf/pdf.layout');

class PdfService {
  async gerarOrcamentoPdf(id) {
    const orcamento = await orcamentoService.buscarPorId(id);
    
    if (!orcamento) {
      throw new Error('Orçamento não encontrado');
    }
    
    const valorSugerido = await orcamentoService.calcularValorSugerido(orcamento);
    const dadosPdf = this._prepararDadosOrcamento(orcamento, valorSugerido);
    const pdfStream = pdfLayout.gerarDocumento(dadosPdf, 'orcamento');
    
    return {
      pdfStream,
      numero: orcamento.numero
    };
  }
  
  async gerarPedidoPdf(id) {
    const pedido = await pedidoService.buscarPorId(id);
    
    if (!pedido) {
      throw new Error('Pedido não encontrado');
    }
    
    const valorSugerido = await pedidoService.calcularValorSugerido(pedido);
    const dadosPdf = this._prepararDadosPedido(pedido, valorSugerido);
    const pdfStream = pdfLayout.gerarDocumento(dadosPdf, 'pedido');
    
    return {
      pdfStream,
      numero: pedido.numero || id
    };
  }
  
  _prepararDadosOrcamento(orcamento, valorSugerido) {
    const totalMateriais = this._calcularTotalMateriais(orcamento.materiais);
    const totalDespesas = this._calcularTotalDespesas(orcamento.despesasAdicionais);
    const totalOpcoes = this._calcularTotalOpcoes(orcamento.opcoesExtras);
    const totalSobras = this._calcularTotalSobras(orcamento.materiais);
    const totalGeral = totalMateriais + totalDespesas + totalOpcoes + totalSobras;
    
    return {
      numero: orcamento.numero,
      cliente: orcamento.cliente,
      produtoNome: orcamento.produto.nome,
      formaPagamento: orcamento.formaPagamento,
      condicoesPagamento: orcamento.condicoesPagamento,
      prazoEntrega: orcamento.prazoEntrega,
      materiais: this._formatarMateriais(orcamento.materiais),
      despesasAdicionais: this._formatarDespesas(orcamento.despesasAdicionais),
      opcoesExtras: this._formatarOpcoes(orcamento.opcoesExtras),
      total: totalGeral,
      totalSobras: totalSobras,
      createdAt: orcamento.createdAt,
      valorSugerido: valorSugerido
    };
  }
  
  _prepararDadosPedido(pedido, valorSugerido) {
    const totalMateriais = this._calcularTotalMateriais(pedido.materiais);
    const totalDespesas = this._calcularTotalDespesas(pedido.despesasAdicionais);
    const totalOpcoes = this._calcularTotalOpcoes(pedido.opcoesExtras);
    const totalSobras = this._calcularTotalSobras(pedido.materiais);
    const totalGeral = totalMateriais + totalDespesas + totalOpcoes + totalSobras;
    
    return {
      numero: pedido.numero || 'S/N',
      cliente: pedido.cliente,
      produtoNome: pedido.produto.nome,
      formaPagamento: pedido.formaPagamento,
      condicoesPagamento: pedido.condicoesPagamento,
      prazoEntrega: pedido.prazoEntrega,
      materiais: this._formatarMateriais(pedido.materiais),
      despesasAdicionais: this._formatarDespesas(pedido.despesasAdicionais),
      opcoesExtras: this._formatarOpcoes(pedido.opcoesExtras),
      total: totalGeral,
      totalSobras: totalSobras,
      createdAt: pedido.createdAt,
      valorSugerido: valorSugerido
    };
  }
  
  _calcularTotalMateriais(materiais) {
    return materiais.reduce((sum, mat) => {
      const qty = parseFloat(mat.quantidade.toString().replace(',', '.'));
      return sum + (qty * mat.material.custo);
    }, 0);
  }
  
  _calcularTotalSobras(materiais) {
    return materiais.reduce((sum, mat) => {
      const valorSobra = parseFloat(mat.valorSobra) || 0;
      return sum + valorSobra;
    }, 0);
  }
  
  _calcularTotalDespesas(despesas) {
    if (!despesas || despesas.length === 0) return 0;
    return despesas
      .filter(d => d.descricao !== '__NAO_SELECIONADO__')
      .reduce((sum, despesa) => sum + despesa.valor, 0);
  }
  
  _calcularTotalOpcoes(opcoes) {
    if (!opcoes || opcoes.length === 0) return 0;
    
    return opcoes.reduce((sum, opcao) => {
      if (opcao.valorString === '__NAO_SELECIONADO__') {
        return sum;
      }
      
      let valorOpcao = 0;
      
      const tipo = opcao.produtoOpcao?.tipo || opcao.tipo;
      
      if (tipo === 'STRINGFLOAT') {
        valorOpcao = parseFloat(opcao.valorFloat1) || 0;
      } else if (tipo === 'FLOATFLOAT') {
        const valor1 = parseFloat(opcao.valorFloat1) || 0;
        const valor2 = parseFloat(opcao.valorFloat2) || 0;
        valorOpcao = valor1 * valor2;
      } else if (tipo === 'PERCENTFLOAT') {
        const percentual = parseFloat(opcao.valorFloat1) || 0;
        const valorBase = parseFloat(opcao.valorFloat2) || 0;
        valorOpcao = (percentual / 100) * valorBase;
      }
      
      return sum + valorOpcao;
    }, 0);
  }
  
  _formatarMateriais(materiais) {
    return materiais.map(m => ({
      materialNome: m.material.nome,
      materialUnidade: m.material.unidade,
      materialCusto: m.material.custo,
      quantidade: m.quantidade,
      alturaSobra: m.alturaSobra || null,
      larguraSobra: m.larguraSobra || null,
      valorSobra: m.valorSobra || 0
    }));
  }
  
  _formatarDespesas(despesas) {
    if (!despesas || despesas.length === 0) return [];
    
    return despesas
      .filter(d => d.descricao !== '__NAO_SELECIONADO__')
      .map(d => ({
        descricao: d.descricao,
        valor: d.valor
      }));
  }
  
  _formatarOpcoes(opcoes) {
    if (!opcoes || opcoes.length === 0) return [];
    
    return opcoes
      .filter(o => o.valorString !== '__NAO_SELECIONADO__')
      .map(o => ({
        nome: o.produtoOpcao.nome,
        tipo: o.produtoOpcao.tipo,
        valorString: o.valorString,
        valorFloat1: o.valorFloat1,
        valorFloat2: o.valorFloat2
      }));
  }
}

module.exports = new PdfService();