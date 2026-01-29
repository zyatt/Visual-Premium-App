const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');

class PdfService {
  gerarDocumento(data, type = 'orcamento') {
    const doc = new PDFDocument({ margin: 30, size: 'A4' });

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
       
    if (fs.existsSync(logoPath)) {
      try {
        doc.image(logoPath, margin, 35, { width: 70, height: 35 });
      } catch (error) {
      }
    }
    
    const numeroStr = numero.toString();
    
    const rightMargin = pageWidth - margin;
    const lineEndX = rightMargin;
    
    const now = new Date();
    const dataFormatada = now.toLocaleDateString('pt-BR');
    const horaFormatada = now.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
    const dataHoraStr = `${dataFormatada} ${horaFormatada}`;
    
    doc.fontSize(7).font('Helvetica');
    const tituloWidth = doc.widthOfString(titulo);
    
    doc.fontSize(20).font('Helvetica-Bold');
    const numeroWidth = doc.widthOfString(numeroStr);
    
    doc.fontSize(6).font('Helvetica');
    const dataHoraWidth = doc.widthOfString(dataHoraStr);
    
    const maxWidth = Math.max(tituloWidth, numeroWidth, dataHoraWidth);
    const dataHoraX = lineEndX - maxWidth;
    
    doc.fontSize(7)
       .font('Helvetica')
       .fillColor('#666666')
       .text(titulo, dataHoraX, 35, { width: maxWidth, align: 'center' });
    
    doc.fontSize(20)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text(numeroStr, dataHoraX, 48, { width: maxWidth, align: 'center' });
    
    doc.fontSize(6)
       .font('Helvetica')
       .fillColor('#666666')
       .text(dataHoraStr, dataHoraX, 70, { width: maxWidth, align: 'center' });
    
    doc.moveTo(margin, 85)
       .lineTo(pageWidth - margin, 85)
       .strokeColor('#e0e0e0')
       .lineWidth(0.5)
       .stroke();
  }

  _desenharInfoPrincipal(doc, cliente, produto) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    let y = 92;
    
    const cardHeight = 42;
    const cardY = y;
    
    doc.fontSize(5)
       .font('Helvetica-Bold')
       .fillColor('#6b7280')
       .text('CLIENTE', margin + 10, cardY + 6);
    
    doc.fontSize(7)
       .font('Helvetica')
       .fillColor('#374151')
       .text(cliente, margin + 10, cardY + 13, { width: pageWidth - 2 * margin - 20, align: 'left' });
    
    doc.fontSize(5)
       .font('Helvetica-Bold')
       .fillColor('#6b7280')
       .text('PRODUTO', margin + 10, cardY + 26);
    
    doc.fontSize(7)
       .font('Helvetica')
       .fillColor('#374151')
       .text(produto, margin + 10, cardY + 33, { width: pageWidth - 2 * margin - 20, align: 'left' });
    
