const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');

class PdfLayout {
  gerarDocumento(data, type = 'orcamento') {
    const doc = new PDFDocument({ margin: 30, size: 'A4' });

    const logoPath = path.join(__dirname, '../../../assets/images/logo preta.png');
    const titulo = type === 'orcamento' ? 'Orçamento' : 'Pedido';
    
    let currentY = this._desenharHeader(doc, logoPath, data.numero, titulo);
    currentY = this._desenharInfoPrincipal(doc, data.cliente, data.produtoNome, currentY);
    currentY = this._desenharTabelaMateriais(doc, data.materiais, currentY);
    
    // ✅ Adicionar tabela de sobras se houver
    const materiaisComSobras = data.materiais.filter(m => (m.valorSobra || 0) > 0);
    if (materiaisComSobras.length > 0) {
      currentY = this._desenharTabelaSobras(doc, materiaisComSobras, currentY);
    }
    
    const temItensAdicionais = this._verificarItensAdicionais(data, type);
    
    if (temItensAdicionais) {
      currentY = this._desenharItensAdicionais(doc, data, type, currentY);
    }
    
    currentY = this._desenharInfoPagamentoETotal(doc, data, type, currentY);
    this._desenharFooter(doc);
    
    doc.end();
    return doc;
  }

  _verificarItensAdicionais(data, type) {
    const temDespesas = data.despesasAdicionais && data.despesasAdicionais.length > 0;
    const temOpcoesExtras = data.opcoesExtras && data.opcoesExtras.length > 0;
    
    return temDespesas || temOpcoesExtras;
  }

