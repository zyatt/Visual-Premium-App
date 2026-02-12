const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');

class PdfRelatorioLayout {
  gerarDocumento(data) {
    const doc = new PDFDocument({ margin: 30, size: 'A4' });

    const logoPath = path.join(__dirname, '../../../assets/images/logo preta.png');
    
    let currentY = this._desenharHeader(doc, logoPath, data.numeroPedido);
    currentY = this._desenharInfoPrincipal(doc, data, currentY);
    currentY = this._desenharResumo(doc, data, currentY);
    currentY = this._desenharTabelaMateriais(doc, data.materiais, currentY);
    
    if (data.despesas && data.despesas.length > 0) {
      currentY = this._desenharTabelaDespesas(doc, data.despesas, currentY);
    }
    
    if (data.opcoesExtras && data.opcoesExtras.length > 0) {
      currentY = this._desenharTabelaOpcoesExtras(doc, data.opcoesExtras, currentY);
    }
    
    this._desenharFooter(doc);
    
    doc.end();
    return doc;
  }

  _desenharHeader(doc, logoPath, numeroPedido) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    let y = 35;
    
    if (fs.existsSync(logoPath)) {
      try {
        doc.image(logoPath, margin, y, { width: 70, height: 35 });
      } catch (error) {
        console.error('Erro ao carregar logo:', error);
      }
    }
    
    const numeroStr = numeroPedido || 'S/N';
    
    const now = new Date();
    const dataFormatada = now.toLocaleDateString('pt-BR');
    const horaFormatada = now.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
    const dataHoraStr = `${dataFormatada} ${horaFormatada}`;
    
    const infoBlockWidth = 120;
    const infoBlockX = pageWidth - infoBlockWidth;
    doc.fontSize(8)
      .font('Helvetica')
      .fillColor('#666')
      .text('Relatório Comparativo', infoBlockX, y, { width: infoBlockWidth, align: 'center' });
    
    doc.fontSize(24)
      .font('Helvetica-Bold')
      .fillColor('#1a1a1a')
      .text(numeroStr, infoBlockX, y + 11, { width: infoBlockWidth, align: 'center' });
    
    doc.fontSize(7)
      .font('Helvetica')
      .fillColor('#666666')
      .text(dataHoraStr, infoBlockX, y + 35, { width: infoBlockWidth, align: 'center' });
    
