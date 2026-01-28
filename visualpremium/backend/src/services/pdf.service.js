const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');

class PdfService {
  gerarDocumento(data, type = 'orcamento') {
    const doc = new PDFDocument({ margin: 40, size: 'A4' });

    const logoPath = path.join(__dirname, '../../../assets/images/logo preta.png');
    const titulo = type === 'orcamento' ? 'Orçamento' : 'Pedido';
    
    this._desenharHeader(doc, logoPath, data.numero, titulo);
    this._desenharInfoPrincipal(doc, data.cliente, data.produtoNome);
    this._desenharTabelaMateriais(doc, data.materiais);
    
    if (data.despesasAdicionais?.length > 0 || data.frete || data.caminhaoMunck) {
      this._desenharItensAdicionais(doc, data);
    }
    
    this._desenharResumo(doc, data);
    this._desenharFooter(doc);
    
    doc.end();
    return doc;
  }

  _desenharHeader(doc, logoPath, numero, titulo) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
       
    // Logo na esquerda
    if (fs.existsSync(logoPath)) {
      try {
        doc.image(logoPath, margin, 40, { width: 100, height: 50 });
      } catch (error) {
      }
    }
    
    // Calcular largura do número para centralizar
    const numeroStr = numero.toString();
    doc.fontSize(28).font('Helvetica-Bold');
    const numeroWidth = doc.widthOfString(numeroStr);
    
    // Posição à direita da página
    const rightMargin = pageWidth - margin;
    const numeroX = rightMargin - numeroWidth;
    
    // Texto "Orçamento" centralizado acima do número
    doc.fontSize(10)
       .font('Helvetica')
       .fillColor('#666666')
       .text(titulo, numeroX - 50, 40, { width: numeroWidth + 100, align: 'center' });
    
    // Número do orçamento (centralizado verticalmente entre texto e data)
    doc.fontSize(28)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text(numeroStr, numeroX, 58);
    
    // Data e hora centralizadas abaixo do número
    const now = new Date();
    const dataFormatada = now.toLocaleDateString('pt-BR');
    const horaFormatada = now.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
    
    doc.fontSize(8)
       .font('Helvetica')
       .fillColor('#666666')
       .text(`${dataFormatada} ${horaFormatada}`, numeroX - 50, 90, { width: numeroWidth + 100, align: 'center' });
    
