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

    // ✅ Tabela de sobras separada (igual ao pdf_layout.js)
    const materiaisComSobras = data.materiais.filter(
      m => m.valorSobraOrcado != null || m.custoSobrasRealizado != null
    );
    if (materiaisComSobras.length > 0) {
      currentY = this._desenharTabelaSobras(doc, materiaisComSobras, currentY);
    }
    
    if (data.materiaisAvulsos && data.materiaisAvulsos.length > 0) {
      currentY = this._desenharTabelaMateriaisAvulsos(doc, data.materiaisAvulsos, currentY);
    }
    
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
      statusColor = '#10b981';
      statusText = 'Economia';
    } else if (data.diferencaTotal > 0) {
      statusColor = '#ef4444';
      statusText = 'Excedeu';
    } else {
      statusColor = '#6b7280';
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
    const verticalCenter = (boxHeight - 30) / 2;
    
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
    const rowHeight = 20;
    
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
      const textY = y + 7;
      
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
      const diferencaPct = material.valorOrcado !== 0
        ? Math.abs((material.diferenca / material.valorOrcado) * 100).toFixed(1)
        : '0.0';
      
      doc.fillColor(diferencaColor)
         .font('Helvetica-Bold')
         .fontSize(6)
         .text(diferencaText, x, textY, { width: colWidths.diferenca, align: 'center' });
      doc.fillColor(diferencaColor)
         .font('Helvetica')
         .fontSize(5.5)
         .text(`${diferencaPct}%`, x, textY + 7, { width: colWidths.diferenca, align: 'center' });
      
      y += rowHeight;
    });
    
    const tableHeight = y - tableStartY;
    doc.roundedRect(margin, tableStartY, contentWidth, tableHeight, 4)
       .strokeColor('#d1d5db')
       .lineWidth(1)
       .stroke();

    // ✅ Subtotal Materiais (sem sobras)
    const subtotalMateriais = materiais.reduce((sum, m) => sum + (m.custoRealizadoTotal || 0), 0);
    const subtotalBoxWidth = 200;
    const subtotalBoxX = pageWidth - margin - subtotalBoxWidth;

    y += 8;

    doc.fontSize(6)
      .font('Helvetica')
      .fillColor('#6b7280')
      .text('Subtotal Materiais', subtotalBoxX, y, { 
        width: subtotalBoxWidth - 87, 
        align: 'right' 
      });
    
    doc.fontSize(7)
      .font('Helvetica-Bold')
      .fillColor('#1f2937')
      .text(this._formatarMoeda(subtotalMateriais), subtotalBoxX + subtotalBoxWidth - 105, y, { 
        width: 80, 
        align: 'right' 
      });

    y += 15;
    
    return y;
  }

  // ✅ Tabela de sobras separada — colunas Orçado / Realizado / Diferença
  _desenharTabelaSobras(doc, materiaisComSobras, startY) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    const contentWidth = pageWidth - 2 * margin;
    let y = startY;

    doc.fontSize(7)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text('SOBRAS', margin, y);

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
    const rowHeight = 20;

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

    materiaisComSobras.forEach((material, index) => {
      if (index % 2 === 0) {
        doc.rect(margin, y, contentWidth, rowHeight)
           .fillColor('#fafafa')
           .fill();
      }

      x = margin;
      const textY = y + 7;

      doc.fillColor('#6b7280')
         .font('Helvetica-Bold')
         .fontSize(6)
         .text((index + 1).toString(), x, textY, { width: colWidths.numero, align: 'center' });
      x += colWidths.numero;

      doc.fillColor('#1f2937')
         .font('Helvetica-Oblique')
         .fontSize(6)
         .text(material.materialNome, x + 6, textY, {
           width: colWidths.material - 6,
           align: 'left',
           lineBreak: false,
           ellipsis: true
         });
      x += colWidths.material;

      // Orçado
      if (material.valorSobraOrcado != null) {
        doc.fillColor('#6b7280')
           .font('Helvetica')
           .fontSize(6)
           .text(this._formatarMoeda(material.valorSobraOrcado), x, textY, { width: colWidths.orcado, align: 'center' });
      } else {
        doc.fillColor('#d1d5db')
           .font('Helvetica')
           .fontSize(6)
           .text('—', x, textY, { width: colWidths.orcado, align: 'center' });
      }
      x += colWidths.orcado;

      // Realizado
      if (material.custoSobrasRealizado != null) {
        doc.fillColor('#1f2937')
           .font('Helvetica-Bold')
           .fontSize(6)
           .text(this._formatarMoeda(material.custoSobrasRealizado), x, textY, { width: colWidths.realizado, align: 'center' });
      } else {
        doc.fillColor('#d1d5db')
           .font('Helvetica')
           .fontSize(6)
           .text('—', x, textY, { width: colWidths.realizado, align: 'center' });
      }
      x += colWidths.realizado;

      // Diferença
      if (material.valorSobraOrcado != null && material.custoSobrasRealizado != null) {
        const sobraDif = material.custoSobrasRealizado - material.valorSobraOrcado;
        const sobraDifColor = sobraDif < 0 ? '#10b981' : sobraDif > 0 ? '#ef4444' : '#6b7280';
        const sobraPct = material.valorSobraOrcado !== 0
          ? Math.abs((sobraDif / material.valorSobraOrcado) * 100).toFixed(1)
          : '0.0';
        doc.fillColor(sobraDifColor)
           .font('Helvetica-Bold')
           .fontSize(6)
           .text(`${sobraDif >= 0 ? '+' : ''}${this._formatarMoeda(sobraDif)}`, x, textY, { width: colWidths.diferenca, align: 'center' });
        doc.fillColor(sobraDifColor)
           .font('Helvetica')
           .fontSize(5.5)
           .text(`${sobraPct}%`, x, textY + 7, { width: colWidths.diferenca, align: 'center' });
      } else {
        doc.fillColor('#d1d5db')
           .font('Helvetica')
           .fontSize(6)
           .text('—', x, textY, { width: colWidths.diferenca, align: 'center' });
      }

      y += rowHeight;
    });

    const tableHeight = headerHeight + (materiaisComSobras.length * rowHeight);
    doc.roundedRect(margin, tableStartY, contentWidth, tableHeight, 4)
       .strokeColor('#d1d5db')
       .lineWidth(1)
       .stroke();

    // Divisórias verticais
    let xDiv = margin + colWidths.numero;
    [colWidths.material, colWidths.orcado, colWidths.realizado].forEach(w => {
      doc.moveTo(xDiv, tableStartY)
         .lineTo(xDiv, tableStartY + tableHeight)
         .strokeColor('#e5e7eb')
         .lineWidth(0.5)
         .stroke();
      xDiv += w;
    });

    y += 8;

    // ✅ Subtotal Sobras
    const subtotalSobrasOrcado = materiaisComSobras.reduce((sum, m) => sum + (m.valorSobraOrcado || 0), 0);
    const subtotalSobrasRealizado = materiaisComSobras.reduce((sum, m) => sum + (m.custoSobrasRealizado || 0), 0);
    const subtotalBoxWidth = 200;
    const subtotalBoxX = pageWidth - margin - subtotalBoxWidth;

    doc.fontSize(6)
      .font('Helvetica')
      .fillColor('#6b7280')
      .text('Subtotal Sobras', subtotalBoxX, y, {
        width: subtotalBoxWidth - 87,
        align: 'right'
      });

    doc.fontSize(7)
      .font('Helvetica-Bold')
      .fillColor('#1f2937')
      .text(this._formatarMoeda(subtotalSobrasRealizado), subtotalBoxX + subtotalBoxWidth - 105, y, {
        width: 80,
        align: 'right'
      });

    y += 15;

    return y;
  }

  _desenharTabelaMateriaisAvulsos(doc, materiaisAvulsos, startY) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    const contentWidth = pageWidth - 2 * margin;
    let y = startY;

    doc.fontSize(7)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text('MATERIAIS ADICIONAIS', margin, y);

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

    materiaisAvulsos.forEach((item, index) => {
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
         .text(item.materialNome, x + 6, textY, {
           width: colWidths.material - 6,
           align: 'left',
           lineBreak: false,
           ellipsis: true
         });
      x += colWidths.material;

      doc.fillColor('#d1d5db')
         .fontSize(6)
         .text('—', x, textY, { width: colWidths.orcado, align: 'center' });
      x += colWidths.orcado;

      doc.fillColor('#1f2937')
         .font('Helvetica-Bold')
         .fontSize(6)
         .text(this._formatarMoeda(item.custoRealizado), x, textY, { width: colWidths.realizado, align: 'center' });
      x += colWidths.realizado;

      doc.fillColor('#d1d5db')
         .font('Helvetica-Bold')
         .fontSize(6)
         .text('—', x, textY, { width: colWidths.diferenca, align: 'center' });

      y += rowHeight;
    });

    const tableHeight = headerHeight + (materiaisAvulsos.length * rowHeight);
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
    const rowHeight = 20;
    
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
      const textY = y + 7;
      
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
      const diferencaPct = despesa.valorOrcado !== 0
        ? Math.abs((despesa.diferenca / despesa.valorOrcado) * 100).toFixed(1)
        : '0.0';
      
      doc.fillColor(diferencaColor)
         .font('Helvetica-Bold')
         .fontSize(6)
         .text(diferencaText, x, textY, { width: colWidths.diferenca, align: 'center' });
      doc.fillColor(diferencaColor)
         .font('Helvetica')
         .fontSize(5.5)
         .text(`${diferencaPct}%`, x, textY + 7, { width: colWidths.diferenca, align: 'center' });
      
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
    const rowHeight = 20;
    
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
      const textY = y + 7;
      
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
      const diferencaPct = opcao.valorOrcado !== 0
        ? Math.abs((opcao.diferenca / opcao.valorOrcado) * 100).toFixed(1)
        : '0.0';
      
      doc.fillColor(diferencaColor)
         .font('Helvetica-Bold')
         .fontSize(6)
         .text(diferencaText, x, textY, { width: colWidths.diferenca, align: 'center' });
      doc.fillColor(diferencaColor)
         .font('Helvetica')
         .fontSize(5.5)
         .text(`${diferencaPct}%`, x, textY + 7, { width: colWidths.diferenca, align: 'center' });
      
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