    doc.moveTo(margin, cardY + cardHeight + 5)
       .lineTo(pageWidth - margin, cardY + cardHeight + 5)
       .strokeColor('#e0e0e0')
       .lineWidth(0.5)
       .stroke();
  }

  _desenharTabelaMateriais(doc, materiais) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    let y = 145;
    
    const startY = y;
    
    doc.fontSize(7)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text('MATERIAIS', margin, y);
    
    y += 10;
    
    const tableWidth = pageWidth - 2 * margin;
    const colWidths = {
      material: tableWidth * 0.48,
      unidade: tableWidth * 0.10,
      quantidade: tableWidth * 0.14,
      valorUnit: tableWidth * 0.14,
      total: tableWidth * 0.14
    };
    
    const headerStartY = y;
    
    doc.roundedRect(margin, y, tableWidth, 18, 3)
       .fillColor('#f5f5f5')
       .fill();
    
    doc.fontSize(5)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a');
    
    let x = margin + 8;
    doc.text('MATERIAL', x, y + 6, { width: colWidths.material - 15, align: 'left' });
    
    x += colWidths.material;
    doc.text('UN', x - 8, y + 6, { width: colWidths.unidade, align: 'center' });
    
    x += colWidths.unidade;
    doc.text('QUANTIDADE', x - 8, y + 6, { width: colWidths.quantidade, align: 'center' });
    
    x += colWidths.quantidade;
    doc.text('CUSTO', x - 8, y + 6, { width: colWidths.valorUnit, align: 'right' });
    
    x += colWidths.valorUnit;
    doc.text('TOTAL', x - 8, y + 6, { width: colWidths.total - 10, align: 'right' });
    
    y += 18;
    
    const contentStartY = y;
    
    doc.fontSize(6)
       .font('Helvetica')
       .fillColor('#1f2937');
    
    materiais.forEach((material, index) => {
      const rowHeight = 16;
      
      if (index % 2 === 0) {
        doc.rect(margin, y, tableWidth, rowHeight)
           .fillColor('#f9fafb')
           .fill();
      }
      
      x = margin + 8;
      const textY = y + 5;
      
      doc.fillColor('#1f2937')
         .font('Helvetica')
         .fontSize(6)
         .text(material.materialNome, x, textY, { 
           width: colWidths.material - 15, 
           align: 'left',
           lineBreak: false,
           ellipsis: true
         });
      
      x += colWidths.material;
      doc.fillColor('#6b7280')
         .fontSize(5)
         .text(material.materialUnidade, x - 8, textY, { width: colWidths.unidade, align: 'center' });
      
      x += colWidths.unidade;
      
      const quantidade = this._formatarQuantidade(material.quantidade, material.materialUnidade);
      doc.fillColor('#1f2937')
         .font('Helvetica-Bold')
         .fontSize(6)
         .text(quantidade, x - 8, textY, { width: colWidths.quantidade, align: 'center' });
      
      x += colWidths.quantidade;
      
      doc.fillColor('#6b7280')
         .font('Helvetica')
         .fontSize(5)
         .text(this._formatarMoeda(material.materialCusto), x - 8, textY, { width: colWidths.valorUnit, align: 'right' });
      
      x += colWidths.valorUnit;
      
      const totalItem = this._calcularTotalItem(material.quantidade, material.materialCusto);
      doc.fillColor('#1f2937')
         .font('Helvetica-Bold')
         .fontSize(6)
         .text(this._formatarMoeda(totalItem), x - 8, textY, { width: colWidths.total - 10, align: 'right' });
      
      y += rowHeight;
    });
    
    const totalHeight = y - headerStartY;
    
    doc.rect(margin, headerStartY, tableWidth, totalHeight)
       .strokeColor('#e0e0e0')
       .lineWidth(0.5)
       .stroke();
    
    return y;
  }

  _desenharItensAdicionais(doc, data) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    let y = doc.y + 10;
    
    const tableWidth = pageWidth - 2 * margin;
    const colWidths = {
      material: tableWidth * 0.48,
      unidade: tableWidth * 0.10,
      quantidade: tableWidth * 0.14,
      valorUnit: tableWidth * 0.14,
      total: tableWidth * 0.14
    };
    
    const totalColX = margin + 8 + colWidths.material + colWidths.unidade + colWidths.quantidade + colWidths.valorUnit;
    
    let subtotal = 0;
    data.materiais.forEach(mat => {
      subtotal += this._calcularTotalItem(mat.quantidade, mat.materialCusto);
    });
    
    doc.fontSize(6)
       .font('Helvetica')
       .fillColor('#6b7280')
       .text('Subtotal Materiais', totalColX - 40, y);
    
    doc.fontSize(7)
       .font('Helvetica-Bold')
       .fillColor('#374151')
       .text(this._formatarMoeda(subtotal), totalColX - 8, y, { 
         width: colWidths.total - 10, 
         align: 'right' 
       });
    
    y += 30;
    
    doc.fontSize(7)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text('INFORMAÇÕES ADICIONAIS', margin, y);
    
    y += 18;
    
    const fullBoxWidth = pageWidth - 2 * margin;
    const boxStartY = y - 3;
    
    if (data.despesasAdicionais && data.despesasAdicionais.length > 0) {
      const titulo = data.despesasAdicionais.length === 1 ? 'DESPESA ADICIONAL' : 'DESPESAS ADICIONAIS';
      
      const startY = y;
      
      doc.fontSize(5)
         .font('Helvetica-Bold')
         .fillColor('#6b7280')
         .text(titulo, margin + 10, y);
      
      y += 10;
      
      data.despesasAdicionais.forEach((despesa, index) => {
        doc.fontSize(6)
           .font('Helvetica')
           .fillColor('#1f2937')
           .text(despesa.descricao, margin + 10, y, { width: fullBoxWidth - 110 });
        
        doc.fontSize(6)
           .font('Helvetica-Bold')
           .fillColor('#1a1a1a')
           .text(this._formatarMoeda(despesa.valor), pageWidth - margin - 80, y, { 
             width: 70, 
             align: 'right' 
           });
        
        y += 12;
        
        if (index < data.despesasAdicionais.length - 1) {
          doc.moveTo(margin + 10, y)
             .lineTo(pageWidth - margin, y)
             .strokeColor('#e5e7eb')
             .lineWidth(0.3)
             .stroke();
          
          y += 8;
        }
      });
      
      y += 6;
    }
    
    if (data.frete && data.freteDesc && data.freteValor) {
      const startY = y;
      
      doc.fontSize(5)
         .font('Helvetica-Bold')
         .fillColor('#6b7280')
         .text('FRETE', margin + 10, y);
      
      y += 10;
      
      doc.fontSize(6)
         .font('Helvetica')
         .fillColor('#1f2937')
         .text(data.freteDesc, margin + 10, y, { width: fullBoxWidth - 110 });
      
      doc.fontSize(6)
         .font('Helvetica-Bold')
         .fillColor('#1a1a1a')
         .text(this._formatarMoeda(data.freteValor), pageWidth - margin - 80, y, { 
           width: 70, 
           align: 'right' 
         });
      
      y += 12;
      
      doc.moveTo(margin + 10, y)
         .lineTo(pageWidth - margin, y)
         .strokeColor('#e5e7eb')
         .lineWidth(0.3)
         .stroke();
      
      y += 8;
    }
    
    if (data.caminhaoMunck && data.caminhaoMunckHoras && data.caminhaoMunckValorHora) {
      const totalMunck = data.caminhaoMunckHoras * data.caminhaoMunckValorHora;
      const startY = y;
      
      doc.fontSize(5)
         .font('Helvetica-Bold')
         .fillColor('#6b7280')
         .text('CAMINHÃO MUNCK', margin + 10, y);
      
      y += 10;
      
      doc.fontSize(6)
         .font('Helvetica')
         .fillColor('#1f2937')
         .text(`${this._formatarQuantidade(data.caminhaoMunckHoras, 'h')} horas × ${this._formatarMoeda(data.caminhaoMunckValorHora)}/h`, 
                margin + 10, y, { width: fullBoxWidth - 110 });
      
      doc.fontSize(6)
         .font('Helvetica-Bold')
         .fillColor('#1a1a1a')
         .text(this._formatarMoeda(totalMunck), pageWidth - margin - 80, y, { 
           width: 70, 
           align: 'right' 
         });
      
      y += 12;
    }
    
    const boxHeight = y - boxStartY;
    doc.rect(margin, boxStartY, fullBoxWidth, boxHeight)
       .strokeColor('#e0e0e0')
       .lineWidth(0.5)
       .stroke();
  }

  _desenharResumo(doc, data) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    let y = doc.y + 10;
    
    const boxWidth = 180;
    const boxX = pageWidth - margin - boxWidth;
    
    let totalGeral = 0;
    
    data.materiais.forEach(mat => {
      totalGeral += this._calcularTotalItem(mat.quantidade, mat.materialCusto);
    });
    
    if (data.despesasAdicionais && data.despesasAdicionais.length > 0) {
      totalGeral += data.despesasAdicionais.reduce((sum, d) => sum + d.valor, 0);
    }
    
    if (data.freteValor) totalGeral += data.freteValor;
    
    if (data.caminhaoMunckHoras && data.caminhaoMunckValorHora) {
      totalGeral += data.caminhaoMunckHoras * data.caminhaoMunckValorHora;
    }
    
    y += 8;
    
    doc.fontSize(7)
       .font('Helvetica-Bold')
       .fillColor('#6b7280')
       .text('VALOR TOTAL', boxX, y, { width: boxWidth, align: 'right' });
    
    doc.fontSize(14)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text(this._formatarMoeda(totalGeral), boxX, y + 10, { width: boxWidth, align: 'right' });
  }

  _desenharFooter(doc) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    const pageHeight = doc.page.height;
    
    doc.moveTo(margin, pageHeight - 40)
       .lineTo(pageWidth - margin, pageHeight - 40)
       .strokeColor('#e5e7eb')
       .lineWidth(0.5)
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