    doc.moveTo(margin, 110)
       .lineTo(pageWidth - margin, 110)
       .strokeColor('#e0e0e0')
       .lineWidth(1)
       .stroke();
  }

  _desenharInfoPrincipal(doc, cliente, produto) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    let y = 120;
    
    const cardHeight = 60;
    const cardY = y;
    
    doc.roundedRect(margin, cardY, pageWidth - 2 * margin, cardHeight, 6)
       .fillColor('#f8f9fa')
       .fill();
    
    doc.rect(margin, cardY, 3, cardHeight)
       .fillColor('#1a1a1a')
       .fill();
    
    doc.fontSize(7)
       .font('Helvetica-Bold')
       .fillColor('#6b7280')
       .text('PRODUTO', margin + 15, cardY + 12);
    
    doc.fontSize(12)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text(produto, margin + 15, cardY + 23, { width: pageWidth - 2 * margin - 30 });
    
    doc.fontSize(7)
       .font('Helvetica-Bold')
       .fillColor('#6b7280')
       .text('CLIENTE', margin + 15, cardY + 40);
    
    doc.fontSize(9)
       .font('Helvetica')
       .fillColor('#374151')
       .text(cliente, margin + 15, cardY + 50, { width: pageWidth - 2 * margin - 30 });
  }

  _desenharTabelaMateriais(doc, materiais) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    let y = 195;
    
    doc.fontSize(10)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text('MATERIAIS', margin, y);
    
    y += 18;
    
    const tableWidth = pageWidth - 2 * margin;
    const colWidths = {
      material: tableWidth * 0.48,
      unidade: tableWidth * 0.10,
      quantidade: tableWidth * 0.14,
      valorUnit: tableWidth * 0.14,
      total: tableWidth * 0.14
    };
    
    doc.roundedRect(margin, y, tableWidth, 25, 5)
       .fillColor('#1a1a1a')
       .fill();
    
    doc.fontSize(7)
       .font('Helvetica-Bold')
       .fillColor('#ffffff');
    
    let x = margin + 12;
    doc.text('MATERIAL', x, y + 9, { width: colWidths.material - 20, align: 'left' });
    
    x += colWidths.material;
    doc.text('UN', x - 10, y + 9, { width: colWidths.unidade, align: 'center' });
    
    x += colWidths.unidade;
    doc.text('QUANTIDADE', x - 10, y + 9, { width: colWidths.quantidade, align: 'center' });
    
    x += colWidths.quantidade;
    doc.text('VL. UNITÁRIO', x - 10, y + 9, { width: colWidths.valorUnit, align: 'right' });
    
    x += colWidths.valorUnit;
    doc.text('TOTAL', x - 10, y + 9, { width: colWidths.total - 15, align: 'right' });
    
    y += 30;
    
    doc.fontSize(8)
       .font('Helvetica')
       .fillColor('#1f2937');
    
    materiais.forEach((material, index) => {
      const rowHeight = 22;
      
      if (index % 2 === 0) {
        doc.rect(margin, y, tableWidth, rowHeight)
           .fillColor('#f9fafb')
           .fill();
      }
      
      doc.moveTo(margin, y + rowHeight)
         .lineTo(pageWidth - margin, y + rowHeight)
         .strokeColor('#e5e7eb')
         .lineWidth(0.5)
         .stroke();
      
      x = margin + 12;
      const textY = y + 7;
      
      doc.fillColor('#1f2937')
         .font('Helvetica')
         .fontSize(8)
         .text(material.materialNome, x, textY, { 
           width: colWidths.material - 20, 
           align: 'left',
           lineBreak: false,
           ellipsis: true
         });
      
      x += colWidths.material;
      
      doc.fillColor('#6b7280')
         .fontSize(7)
         .text(material.materialUnidade, x - 10, textY, { width: colWidths.unidade, align: 'center' });
      
      x += colWidths.unidade;
      
      const quantidade = this._formatarQuantidade(material.quantidade, material.materialUnidade);
      doc.fillColor('#1f2937')
         .font('Helvetica-Bold')
         .fontSize(8)
         .text(quantidade, x - 10, textY, { width: colWidths.quantidade, align: 'center' });
      
      x += colWidths.quantidade;
      
      doc.fillColor('#6b7280')
         .font('Helvetica')
         .fontSize(7)
         .text(this._formatarMoeda(material.materialCusto), x - 10, textY, { width: colWidths.valorUnit, align: 'right' });
      
      x += colWidths.valorUnit;
      
      const totalItem = this._calcularTotalItem(material.quantidade, material.materialCusto);
      doc.fillColor('#1f2937')
         .font('Helvetica-Bold')
         .fontSize(8)
         .text(this._formatarMoeda(totalItem), x - 10, textY, { width: colWidths.total - 15, align: 'right' });
      
      y += rowHeight;
    });
    
    return y;
  }

  _desenharItensAdicionais(doc, data) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    let y = doc.y + 15;
    
    // Desenhar subtotal de materiais à direita
    let subtotal = 0;
    data.materiais.forEach(mat => {
      subtotal += this._calcularTotalItem(mat.quantidade, mat.materialCusto);
    });
    
    const subtotalTexto = 'Subtotal Materiais';
    doc.fontSize(8).font('Helvetica');
    const textoWidth = doc.widthOfString(subtotalTexto);
    const subtotalX = pageWidth - margin - textoWidth - 70;
    
    doc.fillColor('#6b7280')
       .text(subtotalTexto, subtotalX, y);
    
    doc.fontSize(9)
       .font('Helvetica-Bold')
       .fillColor('#374151')
       .text(this._formatarMoeda(subtotal), subtotalX + textoWidth + 10, y);
    
    y += 20;
    
    // Título das informações adicionais
    doc.fontSize(10)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text('INFORMAÇÕES ADICIONAIS', margin, y);
    
    y += 15;
    
    const fullBoxWidth = pageWidth - 2 * margin;
    
    // Despesas adicionais agrupadas
    if (data.despesasAdicionais && data.despesasAdicionais.length > 0) {
      const titulo = data.despesasAdicionais.length === 1 ? 'DESPESA ADICIONAL' : 'DESPESAS ADICIONAIS';
      const alturaBloco = 30 + (data.despesasAdicionais.length - 1) * 18;
      
      doc.roundedRect(margin, y, fullBoxWidth, alturaBloco, 5)
         .fillColor('#f5f5f5')
         .fill();
      
      doc.rect(margin, y, 3, alturaBloco)
         .fillColor('#666666')
         .fill();
      
      doc.fontSize(7)
         .font('Helvetica-Bold')
         .fillColor('#6b7280')
         .text(titulo, margin + 12, y + 8);
      
      let despesaY = y + 18;
      data.despesasAdicionais.forEach((despesa, index) => {
        doc.fontSize(9)
           .font('Helvetica')
           .fillColor('#1f2937')
           .text(despesa.descricao, margin + 12, despesaY, { width: fullBoxWidth - 150 });
        
        doc.fontSize(9)
           .font('Helvetica-Bold')
           .fillColor('#1a1a1a')
           .text(this._formatarMoeda(despesa.valor), pageWidth - margin - 120, despesaY, { 
             width: 110, 
             align: 'right' 
           });
        
        despesaY += 18;
      });
      
      y += alturaBloco + 5;
    }
    
    if (data.frete && data.freteDesc && data.freteValor) {
      doc.roundedRect(margin, y, fullBoxWidth, 30, 5)
         .fillColor('#f5f5f5')
         .fill();
      
      doc.rect(margin, y, 3, 30)
         .fillColor('#666666')
         .fill();
      
      doc.fontSize(7)
         .font('Helvetica-Bold')
         .fillColor('#6b7280')
         .text('FRETE', margin + 12, y + 8);
      
      doc.fontSize(9)
         .font('Helvetica')
         .fillColor('#1f2937')
         .text(data.freteDesc, margin + 12, y + 18, { width: fullBoxWidth - 150 });
      
      doc.fontSize(10)
         .font('Helvetica-Bold')
         .fillColor('#1a1a1a')
         .text(this._formatarMoeda(data.freteValor), pageWidth - margin - 120, y + 13, { 
           width: 110, 
           align: 'right' 
         });
      
      y += 35;
    }
    
    if (data.caminhaoMunck && data.caminhaoMunckHoras && data.caminhaoMunckValorHora) {
      const totalMunck = data.caminhaoMunckHoras * data.caminhaoMunckValorHora;
      
      doc.roundedRect(margin, y, fullBoxWidth, 30, 5)
         .fillColor('#f5f5f5')
         .fill();
      
      doc.rect(margin, y, 3, 30)
         .fillColor('#666666')
         .fill();
      
      doc.fontSize(7)
         .font('Helvetica-Bold')
         .fillColor('#6b7280')
         .text('CAMINHÃO MUNCK', margin + 12, y + 8);
      
      doc.fontSize(9)
         .font('Helvetica')
         .fillColor('#1f2937')
         .text(`${this._formatarQuantidade(data.caminhaoMunckHoras, 'h')} horas × ${this._formatarMoeda(data.caminhaoMunckValorHora)}/h`, 
                margin + 12, y + 18, { width: fullBoxWidth - 150 });
      
      doc.fontSize(10)
         .font('Helvetica-Bold')
         .fillColor('#1a1a1a')
         .text(this._formatarMoeda(totalMunck), pageWidth - margin - 120, y + 13, { 
           width: 110, 
           align: 'right' 
         });
      
      y += 35;
    }
  }

  _desenharResumo(doc, data) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    let y = doc.y + 15;
    
    const boxWidth = 230;
    const boxX = pageWidth - margin - boxWidth;
    
    let totalGeral = 0;
    
    // Calcular total dos materiais
    data.materiais.forEach(mat => {
      totalGeral += this._calcularTotalItem(mat.quantidade, mat.materialCusto);
    });
    
    // Adicionar despesas adicionais
    if (data.despesasAdicionais && data.despesasAdicionais.length > 0) {
      totalGeral += data.despesasAdicionais.reduce((sum, d) => sum + d.valor, 0);
    }
    
    // Adicionar frete
    if (data.freteValor) totalGeral += data.freteValor;
    
    // Adicionar caminhão munck
    if (data.caminhaoMunckHoras && data.caminhaoMunckValorHora) {
      totalGeral += data.caminhaoMunckHoras * data.caminhaoMunckValorHora;
    }
    
    // Linha separadora
    doc.moveTo(boxX, y)
       .lineTo(pageWidth - margin, y)
       .strokeColor('#e5e7eb')
       .lineWidth(1)
       .stroke();
    
    y += 12;
    
    // Valor total
    doc.fontSize(9)
       .font('Helvetica-Bold')
       .fillColor('#6b7280')
       .text('VALOR TOTAL', boxX, y, { width: boxWidth, align: 'right' });
    
    doc.fontSize(20)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text(this._formatarMoeda(totalGeral), boxX, y + 15, { width: boxWidth, align: 'right' });
  }

  _desenharFooter(doc) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    const pageHeight = doc.page.height;
    
    doc.moveTo(margin, pageHeight - 50)
       .lineTo(pageWidth - margin, pageHeight - 50)
       .strokeColor('#e5e7eb')
       .lineWidth(1)
       .stroke();
  }

  _formatarMoeda(valor) {
    return new Intl.NumberFormat('pt-BR', {
      style: 'currency',
      currency: 'BRL'
    }).format(valor);
  }

  _formatarQuantidade(quantidade, unidade) {
    const num = parseFloat(quantidade.toString().replace(',', '.'));
    
    if (unidade === 'Kg' || unidade === 'h') {
      return num.toFixed(2).replace('.', ',');
    }
    
    return num.toString();
  }

  _calcularTotalItem(quantidade, custo) {
    const qty = parseFloat(quantidade.toString().replace(',', '.'));
    return qty * custo;
  }
}

module.exports = new PdfService();