  _desenharHeader(doc, logoPath, numero, titulo) {
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
    
    let numeroStr = 'S/N';
    if (numero !== null && numero !== undefined && numero !== '') {
      const numConverted = numero.toString().trim();
      if (numConverted !== '' && numConverted !== 'null' && numConverted !== 'undefined') {
        numeroStr = numConverted;
      }
    }
    
    const now = new Date();
    const dataFormatada = now.toLocaleDateString('pt-BR');
    const horaFormatada = now.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
    const dataHoraStr = `${dataFormatada} ${horaFormatada}`;
    
    const infoBlockWidth = 120;
    const infoBlockX = pageWidth - infoBlockWidth;
    doc.fontSize(8)
      .font('Helvetica')
      .fillColor('#666')
      .text(titulo, infoBlockX, y, { width: infoBlockWidth, align: 'center' });
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

  _desenharInfoPrincipal(doc, cliente, produto, startY) {
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
       .text(cliente, margin + padding, y + padding + 7, { 
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
       .text(produto, margin + padding, y + padding + 27, { 
         width: contentWidth - 2 * padding, 
         align: 'left' 
       });
    
    return y + cardHeight + 8;
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
      numero: contentWidth * 0.06,
      material: contentWidth * 0.52,
      unidade: contentWidth * 0.08,
      quantidade: contentWidth * 0.08,
      valorUnit: contentWidth * 0.13,
      total: contentWidth * 0.13
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
    
    doc.text('UN', x, y + 4.5, { width: colWidths.unidade, align: 'center' });
    x += colWidths.unidade;
    
    doc.text('QTD', x, y + 4.5, { width: colWidths.quantidade, align: 'center' });
    x += colWidths.quantidade;
    
    doc.text('CUSTO', x, y + 4.5, { width: colWidths.valorUnit, align: 'center' });
    x += colWidths.valorUnit;
    
    doc.text('TOTAL', x, y + 4.5, { width: colWidths.total, align: 'center' });
    
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
         .text(material.materialUnidade, x, textY, { width: colWidths.unidade, align: 'center' });
      x += colWidths.unidade;
      
      const quantidade = this._formatarQuantidade(material.quantidade, material.materialUnidade);
      doc.fillColor('#1f2937')
         .font('Helvetica-Bold')
         .fontSize(6)
         .text(quantidade, x, textY, { width: colWidths.quantidade, align: 'center' });
      x += colWidths.quantidade;
      
      doc.fillColor('#6b7280')
         .font('Helvetica')
         .fontSize(6)
         .text(this._formatarMoeda(material.materialCusto), x, textY, { width: colWidths.valorUnit, align: 'center' });
      x += colWidths.valorUnit;
      
      const totalItem = this._calcularTotalItem(material.quantidade, material.materialCusto);
      doc.fillColor('#1f2937')
         .font('Helvetica-Bold')
         .fontSize(6)
         .text(this._formatarMoeda(totalItem), x, textY, { width: colWidths.total, align: 'center' });
      
      y += rowHeight;
    });
    
    const tableHeight = headerHeight + (materiais.length * rowHeight);
    doc.roundedRect(margin, tableStartY, contentWidth, tableHeight, 4)
       .strokeColor('#d1d5db')
       .lineWidth(1)
       .stroke();
    
    x = margin + colWidths.numero;
    doc.moveTo(x, tableStartY)
       .lineTo(x, tableStartY + tableHeight)
       .strokeColor('#e5e7eb')
       .lineWidth(0.5)
       .stroke();
    
    x += colWidths.material;
    doc.moveTo(x, tableStartY)
       .lineTo(x, tableStartY + tableHeight)
       .strokeColor('#e5e7eb')
       .lineWidth(0.5)
       .stroke();
    
    x += colWidths.unidade;
    doc.moveTo(x, tableStartY)
       .lineTo(x, tableStartY + tableHeight)
       .strokeColor('#e5e7eb')
       .lineWidth(0.5)
       .stroke();
    
    x += colWidths.quantidade;
    doc.moveTo(x, tableStartY)
       .lineTo(x, tableStartY + tableHeight)
       .strokeColor('#e5e7eb')
       .lineWidth(0.5)
       .stroke();
    
    x += colWidths.valorUnit;
    doc.moveTo(x, tableStartY)
       .lineTo(x, tableStartY + tableHeight)
       .strokeColor('#e5e7eb')
       .lineWidth(0.5)
       .stroke();
    
    y += 8;
    
    // ✅ Subtotal Materiais
    const subtotalMateriais = materiais.reduce((sum, mat) => {
      return sum + this._calcularTotalItem(mat.quantidade, mat.materialCusto);
    }, 0);
    
    const subtotalBoxWidth = 200;
    const subtotalBoxX = pageWidth - margin - subtotalBoxWidth;
    
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

  // ✅ Tabela de sobras com coluna Unidade
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
      numero: contentWidth * 0.08,
      material: contentWidth * 0.50,
      unidade: contentWidth * 0.10,
      sobras: contentWidth * 0.16,
      total: contentWidth * 0.16
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
    
    doc.text('UNIDADE', x, y + 4.5, { width: colWidths.unidade, align: 'center' });
    x += colWidths.unidade;
    
    doc.text('SOBRAS', x, y + 4.5, { width: colWidths.sobras, align: 'center' });
    x += colWidths.sobras;
    
    doc.text('TOTAL', x, y + 4.5, { width: colWidths.total, align: 'center' });
    
    y += headerHeight;
    
    materiaisComSobras.forEach((material, index) => {
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
      
      // ✅ Coluna Unidade
      doc.fillColor('#6b7280')
         .fontSize(6)
         .text(material.materialUnidade, x, textY, { width: colWidths.unidade, align: 'center' });
      x += colWidths.unidade;
      
      // Formatar sobras em mm
      const sobraTexto = this._formatarSobras(material);
      doc.fillColor('#1f2937')
         .font('Helvetica-Bold')
         .fontSize(6)
         .text(sobraTexto, x, textY, { width: colWidths.sobras, align: 'center' });
      x += colWidths.sobras;
      
      doc.fillColor('#1f2937')
         .font('Helvetica-Bold')
         .fontSize(6)
         .text(this._formatarMoeda(material.valorSobra || 0), x, textY, { width: colWidths.total, align: 'center' });
      
      y += rowHeight;
    });
    
    const tableHeight = headerHeight + (materiaisComSobras.length * rowHeight);
    doc.roundedRect(margin, tableStartY, contentWidth, tableHeight, 4)
       .strokeColor('#d1d5db')
       .lineWidth(1)
       .stroke();
    
    x = margin + colWidths.numero;
    doc.moveTo(x, tableStartY)
       .lineTo(x, tableStartY + tableHeight)
       .strokeColor('#e5e7eb')
       .lineWidth(0.5)
       .stroke();
    
    x += colWidths.material;
    doc.moveTo(x, tableStartY)
       .lineTo(x, tableStartY + tableHeight)
       .strokeColor('#e5e7eb')
       .lineWidth(0.5)
       .stroke();
    
    x += colWidths.unidade;
    doc.moveTo(x, tableStartY)
       .lineTo(x, tableStartY + tableHeight)
       .strokeColor('#e5e7eb')
       .lineWidth(0.5)
       .stroke();
    
    x += colWidths.sobras;
    doc.moveTo(x, tableStartY)
       .lineTo(x, tableStartY + tableHeight)
       .strokeColor('#e5e7eb')
       .lineWidth(0.5)
       .stroke();
    
    y += 8;
    
    // ✅ Subtotal Sobras
    const subtotalSobras = materiaisComSobras.reduce((sum, mat) => {
      return sum + (mat.valorSobra || 0);
    }, 0);
    
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
      .text(this._formatarMoeda(subtotalSobras), subtotalBoxX + subtotalBoxWidth - 105, y, { 
        width: 80, 
        align: 'right' 
      });
    
    y += 15;
    
    return y;
  }

  _formatarSobras(material) {
    const altura = parseFloat(material.alturaSobra) || 0;
    const largura = parseFloat(material.larguraSobra) || 0;
    
    if (altura > 0 && largura > 0) {
      return `${altura} × ${largura} mm`;
    } else if (altura > 0) {
      return `${altura} mm`;
    } else if (largura > 0) {
      return `${largura} mm`;
    }
    
    return '-';
  }

  _desenharItensAdicionais(doc, data, type, currentY) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    const contentWidth = pageWidth - 2 * margin;
    let y = currentY;
    
    doc.fontSize(7)
      .font('Helvetica-Bold')
      .fillColor('#1a1a1a')
      .text('INFORMAÇÕES ADICIONAIS', margin, y);
    
    y += 10;
    
    const colWidths = {
      numero: contentWidth * 0.06,
      descricao: contentWidth * 0.74,
      valor: contentWidth * 0.20
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
    
    doc.text('VALOR', x, y + 4.5, { width: colWidths.valor, align: 'center' });
    
    y += headerHeight;
    
    let itemIndex = 0;
    
    if (data.despesasAdicionais && data.despesasAdicionais.length > 0) {
      data.despesasAdicionais.forEach((despesa) => {
        if (itemIndex % 2 === 0) {
          doc.rect(margin, y, contentWidth, rowHeight)
             .fillColor('#fafafa')
             .fill();
        }
        
        x = margin;
        const textY = y + 3.5;
        
        doc.fillColor('#6b7280')
           .font('Helvetica-Bold')
           .fontSize(6)
           .text((itemIndex + 1).toString(), x, textY, { width: colWidths.numero, align: 'center' });
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
        
        doc.fillColor('#1f2937')
           .font('Helvetica-Bold')
           .fontSize(6)
           .text(this._formatarMoeda(despesa.valor), x, textY, { width: colWidths.valor, align: 'center' });
        
        y += rowHeight;
        itemIndex++;
      });
    }
    
    if (data.opcoesExtras && data.opcoesExtras.length > 0) {
      data.opcoesExtras.forEach((opcao) => {
        if (itemIndex % 2 === 0) {
          doc.rect(margin, y, contentWidth, rowHeight)
             .fillColor('#fafafa')
             .fill();
        }
        
        x = margin;
        const textY = y + 3.5;
        
        doc.fillColor('#6b7280')
           .font('Helvetica-Bold')
           .fontSize(6)
           .text((itemIndex + 1).toString(), x, textY, { width: colWidths.numero, align: 'center' });
        x += colWidths.numero;
        
        let descricao = opcao.nome;
        let valorOpcao = 0;
        
        if (opcao.tipo === 'STRINGFLOAT') {
          descricao += `: ${opcao.valorString}`;
          valorOpcao = opcao.valorFloat1 || 0;
        } else if (opcao.tipo === 'FLOATFLOAT') {
          const valor1 = parseFloat(opcao.valorFloat1) || 0;
          const valor2 = parseFloat(opcao.valorFloat2) || 0;
          descricao += `: ${this._formatarHoras(valor1)} × ${this._formatarMoeda(valor2)}/hora`;
          valorOpcao = valor1 * valor2;
        } else if (opcao.tipo === 'PERCENTFLOAT') {
          const percentual = parseFloat(opcao.valorFloat1) || 0;
          const valorBase = parseFloat(opcao.valorFloat2) || 0;
          descricao += `: ${percentual}% de ${this._formatarMoeda(valorBase)}`;
          valorOpcao = (percentual / 100) * valorBase;
        }
        
        doc.fillColor('#1f2937')
           .font('Helvetica')
           .fontSize(6)
           .text(descricao, x + 6, textY, { 
             width: colWidths.descricao - 6, 
             align: 'left',
             lineBreak: false,
             ellipsis: true
           });
        x += colWidths.descricao;
        
        doc.fillColor('#1f2937')
           .font('Helvetica-Bold')
           .fontSize(6)
           .text(this._formatarMoeda(valorOpcao), x, textY, { width: colWidths.valor, align: 'center' });
        
        y += rowHeight;
        itemIndex++;
      });
    }
    
    const tableHeight = headerHeight + (itemIndex * rowHeight);
    doc.roundedRect(margin, tableStartY, contentWidth, tableHeight, 4)
       .strokeColor('#d1d5db')
       .lineWidth(1)
       .stroke();
    
    x = margin + colWidths.numero;
    doc.moveTo(x, tableStartY)
       .lineTo(x, tableStartY + tableHeight)
       .strokeColor('#e5e7eb')
       .lineWidth(0.5)
       .stroke();
    
    x += colWidths.descricao;
    doc.moveTo(x, tableStartY)
       .lineTo(x, tableStartY + tableHeight)
       .strokeColor('#e5e7eb')
       .lineWidth(0.5)
       .stroke();
    
    return y + 8;
  }

  _desenharInfoPagamentoETotal(doc, data, type, startY) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    const pageHeight = doc.page.height;
    const contentWidth = pageWidth - 2 * margin;
    let y = startY + 8;
    
    const footerHeight = 70;
    const paymentSectionHeight = 90;
    const spaceNeeded = paymentSectionHeight + footerHeight + 10;
    
    if (y + spaceNeeded > pageHeight) {
      doc.addPage();
      y = 30;
    }
    
    doc.fontSize(7)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text('INFORMAÇÕES DE PAGAMENTO', margin, y);
    
    y += 10;
    
    const colWidths = {
      formaPagamento: contentWidth * 0.33,
      condicoes: contentWidth * 0.34,
      prazo: contentWidth * 0.33
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
    doc.text('FORMA DE PAGAMENTO', x, y + 4.5, { width: colWidths.formaPagamento, align: 'center' });
    x += colWidths.formaPagamento;
    
    doc.text('CONDIÇÕES DE PAGAMENTO', x, y + 4.5, { width: colWidths.condicoes, align: 'center' });
    x += colWidths.condicoes;
    
    doc.text('PRAZO DE ENTREGA', x, y + 4.5, { width: colWidths.prazo, align: 'center' });
    
    y += headerHeight;
    
    doc.rect(margin, y, contentWidth, rowHeight)
       .fillColor('#fafafa')
       .fill();
    
    x = margin;
    const textY = y + 6;
    
    doc.fillColor('#1f2937')
       .font('Helvetica')
       .fontSize(6)
       .text(data.formaPagamento, x + 6, textY, { 
         width: colWidths.formaPagamento - 12, 
         align: 'left'
       });
    x += colWidths.formaPagamento;
    
    doc.fillColor('#1f2937')
       .font('Helvetica')
       .fontSize(6)
       .text(data.condicoesPagamento, x + 6, textY, { 
         width: colWidths.condicoes - 12, 
         align: 'left'
       });
    x += colWidths.condicoes;
    
    doc.fillColor('#1f2937')
       .font('Helvetica')
       .fontSize(6)
       .text(data.prazoEntrega, x + 6, textY, { 
         width: colWidths.prazo - 12, 
         align: 'left'
       });
    
    y += rowHeight;
    
    const tableHeight = headerHeight + rowHeight;
    doc.roundedRect(margin, tableStartY, contentWidth, tableHeight, 4)
       .strokeColor('#d1d5db')
       .lineWidth(1)
       .stroke();
    
    x = margin + colWidths.formaPagamento;
    doc.moveTo(x, tableStartY)
       .lineTo(x, tableStartY + tableHeight)
       .strokeColor('#e5e7eb')
       .lineWidth(0.5)
       .stroke();
    
    x += colWidths.condicoes;
    doc.moveTo(x, tableStartY)
       .lineTo(x, tableStartY + tableHeight)
       .strokeColor('#e5e7eb')
       .lineWidth(0.5)
       .stroke();
    
    y += 8;
    
    // ✅ Seção de total simplificada (sem breakdown)
    const totalBoxHeight = 40;
    doc.roundedRect(margin, y, contentWidth, totalBoxHeight, 4)
       .strokeColor('#d1d5db')
       .lineWidth(1)
       .stroke();
    
    let totalY = y + 8;
    
    // Total Geral direto
    doc.fontSize(6)
       .font('Helvetica-Bold')
       .fillColor('#6b7280')
       .text('VALOR TOTAL', margin, totalY, {
         width: contentWidth, 
         align: 'center' 
       });
    
    doc.fontSize(14)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text(this._formatarMoeda(data.total), margin, totalY + 11, {
         width: contentWidth, 
         align: 'center' 
       });
    
    y += totalBoxHeight + 8;
    
    // ✅ Valor Sugerido (se disponível)
    if (data.valorSugerido && data.valorSugerido.valorSugerido) {
      const sugeridoBoxHeight = 50;
      
      doc.roundedRect(margin, y, contentWidth, sugeridoBoxHeight, 4)
         .fillAndStroke('#e0f2fe', '#0284c7');
      
      doc.fontSize(6)
         .font('Helvetica-Bold')
         .fillColor('#0369a1')
         .text('VALOR SUGERIDO', margin, y + 8, {
           width: contentWidth, 
           align: 'center' 
         });
      
      doc.fontSize(12)
         .font('Helvetica-Bold')
         .fillColor('#0c4a6e')
         .text(this._formatarMoeda(data.valorSugerido.valorSugerido), margin, y + 19, {
           width: contentWidth, 
           align: 'center' 
         });
      
      doc.fontSize(5)
         .font('Helvetica')
         .fillColor('#0369a1')
         .text(
           `Margem de ${data.valorSugerido.margem}% aplicada sobre ${this._formatarMoeda(data.valorSugerido.custoTotal)}`,
           margin,
           y + 36,
           {
             width: contentWidth,
             align: 'center'
           }
         );
      
      y += sugeridoBoxHeight;
    }
    
    return y;
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

  _formatarMoeda(valor){
    return new Intl.NumberFormat('pt-BR', {
      style: 'currency',
      currency: 'BRL'
    }).format(valor);
  }

  _formatarQuantidade(quantidade, unidade) {
    const num = parseFloat(quantidade.toString().replace(',', '.'));
    
    return num.toString();
  }

  _formatarHoras(horas) {
    const num = parseFloat(horas.toString().replace(',', '.'));
    
    const isInteiro = num % 1 === 0;
    const valorFormatado = isInteiro ? num.toString() : num.toFixed(2).replace('.', ',');
    
    const texto = num === 1 ? 'hora' : 'horas';
    
    return `${valorFormatado} ${texto}`;
  }

  _calcularTotalItem(quantidade, custo) {
    const qty = parseFloat(quantidade.toString().replace(',', '.'));
    return qty * custo;
  }
}

module.exports = new PdfLayout();