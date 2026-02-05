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
    
    // Verificar se há itens adicionais para desenhar (apenas despesas e opções extras do produto)
    const temItensAdicionais = 
      (data.despesasAdicionais?.length > 0) || 
      (data.opcoesExtras?.length > 0);
    
    if (temItensAdicionais) {
      this._desenharItensAdicionais(doc, data);
    }
    
    // Desenhar frete e caminhão munck separadamente (apenas para pedido)
    if (type === 'pedido') {
      const temFreteOuMunck = 
        (data.frete && data.freteDesc && data.freteValor) ||
        (data.caminhaoMunck && data.caminhaoMunckHoras && data.caminhaoMunckValorHora);
      
      if (temFreteOuMunck) {
        this._desenharFreteEMunck(doc, data);
      }
    }
    
    this._desenharInfoPagamentoETotal(doc, data, type);
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
       .text(titulo, infoBlockX, 35, { width: infoBlockWidth, align: 'center' });
    
    doc.fontSize(22)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text(numeroStr, infoBlockX, 46, { width: infoBlockWidth, align: 'center' });
    
    doc.fontSize(7)
       .font('Helvetica')
       .fillColor('#666666')
       .text(dataHoraStr, infoBlockX, 70, { width: infoBlockWidth, align: 'center' });
    
    doc.moveTo(margin, 88)
       .lineTo(pageWidth - margin, 88)
       .strokeColor('#d1d5db')
       .lineWidth(1)
       .stroke();
  }

  _desenharInfoPrincipal(doc, cliente, produto) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    const contentWidth = pageWidth - 2 * margin;
    let y = 98;
    
    const cardHeight = 70;
    const padding = 12;
    
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
       .text(cliente, margin + padding, y + padding + 10, { 
         width: contentWidth - 2 * padding, 
         align: 'left' 
       });
    
    doc.fontSize(6)
       .font('Helvetica-Bold')
       .fillColor('#6b7280')
       .text('PRODUTO', margin + padding, y + padding + 28);
    
    doc.fontSize(8)
       .font('Helvetica')
       .fillColor('#1f2937')
       .text(produto, margin + padding, y + padding + 38, { 
         width: contentWidth - 2 * padding, 
         align: 'left' 
       });
  }

  _desenharTabelaMateriais(doc, materiais) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    const contentWidth = pageWidth - 2 * margin;
    let y = 180;
    
    doc.fontSize(8)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text('MATERIAIS', margin, y);
    
    y += 16;
    
    const colWidths = {
      numero: contentWidth * 0.06,
      material: contentWidth * 0.42,
      unidade: contentWidth * 0.10,
      quantidade: contentWidth * 0.14,
      valorUnit: contentWidth * 0.14,
      total: contentWidth * 0.14
    };
    
    const tableStartY = y;
    const headerHeight = 20;
    const rowHeight = 18;
    
    doc.roundedRect(margin, y, contentWidth, headerHeight, 3)
       .fillAndStroke('#f3f4f6', '#d1d5db');
    
    doc.fontSize(6)
       .font('Helvetica-Bold')
       .fillColor('#374151');
    
    let x = margin;
    doc.text('#', x, y + 7, { 
      width: colWidths.numero, 
      align: 'center' 
    });
    x += colWidths.numero;
    
    doc.text('MATERIAL', x, y + 7, { 
      width: colWidths.material, 
      align: 'center' 
    });
    x += colWidths.material;
    
    doc.text('UN', x, y + 7, { 
      width: colWidths.unidade, 
      align: 'center' 
    });
    x += colWidths.unidade;
    
    doc.text('QUANTIDADE', x, y + 7, { 
      width: colWidths.quantidade, 
      align: 'center' 
    });
    x += colWidths.quantidade;
    
    doc.text('CUSTO', x, y + 7, { 
      width: colWidths.valorUnit, 
      align: 'center' 
    });
    x += colWidths.valorUnit;
    
    doc.text('TOTAL', x, y + 7, { 
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
      const textY = y + 6;
      
      doc.fillColor('#6b7280')
         .font('Helvetica-Bold')
         .fontSize(7)
         .text((index + 1).toString(), x, textY, { 
           width: colWidths.numero, 
           align: 'center' 
         });
      x += colWidths.numero;
      
      doc.fillColor('#1f2937')
         .font('Helvetica')
         .fontSize(7)
         .text(material.materialNome, x + 10, textY, { 
           width: colWidths.material - 10, 
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
         .fontSize(7)
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
         .fontSize(7)
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
    
    return y;
  }

  _desenharItensAdicionais(doc, data) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    const contentWidth = pageWidth - 2 * margin;
    let y = doc.y + 15;
    
    let subtotal = 0;
    data.materiais.forEach(mat => {
      subtotal += this._calcularTotalItem(mat.quantidade, mat.materialCusto);
    });
    
    const subtotalBoxWidth = 200;
    const subtotalBoxX = pageWidth - margin - subtotalBoxWidth;
    
    doc.fontSize(7)
      .font('Helvetica')
      .fillColor('#6b7280')
      .text('Subtotal Materiais', subtotalBoxX, y, { 
        width: subtotalBoxWidth - 87, 
        align: 'right' 
      });
    
    doc.fontSize(8)
      .font('Helvetica-Bold')
      .fillColor('#1f2937')
      .text(this._formatarMoeda(subtotal), subtotalBoxX + subtotalBoxWidth - 105, y, { 
        width: 80, 
        align: 'right' 
      });
    
    y += 25;
    
    doc.fontSize(8)
      .font('Helvetica-Bold')
      .fillColor('#1a1a1a')
      .text('INFORMAÇÕES ADICIONAIS DO PRODUTO', margin, y);
    
    y += 16;
    
    const boxStartY = y;
    const padding = 12;
    const lineSpacing = 12;
    let boxContentY = y + padding;
    let needsDivider = false;
    
    // Desenhar despesas adicionais
    if (data.despesasAdicionais && data.despesasAdicionais.length > 0) {
      const titulo = data.despesasAdicionais.length === 1 ? 'DESPESA ADICIONAL' : 'DESPESAS ADICIONAIS';
      
      doc.fontSize(6)
        .font('Helvetica-Bold')
        .fillColor('#6b7280')
        .text(titulo, margin + padding, boxContentY);
      
      boxContentY += 12;
      
      data.despesasAdicionais.forEach((despesa, index) => {
        const numeroWidth = 20;
        const itemStartY = boxContentY;
        
        doc.fontSize(7)
          .font('Helvetica-Bold')
          .fillColor('#6b7280')
          .text(`${index + 1}.`, margin + padding, boxContentY, { 
            width: numeroWidth, 
            align: 'left' 
          });
        
        doc.fontSize(7)
          .font('Helvetica')
          .fillColor('#1f2937')
          .text(despesa.descricao, margin + padding + numeroWidth, boxContentY, { 
            width: contentWidth - 2 * padding - numeroWidth - 100 
          });
        
        const descricaoEndY = doc.y;
        
        doc.fontSize(7)
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
    
    // Desenhar opções extras
    if (data.opcoesExtras && data.opcoesExtras.length > 0) {
      if (needsDivider) {
        doc.moveTo(margin + padding, boxContentY - lineSpacing/2)
          .lineTo(pageWidth - margin - padding, boxContentY - lineSpacing/2)
          .strokeColor('#e5e7eb')
          .lineWidth(0.5)
          .stroke();
      }
      
      const titulo = data.opcoesExtras.length === 1 ? 'OPÇÃO EXTRA' : 'OPÇÕES EXTRAS';
      
      doc.fontSize(6)
        .font('Helvetica-Bold')
        .fillColor('#6b7280')
        .text(titulo, margin + padding, boxContentY);
      
      boxContentY += 12;
      
      data.opcoesExtras.forEach((opcao, index) => {
        const numeroWidth = 20;
        const itemStartY = boxContentY;
        
        doc.fontSize(7)
          .font('Helvetica-Bold')
          .fillColor('#6b7280')
          .text(`${index + 1}.`, margin + padding, boxContentY, { 
            width: numeroWidth, 
            align: 'left' 
          });
        
        // ✅ Montar descrição baseada no tipo
        let descricao = opcao.nome;
        let valorOpcao = 0;
        
        if (opcao.tipo === 'STRING_FLOAT') {
          descricao += `: ${opcao.valorString}`;
          valorOpcao = opcao.valorFloat1 || 0;
        } else if (opcao.tipo === 'FLOAT_FLOAT' && opcao.valorFloat1 && opcao.valorFloat2) {
          // Verificar se a opção representa tempo (minutos) × custo/hora
          const ehTempo = opcao.nome.toLowerCase().includes('hora') || 
                          opcao.nome.toLowerCase().includes('tempo') ||
                          opcao.nome.toLowerCase().includes('munck') ||
                          opcao.nome.toLowerCase().includes('caminhão');
          
          if (ehTempo) {
            // ✅ FORMATO: "120 min (2 horas) × 3"
            const minutos = opcao.valorFloat1;
            const horas = minutos / 60;
            const horasTexto = horas % 1 === 0 ? horas.toFixed(0) : horas.toFixed(1);
            const custoFormatado = this._formatarQuantidade(opcao.valorFloat2, 'un');
            
            descricao += `: ${minutos} min (${horasTexto} horas) × ${custoFormatado}`;
            valorOpcao = horas * opcao.valorFloat2;
          } else {
            // Formato normal para outros tipos de FLOAT_FLOAT
            const val1 = this._formatarQuantidade(opcao.valorFloat1, 'un');
            const val2 = this._formatarQuantidade(opcao.valorFloat2, 'un');
            descricao += `: ${val1} × ${val2}`;
            valorOpcao = opcao.valorFloat1 * opcao.valorFloat2;
          }
        } else if (opcao.valorFloat1) {
          valorOpcao = opcao.valorFloat1;
        }
        
        doc.fontSize(7)
          .font('Helvetica')
          .fillColor('#1f2937')
          .text(descricao, margin + padding + numeroWidth, boxContentY, { 
            width: contentWidth - 2 * padding - numeroWidth - 100 
          });
        
        const descricaoEndY = doc.y;
        
        doc.fontSize(7)
          .font('Helvetica-Bold')
          .fillColor('#1a1a1a')
          .text(this._formatarMoeda(valorOpcao), pageWidth - margin - padding - 90, itemStartY, { 
            width: 90, 
            align: 'right' 
          });
        
        boxContentY = Math.max(descricaoEndY, doc.y) + lineSpacing;
        
        if (index < data.opcoesExtras.length - 1) {
          doc.moveTo(margin + padding, boxContentY - lineSpacing/2)
            .lineTo(pageWidth - margin - padding, boxContentY - lineSpacing/2)
            .strokeColor('#e5e7eb')
            .lineWidth(0.5)
            .stroke();
        }
      });
    }
    
    const boxHeight = boxContentY - boxStartY + padding - lineSpacing;
    doc.roundedRect(margin, boxStartY, contentWidth, boxHeight, 4)
      .strokeColor('#d1d5db')
      .lineWidth(1)
      .stroke();
  }

  _desenharFreteEMunck(doc, data) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    const contentWidth = pageWidth - 2 * margin;
    let y = doc.y + 15;
    
    doc.fontSize(8)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text('SERVIÇOS ADICIONAIS', margin, y);
    
    y += 16;
    
    const boxStartY = y;
    const padding = 12;
    const lineSpacing = 12;
    let boxContentY = y + padding;
    let needsDivider = false;
    
    // Desenhar frete
    if (data.frete && data.freteDesc && data.freteValor) {
      doc.fontSize(6)
         .font('Helvetica-Bold')
         .fillColor('#6b7280')
         .text('FRETE', margin + padding, boxContentY);
      
      boxContentY += 12;
      
      const itemStartY = boxContentY;
      
      doc.fontSize(7)
         .font('Helvetica')
         .fillColor('#1f2937')
         .text(data.freteDesc, margin + padding, boxContentY, { 
           width: contentWidth - 2 * padding - 100 
         });
      
      const freteDescEndY = doc.y;
      
      doc.fontSize(7)
         .font('Helvetica-Bold')
         .fillColor('#1a1a1a')
         .text(this._formatarMoeda(data.freteValor), pageWidth - margin - padding - 90, itemStartY, { 
           width: 90, 
           align: 'right' 
           });
      
      boxContentY = Math.max(freteDescEndY, doc.y) + lineSpacing;
      needsDivider = true;
    }
    
    // Desenhar caminhão munck
    if (data.caminhaoMunck && data.caminhaoMunckHoras && data.caminhaoMunckValorHora) {
      if (needsDivider) {
        doc.moveTo(margin + padding, boxContentY - lineSpacing/2)
           .lineTo(pageWidth - margin - padding, boxContentY - lineSpacing/2)
           .strokeColor('#e5e7eb')
           .lineWidth(0.5)
           .stroke();
      }
      
      // ✅ O valor no banco JÁ está em MINUTOS, então converter para horas para exibir
      const minutos = data.caminhaoMunckHoras; // valor em minutos
      const horas = minutos / 60; // converter para horas
      const totalMunck = horas * data.caminhaoMunckValorHora; // calcular total
      
      doc.fontSize(6)
         .font('Helvetica-Bold')
         .fillColor('#6b7280')
         .text('CAMINHÃO MUNCK', margin + padding, boxContentY);
      
      boxContentY += 12;
      
      const itemStartY = boxContentY;
      
      // Mostrar minutos e horas convertidas
      const horasFormatadas = horas.toFixed(2).replace('.', ',');
      doc.fontSize(7)
         .font('Helvetica')
         .fillColor('#1f2937')
         .text(
           `${minutos} min (${horasFormatadas}h) × ${this._formatarMoeda(data.caminhaoMunckValorHora)}/h`, 
           margin + padding, 
           boxContentY, 
           { width: contentWidth - 2 * padding - 100 }
         );
      
      const munckDescEndY = doc.y;
      
      doc.fontSize(7)
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
  }

  _desenharInfoPagamentoETotal(doc, data, type) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    const contentWidth = pageWidth - 2 * margin;
    let y = doc.y + 20;
    
    doc.fontSize(8)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text('INFORMAÇÕES DE PAGAMENTO', margin, y);
    
    y += 16;
    
    const boxStartY = y;
    const padding = 12;
    const infoHeight = 52;
    const totalHeight = 50;
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
    
    doc.fontSize(7)
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
    
    doc.fontSize(7)
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
    
    doc.fontSize(7)
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
    
    // Somar materiais
    data.materiais.forEach(mat => {
      totalGeral += this._calcularTotalItem(mat.quantidade, mat.materialCusto);
    });
    
    // Somar despesas adicionais
    if (data.despesasAdicionais && data.despesasAdicionais.length > 0) {
      totalGeral += data.despesasAdicionais.reduce((sum, d) => sum + d.valor, 0);
    }
    
    // Somar opções extras (corrigido: multiplicar FLOAT_FLOAT)
   if (data.opcoesExtras && data.opcoesExtras.length > 0) {
    data.opcoesExtras.forEach(opcao => {
      if (opcao.tipo === 'FLOAT_FLOAT' && opcao.valorFloat1 && opcao.valorFloat2) {
        // ✅ Verificar se é tempo
        const ehTempo = opcao.nome.toLowerCase().includes('hora') || 
                        opcao.nome.toLowerCase().includes('tempo') ||
                        opcao.nome.toLowerCase().includes('munck');
        
        if (ehTempo) {
          const horas = opcao.valorFloat1 / 60;
          totalGeral += horas * opcao.valorFloat2;
        } else {
          totalGeral += opcao.valorFloat1 * opcao.valorFloat2;
        }
      } else if (opcao.valorFloat1) {
        totalGeral += opcao.valorFloat1;
      }
    });
  }
    
    // Somar frete (apenas para pedido)
    if (type === 'pedido' && data.freteValor) {
      totalGeral += data.freteValor;
    }
    
    // Somar caminhão munck (apenas para pedido)
    // ✅ O valor no banco JÁ está em MINUTOS, então converter para horas antes de calcular
    if (type === 'pedido' && data.caminhaoMunckHoras && data.caminhaoMunckValorHora) {
      const minutos = data.caminhaoMunckHoras;
      const horas = minutos / 60;
      totalGeral += horas * data.caminhaoMunckValorHora;
    }
    
    doc.fontSize(7)
       .font('Helvetica-Bold')
       .fillColor('#6b7280')
       .text('VALOR TOTAL', margin + padding, y + 12, { 
         width: contentWidth - 2 * padding, 
         align: 'center' 
       });
    
    doc.fontSize(16)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text(this._formatarMoeda(totalGeral), margin + padding, y + 24, { 
         width: contentWidth - 2 * padding, 
         align: 'center' 
       });
  }

  _desenharFooter(doc) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    const pageHeight = doc.page.height;
    
    doc.moveTo(margin, pageHeight - 45)
       .lineTo(pageWidth - margin, pageHeight - 45)
       .strokeColor('#d1d5db')
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