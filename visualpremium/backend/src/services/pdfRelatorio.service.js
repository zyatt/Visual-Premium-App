const almoxarifadoService = require('./almoxarifado.service');
const pdfRelatorioLayout = require('../pdf/pdfRelatorio.layout');

class PdfRelatorioService {
  async gerarRelatorioPdf(id) {
    const relatorio = await almoxarifadoService.buscarRelatorioPorId(id);
    
    if (!relatorio) {
      throw new Error('Relatório não encontrado');
    }
    
    if (!relatorio.almoxarifado || !relatorio.almoxarifado.pedido) {
      throw new Error('Dados do relatório incompletos');
    }
    
    const dadosPdf = this._prepararDadosRelatorio(relatorio);
    
    try {
      const pdfStream = pdfRelatorioLayout.gerarDocumento(dadosPdf);
      
      return {
        pdfStream,
        numeroPedido: relatorio.almoxarifado?.pedido?.numero || 'S/N'
      };
    } catch (error) {
      throw new Error('Falha ao gerar documento PDF');
    }
  }

  async gerarRelatorioPdfPorAlmoxarifado(almoxarifadoId) {
    const relatorio = await almoxarifadoService.buscarRelatorioPorAlmoxarifadoId(almoxarifadoId);
    
    if (!relatorio) {
      throw new Error('Relatório não encontrado para este almoxarifado');
    }
    
    if (!relatorio.almoxarifado || !relatorio.almoxarifado.pedido) {
      throw new Error('Dados do relatório incompletos');
    }
    
    const dadosPdf = this._prepararDadosRelatorio(relatorio);
    
    try {
      const pdfStream = pdfRelatorioLayout.gerarDocumento(dadosPdf);
      
      return {
        pdfStream,
        numeroPedido: relatorio.almoxarifado?.pedido?.numero || 'S/N'
      };
    } catch (error) {
      throw new Error('Falha ao gerar documento PDF');
    }
  }
  
  _prepararDadosRelatorio(relatorio) {
    const almoxarifado = relatorio.almoxarifado;
    const pedido = almoxarifado?.pedido;
    const analise = relatorio.analiseDetalhada || {};
    
    return {
      numeroPedido: pedido?.numero || 'S/N',
      cliente: pedido?.cliente || 'N/A',
      produtoNome: pedido?.produto?.nome || 'N/A',
      totalOrcado: relatorio.totalOrcado || 0,
      totalRealizado: relatorio.totalRealizado || 0,
      diferencaTotal: relatorio.diferencaTotal || 0,
      percentualTotal: relatorio.percentualTotal || 0,
      materiais: this._formatarMateriais(analise.materiais || []),
      materiaisAvulsos: this._formatarMateriaisAvulsos(analise.materiaisAvulsos || []),
      despesas: this._formatarDespesas(analise.despesas || []),
      opcoesExtras: this._formatarOpcoesExtras(analise.opcoesExtras || []),
      createdAt: relatorio.createdAt
    };
  }
  
  _formatarMateriais(materiais) {
    return materiais.map(m => ({
      materialNome: m.materialNome || 'N/A',
      valorOrcado: m.valorOrcado || 0,
      custoRealizadoTotal: m.custoRealizadoTotal || 0,
      diferenca: m.diferenca || 0,
      percentual: m.percentual || 0,
      status: m.status || 'igual',
      custoSobrasRealizado: m.custoSobrasRealizado != null ? m.custoSobrasRealizado : null,
      valorSobraOrcado: m.valorSobraOrcado != null ? m.valorSobraOrcado : null,
    }));
  }
  
  _formatarMateriaisAvulsos(materiaisAvulsos) {
    return materiaisAvulsos.map(m => ({
      materialNome: m.materialNome || 'N/A',
      unidade: m.unidade || '',
      quantidade: m.quantidade || 0,
      custoRealizado: m.custoRealizado || 0,
    }));
  }
  
  _formatarDespesas(despesas) {
    return despesas.map(d => ({
      descricao: d.descricao || 'N/A',
      valorOrcado: d.valorOrcado || 0,
      valorRealizado: d.valorRealizado || 0,
      diferenca: d.diferenca || 0,
      percentual: d.percentual || 0,
      status: d.status || 'igual'
    }));
  }
  
  _formatarOpcoesExtras(opcoesExtras) {
    return opcoesExtras
      .filter(o => o.valorOrcado !== 0 || o.valorRealizado !== 0)
      .map(o => ({
        nome: o.nome || 'N/A',
        valorOrcado: o.valorOrcado || 0,
        valorRealizado: o.valorRealizado || 0,
        diferenca: o.diferenca || 0,
        percentual: o.percentual || 0,
        status: o.status || 'igual'
      }));
  }
}

module.exports = new PdfRelatorioService();