    return 78;
  }

  _desenharInfoPrincipal(doc, data, startY) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    const contentWidth = pageWidth - 2 * margin;
    let y = startY;
    
    const cardHeight = 48;
    const padding = 9;
    
    doc.roundedRect(margin, y, contentWidth, cardHeight, 4)
       .strokeColor('#d1d5db')
       .lineWidth(1)
       .stroke();
    
    doc.fontSize(6)
       .font('Helvetica-Bold')
       .fillColor('#6b7280')
       .text('CLIENTE', margin + padding, y + padding);
    doc.fontSize(8)
       .font('Helvetica')
       .fillColor('#1f2937')
       .text(data.cliente, margin + padding, y + padding + 7, { 
         width: contentWidth - 2 * padding, 
         align: 'left' 
       });
    
    doc.fontSize(6)
       .font('Helvetica-Bold')
       .fillColor('#6b7280')
       .text('PRODUTO', margin + padding, y + padding + 20);
    
    doc.fontSize(8)
       .font('Helvetica')
       .fillColor('#1f2937')
       .text(data.produtoNome, margin + padding, y + padding + 27, { 
         width: contentWidth - 2 * padding, 
         align: 'left' 
       });
    
    return y + cardHeight + 8;
  }

  _desenharResumo(doc, data, startY) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    const contentWidth = pageWidth - 2 * margin;
    let y = startY;
    
    let statusColor;
    let statusText;
    
    if (data.diferencaTotal < 0) {
      statusColor = '#10b981'; // Verde - Economia
      statusText = 'Economia';
    } else if (data.diferencaTotal > 0) {
      statusColor = '#ef4444'; // Vermelho - Excedeu
      statusText = 'Excedeu';
    } else {
      statusColor = '#6b7280'; // Cinza - Conforme
      statusText = 'Conforme';
    }
    
    doc.fontSize(7)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text('RESUMO COMPARATIVO', margin, y);
    
    y += 10;
    
    const boxHeight = 70;
    
    doc.roundedRect(margin, y, contentWidth, boxHeight, 4)
       .fillAndStroke('#ffffff', '#d1d5db');
    
    const padding = 12;
    const colWidth = (contentWidth - 3 * padding) / 3;
    
    // Centralizar verticalmente: (boxHeight - altura_conteudo) / 2
    const verticalCenter = (boxHeight - 30) / 2; // 30 = altura aproximada do conteúdo (label + value)
    
    let x = margin + padding;
    this._desenharColuna(doc, 'ORÇADO', this._formatarMoeda(data.totalOrcado), x, y + verticalCenter, colWidth);
    
    x += colWidth + padding;
    this._desenharColuna(doc, 'REALIZADO', this._formatarMoeda(data.totalRealizado), x, y + verticalCenter, colWidth);
    
    x += colWidth + padding;
    const valorEconomia = this._formatarMoeda(Math.abs(data.diferencaTotal));
    const percentualText = `${Math.abs(data.percentualTotal).toFixed(1)}%`;
    this._desenharColunaEconomia(doc, statusText.toUpperCase(), valorEconomia, percentualText, x, y + verticalCenter, colWidth, statusColor);
    
    y += boxHeight + 8;
    
    return y;
  }

  _desenharColuna(doc, label, value, x, y, width, color = '#1f2937') {
    doc.fontSize(6)
       .font('Helvetica-Bold')
       .fillColor('#6b7280')
       .text(label, x, y, { width, align: 'center' });
    
    doc.fontSize(14)
       .font('Helvetica-Bold')
       .fillColor(color)
       .text(value, x, y + 12, { width, align: 'center' });
  }

  _desenharColunaEconomia(doc, label, valorEconomia, percentual, x, y, width, color = '#1f2937') {
    doc.fontSize(6)
       .font('Helvetica-Bold')
       .fillColor('#6b7280')
       .text(label, x, y, { width, align: 'center' });
    
    const textoCompleto = `${valorEconomia} (${percentual})`;
    
    doc.fontSize(14)
       .font('Helvetica-Bold')
       .fillColor(color)
       .text(textoCompleto, x, y + 12, { width, align: 'center' });
  }

  _desenharTabelaMateriais(doc, materiais, startY) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    const contentWidth = pageWidth - 2 * margin;
    let y = startY;
    
    doc.fontSize(7)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text('MATERIAIS', margin, y);
    
    y += 10;
    
    const colWidths = {
      numero: contentWidth * 0.05,
      material: contentWidth * 0.40,
      orcado: contentWidth * 0.18,
      realizado: contentWidth * 0.18,
      diferenca: contentWidth * 0.19
    };
    
    const tableStartY = y;
    const headerHeight = 15;
    const rowHeight = 13;
    
    doc.roundedRect(margin, y, contentWidth, headerHeight, 3)
       .fillAndStroke('#f3f4f6', '#d1d5db');
    
    doc.fontSize(6)
       .font('Helvetica-Bold')
       .fillColor('#374151');
    
    let x = margin;
    doc.text('#', x, y + 4.5, { width: colWidths.numero, align: 'center' });
    x += colWidths.numero;
    
    doc.text('MATERIAL', x, y + 4.5, { width: colWidths.material, align: 'center' });
    x += colWidths.material;
    
    doc.text('ORÇADO', x, y + 4.5, { width: colWidths.orcado, align: 'center' });
    x += colWidths.orcado;
    
    doc.text('REALIZADO', x, y + 4.5, { width: colWidths.realizado, align: 'center' });
    x += colWidths.realizado;
    
    doc.text('DIFERENÇA', x, y + 4.5, { width: colWidths.diferenca, align: 'center' });
    
    y += headerHeight;
    
    materiais.forEach((material, index) => {
      if (index % 2 === 0) {
        doc.rect(margin, y, contentWidth, rowHeight)
           .fillColor('#fafafa')
           .fill();
      }
      
      x = margin;
      const textY = y + 3.5;
      
      doc.fillColor('#6b7280')
         .font('Helvetica-Bold')
         .fontSize(6)
         .text((index + 1).toString(), x, textY, { width: colWidths.numero, align: 'center' });
      x += colWidths.numero;
      
      doc.fillColor('#1f2937')
         .font('Helvetica')
         .fontSize(6)
         .text(material.materialNome, x + 6, textY, { 
           width: colWidths.material - 6, 
           align: 'left',
           lineBreak: false,
           ellipsis: true
         });
      x += colWidths.material;
      
      doc.fillColor('#6b7280')
         .fontSize(6)
         .text(this._formatarMoeda(material.valorOrcado), x, textY, { width: colWidths.orcado, align: 'center' });
      x += colWidths.orcado;
      
      doc.fillColor('#1f2937')
         .font('Helvetica-Bold')
         .fontSize(6)
         .text(this._formatarMoeda(material.custoRealizadoTotal), x, textY, { width: colWidths.realizado, align: 'center' });
      x += colWidths.realizado;
      
      const diferencaColor = material.status === 'abaixo' ? '#10b981' : material.status === 'acima' ? '#ef4444' : '#6b7280';
      const diferencaText = `${material.diferenca >= 0 ? '+' : ''}${this._formatarMoeda(material.diferenca)}`;
      
      doc.fillColor(diferencaColor)
         .font('Helvetica-Bold')
         .fontSize(6)
         .text(diferencaText, x, textY, { width: colWidths.diferenca, align: 'center' });
      
      y += rowHeight;
    });
    
    const tableHeight = headerHeight + (materiais.length * rowHeight);
    doc.roundedRect(margin, tableStartY, contentWidth, tableHeight, 4)
       .strokeColor('#d1d5db')
       .lineWidth(1)
       .stroke();
    
    return y + 8;
  }

  _desenharTabelaDespesas(doc, despesas, startY) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    const contentWidth = pageWidth - 2 * margin;
    let y = startY;
    
    doc.fontSize(7)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text('DESPESAS ADICIONAIS', margin, y);
    
    y += 10;
    
    const colWidths = {
      numero: contentWidth * 0.05,
      descricao: contentWidth * 0.40,
      orcado: contentWidth * 0.18,
      realizado: contentWidth * 0.18,
      diferenca: contentWidth * 0.19
    };
    
    const tableStartY = y;
    const headerHeight = 15;
    const rowHeight = 13;
    
    doc.roundedRect(margin, y, contentWidth, headerHeight, 3)
       .fillAndStroke('#f3f4f6', '#d1d5db');
    
    doc.fontSize(6)
       .font('Helvetica-Bold')
       .fillColor('#374151');
    
    let x = margin;
    doc.text('#', x, y + 4.5, { width: colWidths.numero, align: 'center' });
    x += colWidths.numero;
    
    doc.text('DESCRIÇÃO', x, y + 4.5, { width: colWidths.descricao, align: 'center' });
    x += colWidths.descricao;
    
    doc.text('ORÇADO', x, y + 4.5, { width: colWidths.orcado, align: 'center' });
    x += colWidths.orcado;
    
    doc.text('REALIZADO', x, y + 4.5, { width: colWidths.realizado, align: 'center' });
    x += colWidths.realizado;
    
    doc.text('DIFERENÇA', x, y + 4.5, { width: colWidths.diferenca, align: 'center' });
    
    y += headerHeight;
    
    despesas.forEach((despesa, index) => {
      if (index % 2 === 0) {
        doc.rect(margin, y, contentWidth, rowHeight)
           .fillColor('#fafafa')
           .fill();
      }
      
      x = margin;
      const textY = y + 3.5;
      
      doc.fillColor('#6b7280')
         .font('Helvetica-Bold')
         .fontSize(6)
         .text((index + 1).toString(), x, textY, { width: colWidths.numero, align: 'center' });
      x += colWidths.numero;
      
      doc.fillColor('#1f2937')
         .font('Helvetica')
         .fontSize(6)
         .text(despesa.descricao, x + 6, textY, { 
           width: colWidths.descricao - 6, 
           align: 'left',
           lineBreak: false,
           ellipsis: true
         });
      x += colWidths.descricao;
      
      doc.fillColor('#6b7280')
         .fontSize(6)
         .text(this._formatarMoeda(despesa.valorOrcado), x, textY, { width: colWidths.orcado, align: 'center' });
      x += colWidths.orcado;
      
      doc.fillColor('#1f2937')
         .font('Helvetica-Bold')
         .fontSize(6)
         .text(this._formatarMoeda(despesa.valorRealizado), x, textY, { width: colWidths.realizado, align: 'center' });
      x += colWidths.realizado;
      
      const diferencaColor = despesa.status === 'abaixo' ? '#10b981' : despesa.status === 'acima' ? '#ef4444' : '#6b7280';
      const diferencaText = `${despesa.diferenca >= 0 ? '+' : ''}${this._formatarMoeda(despesa.diferenca)}`;
      
      doc.fillColor(diferencaColor)
         .font('Helvetica-Bold')
         .fontSize(6)
         .text(diferencaText, x, textY, { width: colWidths.diferenca, align: 'center' });
      
      y += rowHeight;
    });
    
    const tableHeight = headerHeight + (despesas.length * rowHeight);
    doc.roundedRect(margin, tableStartY, contentWidth, tableHeight, 4)
       .strokeColor('#d1d5db')
       .lineWidth(1)
       .stroke();
    
    return y + 8;
  }

  _desenharTabelaOpcoesExtras(doc, opcoesExtras, startY) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    const contentWidth = pageWidth - 2 * margin;
    let y = startY;
    
    doc.fontSize(7)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text('OUTROS', margin, y);
    
    y += 10;
    
    const colWidths = {
      numero: contentWidth * 0.05,
      nome: contentWidth * 0.40,
      orcado: contentWidth * 0.18,
      realizado: contentWidth * 0.18,
      diferenca: contentWidth * 0.19
    };
    
    const tableStartY = y;
    const headerHeight = 15;
    const rowHeight = 13;
    
    doc.roundedRect(margin, y, contentWidth, headerHeight, 3)
       .fillAndStroke('#f3f4f6', '#d1d5db');
    
    doc.fontSize(6)
       .font('Helvetica-Bold')
       .fillColor('#374151');
    
    let x = margin;
    doc.text('#', x, y + 4.5, { width: colWidths.numero, align: 'center' });
    x += colWidths.numero;
    
    doc.text('DESCRIÇÃO', x, y + 4.5, { width: colWidths.nome, align: 'center' });
    x += colWidths.nome;
    
    doc.text('ORÇADO', x, y + 4.5, { width: colWidths.orcado, align: 'center' });
    x += colWidths.orcado;
    
    doc.text('REALIZADO', x, y + 4.5, { width: colWidths.realizado, align: 'center' });
    x += colWidths.realizado;
    
    doc.text('DIFERENÇA', x, y + 4.5, { width: colWidths.diferenca, align: 'center' });
    
    y += headerHeight;
    
    opcoesExtras.forEach((opcao, index) => {
      if (index % 2 === 0) {
        doc.rect(margin, y, contentWidth, rowHeight)
           .fillColor('#fafafa')
           .fill();
      }
      
      x = margin;
      const textY = y + 3.5;
      
      doc.fillColor('#6b7280')
         .font('Helvetica-Bold')
         .fontSize(6)
         .text((index + 1).toString(), x, textY, { width: colWidths.numero, align: 'center' });
      x += colWidths.numero;
      
      doc.fillColor('#1f2937')
         .font('Helvetica')
         .fontSize(6)
         .text(opcao.nome, x + 6, textY, { 
           width: colWidths.nome - 6, 
           align: 'left',
           lineBreak: false,
           ellipsis: true
         });
      x += colWidths.nome;
      
      doc.fillColor('#6b7280')
         .fontSize(6)
         .text(this._formatarMoeda(opcao.valorOrcado), x, textY, { width: colWidths.orcado, align: 'center' });
      x += colWidths.orcado;
      
      doc.fillColor('#1f2937')
         .font('Helvetica-Bold')
         .fontSize(6)
         .text(this._formatarMoeda(opcao.valorRealizado), x, textY, { width: colWidths.realizado, align: 'center' });
      x += colWidths.realizado;
      
      const diferencaColor = opcao.status === 'abaixo' ? '#10b981' : opcao.status === 'acima' ? '#ef4444' : '#6b7280';
      const diferencaText = `${opcao.diferenca >= 0 ? '+' : ''}${this._formatarMoeda(opcao.diferenca)}`;
      
      doc.fillColor(diferencaColor)
         .font('Helvetica-Bold')
         .fontSize(6)
         .text(diferencaText, x, textY, { width: colWidths.diferenca, align: 'center' });
      
      y += rowHeight;
    });
    
    const tableHeight = headerHeight + (opcoesExtras.length * rowHeight);
    doc.roundedRect(margin, tableStartY, contentWidth, tableHeight, 4)
       .strokeColor('#d1d5db')
       .lineWidth(1)
       .stroke();
    
    return y + 8;
  }

  _desenharFooter(doc) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    const pageHeight = doc.page.height;
    const contentWidth = pageWidth - 2 * margin;
    
    doc.moveTo(margin, pageHeight - 65)
       .lineTo(pageWidth - margin, pageHeight - 65)
       .strokeColor('#d1d5db')
       .lineWidth(1)
       .stroke();
    
    const footerTextY = pageHeight - 58;
    
    doc.fontSize(6)
       .font('Helvetica')
       .fillColor('#6b7280')
       .text('Visual Premium', margin, footerTextY, {
         width: contentWidth,
         align: 'left'
       });
        
    const lgpdText = 'Declara cumprir fielmente e integralmente todas as disposições contidas na Lei nº 13.709, de 14 de agosto de 2018, Lei Geral de Proteção de Dados Pessoais (LGPD). Portanto, após abertura desse arquivo e ou link enviado para o cliente, o mesmo, se torna responsável por qualquer repasse de informação a seu respeito, eximindo a Visual Premium de qualquer responsabilidade, conforme a lei citada acima.';
    
    doc.fontSize(5)
       .font('Helvetica')
       .fillColor('#6b7280')
       .text(lgpdText, margin, footerTextY + 8, {
         width: contentWidth,
         align: 'justify',
         lineGap: 1
       });
  }

  _formatarMoeda(valor) {
    return new Intl.NumberFormat('pt-BR', {
      style: 'currency',
      currency: 'BRL'
    }).format(valor);
  }

  _hexToRgb(hex, alpha = 1) {
    const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
    if (!result) return hex;
    
    const r = parseInt(result[1], 16);
    const g = parseInt(result[2], 16);
    const b = parseInt(result[3], 16);
    
    return `rgba(${r}, ${g}, ${b}, ${alpha})`;
  }
}

module.exports = new PdfRelatorioLayout();