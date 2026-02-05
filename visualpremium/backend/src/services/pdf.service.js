const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');

class PdfService {
  gerarDocumento(data, type = 'orcamento') {
    const doc = new PDFDocument({ margin: 30, size: 'A4' });

    const logoPath = path.join(__dirname, '../../../assets/images/logo preta.png');
    const titulo = type === 'orcamento' ? 'Orçamento' : 'Pedido';
    
    let currentY = this._desenharHeader(doc, logoPath, data.numero, titulo);
    currentY = this._desenharInfoPrincipal(doc, data.cliente, data.produtoNome, currentY);
    currentY = this._desenharTabelaMateriais(doc, data.materiais, currentY);
    
    // ✅ FILTRAR opções extras para verificar se há alguma com valores
    const opcoesExtrasComValores = (data.opcoesExtras || []).filter(opcao => {
      return opcao.valorString != null || 
            opcao.valorFloat1 != null || 
            opcao.valorFloat2 != null;
    });
    
    // ✅ Verificar se há itens adicionais REAIS para desenhar
    const temItensAdicionais = 
      (data.despesasAdicionais?.length > 0) || 
      (opcoesExtrasComValores.length > 0) ||
      (data.frete && type === 'pedido') || 
      (data.caminhaoMunck && type === 'pedido');
    
    if (temItensAdicionais) {
      currentY = this._desenharItensAdicionais(doc, data, type, currentY);
    }
    
    currentY = this._desenharInfoPagamentoETotal(doc, data, type, currentY);
    this._desenharFooter(doc);
    
    doc.end();
    return doc;
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
    
    const numeroStr = numero !== null && numero !== undefined 
      ? numero.toString() 
      : 'S/N';
    
    const now = new Date();
    const dataFormatada = now.toLocaleDateString('pt-BR');
    const horaFormatada = now.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
    const dataHoraStr = `${dataFormatada} ${horaFormatada}`;
    
    const infoBlockWidth = 120;
    const infoBlockX = pageWidth - margin - infoBlockWidth;
    
    doc.fontSize(8)
       .font('Helvetica')
       .fillColor('#666')
       .text(titulo, infoBlockX, y, { width: infoBlockWidth, align: 'center' });
    
    doc.fontSize(22)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text(numeroStr, infoBlockX, y + 11, { width: infoBlockWidth, align: 'center' });
    
    doc.fontSize(7)
       .font('Helvetica')
       .fillColor('#666666')
       .text(dataHoraStr, infoBlockX, y + 35, { width: infoBlockWidth, align: 'center' });
    
    y = 78;
    doc.moveTo(margin, y)
       .lineTo(pageWidth - margin, y)
       .strokeColor('#d1d5db')
       .lineWidth(1)
       .stroke();
    
    return y + 6;
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
    
    // Ajustar larguras para ocupar 100% do espaço
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
    doc.text('#', x, y + 4.5, {
      width: colWidths.numero, 
      align: 'center' 
    });
    x += colWidths.numero;
    
    doc.text('MATERIAL', x, y + 4.5, { 
      width: colWidths.material, 
      align: 'center' 
    });
    x += colWidths.material;
    
    doc.text('UN', x, y + 4.5, { 
      width: colWidths.unidade, 
      align: 'center' 
    });
    x += colWidths.unidade;
    
    doc.text('QTD', x, y + 4.5, {
      width: colWidths.quantidade, 
      align: 'center' 
    });
    x += colWidths.quantidade;
    
    doc.text('CUSTO', x, y + 4.5, { 
      width: colWidths.valorUnit, 
      align: 'center' 
    });
    x += colWidths.valorUnit;
    
    doc.text('TOTAL', x, y + 4.5, { 
      width: colWidths.total, 
      align: 'center' 
    });
    
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
         .text((index + 1).toString(), x, textY, { 
           width: colWidths.numero, 
           align: 'center' 
         });
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
         .text(material.materialUnidade, x, textY, { 
           width: colWidths.unidade, 
           align: 'center' 
         });
      x += colWidths.unidade;
      
      const quantidade = this._formatarQuantidade(material.quantidade, material.materialUnidade);
      doc.fillColor('#1f2937')
         .font('Helvetica-Bold')
         .fontSize(6)
         .text(quantidade, x, textY, { 
           width: colWidths.quantidade, 
           align: 'center' 
         });
      x += colWidths.quantidade;
      
      doc.fillColor('#6b7280')
         .font('Helvetica')
         .fontSize(6)
         .text(this._formatarMoeda(material.materialCusto), x, textY, { 
           width: colWidths.valorUnit, 
           align: 'center' 
         });
      x += colWidths.valorUnit;
      
      const totalItem = this._calcularTotalItem(material.quantidade, material.materialCusto);
      doc.fillColor('#1f2937')
         .font('Helvetica-Bold')
         .fontSize(6)
         .text(this._formatarMoeda(totalItem), x, textY, { 
           width: colWidths.total, 
           align: 'center' 
         });
      
      y += rowHeight;
    });
    
    const tableHeight = headerHeight + (materiais.length * rowHeight);
    doc.roundedRect(margin, tableStartY, contentWidth, tableHeight, 4)
       .strokeColor('#d1d5db')
       .lineWidth(1)
       .stroke();
    
    // Linhas verticais
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
    
    return y + 8;
  }

  _desenharItensAdicionais(doc, data, type, currentY) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    const contentWidth = pageWidth - 2 * margin;
    let y = currentY;
    
    // Calcular e mostrar subtotal
    let subtotal = 0;
    data.materiais.forEach(mat => {
      subtotal += this._calcularTotalItem(mat.quantidade, mat.materialCusto);
    });
    
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
      .text(this._formatarMoeda(subtotal), subtotalBoxX + subtotalBoxWidth - 105, y, { 
        width: 80, 
        align: 'right' 
      });
    
    y += 15;
    
    // ✅ FILTRAR opções extras para remover as marcadas como "Não"
    const opcoesExtrasComValores = (data.opcoesExtras || []).filter(opcao => {
      // Verificar se tem pelo menos um valor não-nulo
      return opcao.valorString != null || 
            opcao.valorFloat1 != null || 
            opcao.valorFloat2 != null;
    });
    
    // ✅ VERIFICAR se há itens para mostrar (despesas OU opções extras com valores)
    const temDespesas = data.despesasAdicionais && data.despesasAdicionais.length > 0;
    const temOpcoesExtras = opcoesExtrasComValores.length > 0;
    const temFrete = type === 'pedido' && data.frete && data.freteDesc && data.freteValor;
    const temMunck = type === 'pedido' && data.caminhaoMunck && data.caminhaoMunckHoras && data.caminhaoMunckValorHora;
    
    // ✅ SE NÃO HOUVER NADA PARA MOSTRAR, RETORNAR SEM DESENHAR A SEÇÃO
    if (!temDespesas && !temOpcoesExtras && !temFrete && !temMunck) {
      return y;
    }
    
    // Se chegou aqui, há algo para mostrar
    doc.fontSize(7)
      .font('Helvetica-Bold')
      .fillColor('#1a1a1a')
      .text('INFORMAÇÕES ADICIONAIS', margin, y);
    
    y += 10;
    
    const boxStartY = y;
    const padding = 9;
    const lineSpacing = 9;
    let boxContentY = y + padding;
    let needsDivider = false;
    
    // Desenhar despesas adicionais
    if (temDespesas) {
      const titulo = data.despesasAdicionais.length === 1 ? 'DESPESA ADICIONAL' : 'DESPESAS ADICIONAIS';
      
      doc.fontSize(6)
        .font('Helvetica-Bold')
        .fillColor('#6b7280')
        .text(titulo, margin + padding, boxContentY);
      
      boxContentY += 9;
      
      data.despesasAdicionais.forEach((despesa, index) => {
        const numeroWidth = 20;
        const itemStartY = boxContentY;
        
        doc.fontSize(6)
          .font('Helvetica-Bold')
          .fillColor('#6b7280')
          .text(`${index + 1}.`, margin + padding, boxContentY, { 
            width: numeroWidth, 
            align: 'left' 
          });
        
        doc.fontSize(6)
          .font('Helvetica')
          .fillColor('#1f2937')
          .text(despesa.descricao, margin + padding + numeroWidth, boxContentY, { 
            width: contentWidth - 2 * padding - numeroWidth - 100 
          });
        
        const descricaoEndY = doc.y;
        
        doc.fontSize(6)
          .font('Helvetica-Bold')
          .fillColor('#1a1a1a')
          .text(this._formatarMoeda(despesa.valor), pageWidth - margin - padding - 90, itemStartY, { 
            width: 90, 
            align: 'right' 
          });
        
        boxContentY = Math.max(descricaoEndY, doc.y) + lineSpacing;
        
        if (index < data.despesasAdicionais.length - 1) {
          doc.moveTo(margin + padding, boxContentY - lineSpacing/2)
            .lineTo(pageWidth - margin - padding, boxContentY - lineSpacing/2)
            .strokeColor('#e5e7eb')
            .lineWidth(0.5)
            .stroke();
        }
      });
      
      needsDivider = true;
    }
    
    // ✅ Desenhar apenas opções extras COM VALORES
    if (temOpcoesExtras) {
      if (needsDivider) {
        doc.moveTo(margin + padding, boxContentY - lineSpacing/2)
          .lineTo(pageWidth - margin - padding, boxContentY - lineSpacing/2)
          .strokeColor('#e5e7eb')
          .lineWidth(0.5)
          .stroke();
      }
      
      const titulo = opcoesExtrasComValores.length === 1 ? 'OPÇÃO EXTRA' : 'OPÇÕES EXTRAS';
      
      doc.fontSize(6)
        .font('Helvetica-Bold')
        .fillColor('#6b7280')
        .text(titulo, margin + padding, boxContentY);
      
      boxContentY += 9;
      
      opcoesExtrasComValores.forEach((opcao, index) => {
        const numeroWidth = 20;
        const itemStartY = boxContentY;
        
        doc.fontSize(6)
          .font('Helvetica-Bold')
          .fillColor('#6b7280')
          .text(`${index + 1}.`, margin + padding, boxContentY, { 
            width: numeroWidth, 
            align: 'left' 
          });
        
        let descricao = opcao.nome;
        let valorOpcao = 0;
        
        if (opcao.tipo === 'STRINGFLOAT') {
          descricao += `: ${opcao.valorString}`;
          valorOpcao = opcao.valorFloat1 || 0;
        } else if (opcao.tipo === 'FLOATFLOAT') {
          const valor1 = parseFloat(opcao.valorFloat1) || 0;
          const valor2 = parseFloat(opcao.valorFloat2) || 0;
          descricao += `: ${this._formatarQuantidade(valor1, 'un')} × ${this._formatarMoeda(valor2)}`;
          valorOpcao = valor1 * valor2;
        } else if (opcao.tipo === 'PERCENTFLOAT') {
          const percentual = parseFloat(opcao.valorFloat1) || 0;
          const valorBase = parseFloat(opcao.valorFloat2) || 0;
          descricao += `: ${percentual}% de ${this._formatarMoeda(valorBase)}`;
          valorOpcao = (percentual / 100) * valorBase;
        }
        
        doc.fontSize(6)
          .font('Helvetica')
          .fillColor('#1f2937')
          .text(descricao, margin + padding + numeroWidth, boxContentY, { 
            width: contentWidth - 2 * padding - numeroWidth - 100 
          });
        
        const descricaoEndY = doc.y;
        
        doc.fontSize(6)
          .font('Helvetica-Bold')
          .fillColor('#1a1a1a')
          .text(this._formatarMoeda(valorOpcao), pageWidth - margin - padding - 90, itemStartY, { 
            width: 90, 
            align: 'right' 
          });
        
        boxContentY = Math.max(descricaoEndY, doc.y) + lineSpacing;
        
        if (index < opcoesExtrasComValores.length - 1) {
          doc.moveTo(margin + padding, boxContentY - lineSpacing/2)
            .lineTo(pageWidth - margin - padding, boxContentY - lineSpacing/2)
            .strokeColor('#e5e7eb')
            .lineWidth(0.5)
            .stroke();
        }
      });
      
      needsDivider = true;
    }
    
    // Desenhar frete (apenas para pedido)
    if (temFrete) {
      if (needsDivider) {
        doc.moveTo(margin + padding, boxContentY - lineSpacing/2)
          .lineTo(pageWidth - margin - padding, boxContentY - lineSpacing/2)
          .strokeColor('#e5e7eb')
          .lineWidth(0.5)
          .stroke();
      }
      
      doc.fontSize(6)
        .font('Helvetica-Bold')
        .fillColor('#6b7280')
        .text('FRETE', margin + padding, boxContentY);
      
      boxContentY += 9;
      
      const itemStartY = boxContentY;
      
      doc.fontSize(6)
        .font('Helvetica')
        .fillColor('#1f2937')
        .text(data.freteDesc, margin + padding, boxContentY, { 
          width: contentWidth - 2 * padding - 100 
        });
      
      const freteDescEndY = doc.y;
      
      doc.fontSize(6)
        .font('Helvetica-Bold')
        .fillColor('#1a1a1a')
        .text(this._formatarMoeda(data.freteValor), pageWidth - margin - padding - 90, itemStartY, { 
          width: 90, 
          align: 'right' 
        });
      
      boxContentY = Math.max(freteDescEndY, doc.y) + lineSpacing;
      needsDivider = true;
    }
    
    // Desenhar caminhão munck (apenas para pedido)
    if (temMunck) {
      if (needsDivider) {
        doc.moveTo(margin + padding, boxContentY - lineSpacing/2)
          .lineTo(pageWidth - margin - padding, boxContentY - lineSpacing/2)
          .strokeColor('#e5e7eb')
          .lineWidth(0.5)
          .stroke();
      }
      
      doc.fontSize(6)
        .font('Helvetica-Bold')
        .fillColor('#6b7280')
        .text('CAMINHÃO MUNCK', margin + padding, boxContentY);
      
      boxContentY += 9;
      
      const itemStartY = boxContentY;
      
      const horas = data.caminhaoMunckHoras;
      const valorHora = data.caminhaoMunckValorHora;
      const totalMunck = data.caminhaoMunckTotal || (horas * valorHora);
      
      doc.fontSize(6)
        .font('Helvetica')
        .fillColor('#1f2937')
        .text(`${this._formatarQuantidade(horas, 'h')} horas × ${this._formatarMoeda(valorHora)}/hora`, 
                margin + padding, boxContentY, { 
                  width: contentWidth - 2 * padding - 100 
                });
      
      const munckDescEndY = doc.y;
      
      doc.fontSize(6)
        .font('Helvetica-Bold')
        .fillColor('#1a1a1a')
        .text(this._formatarMoeda(totalMunck), pageWidth - margin - padding - 90, itemStartY, { 
          width: 90, 
          align: 'right' 
        });
      
      boxContentY = Math.max(munckDescEndY, doc.y) + lineSpacing;
    }
    
    const boxHeight = boxContentY - boxStartY + padding - lineSpacing;
    doc.roundedRect(margin, boxStartY, contentWidth, boxHeight, 4)
      .strokeColor('#d1d5db')
      .lineWidth(1)
      .stroke();
    
    return boxContentY + padding;
  }

  _desenharInfoPagamentoETotal(doc, data, type, startY) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    const pageHeight = doc.page.height;
    const contentWidth = pageWidth - 2 * margin;
    let y = startY + 8;
    
    // Verificar se há espaço suficiente para a seção de pagamento + total + footer
    const footerHeight = 70;
    const paymentSectionHeight = 90; // Altura aproximada da seção
    const spaceNeeded = paymentSectionHeight + footerHeight + 10; // +10 de margem de segurança
    
    if (y + spaceNeeded > pageHeight) {
      doc.addPage();
      y = 30; // Resetar Y para o topo da nova página
    }
    
    doc.fontSize(7)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text('INFORMAÇÕES DE PAGAMENTO', margin, y);
    
    y += 10;
    
    const boxStartY = y;
    const padding = 9;
    const infoHeight = 40;
    const totalHeight = 40;
    const totalBoxHeight = infoHeight + totalHeight;
    
    doc.roundedRect(margin, y, contentWidth, totalBoxHeight, 4)
       .strokeColor('#d1d5db')
       .lineWidth(1)
       .stroke();
    
    const thirdWidth = (contentWidth - 2 * padding - 20) / 3;
    const col1X = margin + padding;
    const col2X = margin + padding + thirdWidth + 10;
    const col3X = margin + padding + 2 * (thirdWidth + 10);
    
    doc.fontSize(6)
       .font('Helvetica-Bold')
       .fillColor('#6b7280')
       .text('FORMA DE PAGAMENTO', col1X, y + padding);
    
    doc.fontSize(6)
       .font('Helvetica')
       .fillColor('#1f2937')
       .text(data.formaPagamento, col1X, y + padding + 8, { 
         width: thirdWidth, 
         align: 'left' 
       });
    
    const divider1X = col1X + thirdWidth + 5;
    doc.moveTo(divider1X, y + padding)
       .lineTo(divider1X, y + infoHeight - padding)
       .strokeColor('#e5e7eb')
       .lineWidth(0.5)
       .stroke();
    
    doc.fontSize(6)
       .font('Helvetica-Bold')
       .fillColor('#6b7280')
       .text('CONDIÇÕES DE PAGAMENTO', col2X, y + padding);
    
    doc.fontSize(6)
       .font('Helvetica')
       .fillColor('#1f2937')
       .text(data.condicoesPagamento, col2X, y + padding + 8, { 
         width: thirdWidth, 
         align: 'left' 
       });
    
    const divider2X = col2X + thirdWidth + 5;
    doc.moveTo(divider2X, y + padding)
       .lineTo(divider2X, y + infoHeight - padding)
       .strokeColor('#e5e7eb')
       .lineWidth(0.5)
       .stroke();
    
    doc.fontSize(6)
       .font('Helvetica-Bold')
       .fillColor('#6b7280')
       .text('PRAZO DE ENTREGA', col3X, y + padding);
    
    doc.fontSize(6)
       .font('Helvetica')
       .fillColor('#1f2937')
       .text(data.prazoEntrega, col3X, y + padding + 8, { 
         width: thirdWidth, 
         align: 'left' 
       });
    
    y += infoHeight;
    doc.moveTo(margin, y)
       .lineTo(pageWidth - margin, y)
       .strokeColor('#d1d5db')
       .lineWidth(1)
       .stroke();
    
    // Calcular total geral
    let totalGeral = 0;
    
    data.materiais.forEach(mat => {
      totalGeral += this._calcularTotalItem(mat.quantidade, mat.materialCusto);
    });
    
    if (data.despesasAdicionais && data.despesasAdicionais.length > 0) {
      totalGeral += data.despesasAdicionais.reduce((sum, d) => sum + d.valor, 0);
    }
    
    if (data.opcoesExtras && data.opcoesExtras.length > 0) {
      data.opcoesExtras.forEach(opcao => {
        let valorOpcao = 0;
        
        if (opcao.tipo === 'STRINGFLOAT') {
          valorOpcao = parseFloat(opcao.valorFloat1) || 0;
        } else if (opcao.tipo === 'FLOATFLOAT') {
          const valor1 = parseFloat(opcao.valorFloat1) || 0;
          const valor2 = parseFloat(opcao.valorFloat2) || 0;
          valorOpcao = valor1 * valor2;
        } else if (opcao.tipo === 'PERCENTFLOAT') {
          const percentual = parseFloat(opcao.valorFloat1) || 0;
          const valorBase = parseFloat(opcao.valorFloat2) || 0;
          valorOpcao = (percentual / 100) * valorBase;
        }
        
        totalGeral += valorOpcao;
      });
    }
    
    if (type === 'pedido' && data.freteValor) {
      totalGeral += data.freteValor;
    }
    
    if (type === 'pedido' && data.caminhaoMunck && data.caminhaoMunckHoras && data.caminhaoMunckValorHora) {
      const totalMunck = data.caminhaoMunckTotal || (data.caminhaoMunckHoras * data.caminhaoMunckValorHora);
      totalGeral += totalMunck;
    }
    
    doc.fontSize(6)
       .font('Helvetica-Bold')
       .fillColor('#6b7280')
       .text('VALOR TOTAL', margin + padding, y + 8, {
         width: contentWidth - 2 * padding, 
         align: 'center' 
       });
    
    doc.fontSize(14)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text(this._formatarMoeda(totalGeral), margin + padding, y + 19, {
         width: contentWidth - 2 * padding, 
         align: 'center' 
       });
    
    return y + totalHeight;
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