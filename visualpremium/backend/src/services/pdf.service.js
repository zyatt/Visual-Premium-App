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
    
    console.log('Tentando carregar logo de:', logoPath);
    console.log('Logo existe?', fs.existsSync(logoPath));
    
    if (fs.existsSync(logoPath)) {
      try {
        doc.image(logoPath, margin, 40, { width: 120, height: 60 });
        console.log('Logo carregada com sucesso');
      } catch (error) {
        console.error('Erro ao carregar logo:', error);
      }
    } else {
      console.warn('Logo não encontrada no caminho:', logoPath);
    }
    
    const numeroStr = numero.toString();
    const numeroFontSize = 32;
    doc.fontSize(numeroFontSize).font('Helvetica-Bold');
    const numeroWidth = doc.widthOfString(numeroStr);
    
    const areaDireitaStart = pageWidth / 2;
    const areaDireitaWidth = (pageWidth - margin) - areaDireitaStart;
    const numeroX = areaDireitaStart + (areaDireitaWidth - numeroWidth) / 2;
    
    doc.fontSize(11)
       .font('Helvetica')
       .fillColor('#666666')
       .text(titulo, numeroX - 30, 50, { width: numeroWidth + 60, align: 'center' });
    
    doc.fontSize(32)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text(numeroStr, numeroX, 68);
    
    const now = new Date();
    const dataFormatada = now.toLocaleDateString('pt-BR');
    const horaFormatada = now.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
    
    doc.fontSize(9)
       .font('Helvetica')
       .fillColor('#666666')
       .text(`${dataFormatada} às ${horaFormatada}`, numeroX - 30, 108, { width: numeroWidth + 60, align: 'center' });
    
    doc.moveTo(margin, 130)
       .lineTo(pageWidth - margin, 130)
       .strokeColor('#e0e0e0')
       .lineWidth(1)
       .stroke();
  }

  _desenharInfoPrincipal(doc, cliente, produto) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    let y = 150;
    
    const cardHeight = 90;
    const cardY = y;
    
    doc.roundedRect(margin, cardY, pageWidth - 2 * margin, cardHeight, 8)
       .fillColor('#f8f9fa')
       .fill();
    
    doc.rect(margin, cardY, 4, cardHeight)
       .fillColor('#1a1a1a')
       .fill();
    
    doc.fontSize(9)
       .font('Helvetica-Bold')
       .fillColor('#6b7280')
       .text('CLIENTE', margin + 20, cardY + 20);
    
    doc.fontSize(16)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text(cliente, margin + 20, cardY + 35, { width: pageWidth - 2 * margin - 40 });
    
    doc.fontSize(9)
       .font('Helvetica-Bold')
       .fillColor('#6b7280')
       .text('PRODUTO', margin + 20, cardY + 60);
    
    doc.fontSize(12)
       .font('Helvetica')
       .fillColor('#374151')
       .text(produto, margin + 20, cardY + 75, { width: pageWidth - 2 * margin - 40 });
  }

  _desenharTabelaMateriais(doc, materiais) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    let y = 260;
    
    doc.fontSize(11)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text('MATERIAIS', margin, y);
    
    y += 25;
    
    const tableWidth = pageWidth - 2 * margin;
    const colWidths = {
      material: tableWidth * 0.48,
      unidade: tableWidth * 0.10,
      quantidade: tableWidth * 0.14,
      valorUnit: tableWidth * 0.14,
      total: tableWidth * 0.14
    };
    
    doc.roundedRect(margin, y, tableWidth, 30, 6)
       .fillColor('#1a1a1a')
       .fill();
    
    doc.fontSize(8)
       .font('Helvetica-Bold')
       .fillColor('#ffffff');
    
    let x = margin + 15;
    doc.text('MATERIAL', x, y + 10, { width: colWidths.material - 20, align: 'left' });
    
    x += colWidths.material;
    doc.text('UN', x - 10, y + 10, { width: colWidths.unidade, align: 'center' });
    
    x += colWidths.unidade;
    doc.text('QUANTIDADE', x - 10, y + 10, { width: colWidths.quantidade, align: 'center' });
    
    x += colWidths.quantidade;
    doc.text('VL. UNITÁRIO', x - 10, y + 10, { width: colWidths.valorUnit, align: 'right' });
    
    x += colWidths.valorUnit;
    doc.text('TOTAL', x - 10, y + 10, { width: colWidths.total - 15, align: 'right' });
    
    y += 40;
    
    doc.fontSize(9)
       .font('Helvetica')
       .fillColor('#1f2937');
    
    materiais.forEach((material, index) => {
      if (y > doc.page.height - 180) {
        doc.addPage();
        y = 60;
      }
      
      const rowHeight = 35;
      
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
      
      x = margin + 15;
      const textY = y + 12;
      
      doc.fillColor('#1f2937')
         .font('Helvetica')
         .fontSize(9)
         .text(material.materialNome, x, textY, { 
           width: colWidths.material - 20, 
           align: 'left',
           lineBreak: false,
           ellipsis: true
         });
      
      x += colWidths.material;
      
      doc.fillColor('#6b7280')
         .fontSize(8)
         .text(material.materialUnidade, x - 10, textY, { width: colWidths.unidade, align: 'center' });
      
      x += colWidths.unidade;
      
      const quantidade = this._formatarQuantidade(material.quantidade, material.materialUnidade);
      doc.fillColor('#1f2937')
         .font('Helvetica-Bold')
         .fontSize(9)
         .text(quantidade, x - 10, textY, { width: colWidths.quantidade, align: 'center' });
      
      x += colWidths.quantidade;
      
      doc.fillColor('#6b7280')
         .font('Helvetica')
         .fontSize(8)
         .text(this._formatarMoeda(material.materialCusto), x - 10, textY, { width: colWidths.valorUnit, align: 'right' });
      
      x += colWidths.valorUnit;
      
      const totalItem = this._calcularTotalItem(material.quantidade, material.materialCusto);
      doc.fillColor('#1f2937')
         .font('Helvetica-Bold')
         .fontSize(9)
         .text(this._formatarMoeda(totalItem), x - 10, textY, { width: colWidths.total - 15, align: 'right' });
      
      y += rowHeight;
    });
    
    return y;
  }

  _desenharItensAdicionais(doc, data) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    let y = doc.y + 30;
    
    if (y > doc.page.height - 200) {
      doc.addPage();
      y = 60;
    }
    
    doc.fontSize(11)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text('INFORMAÇÕES ADICIONAIS', margin, y);
    
    y += 20;
    
    const boxWidth = pageWidth - 2 * margin;
    
    if (data.despesasAdicionais && data.despesasAdicionais.length > 0) {
      for (const despesa of data.despesasAdicionais) {
        if (y > doc.page.height - 100) {
          doc.addPage();
          y = 60;
        }
        
        doc.roundedRect(margin, y, boxWidth, 45, 6)
           .fillColor('#f0f9ff')
           .fill();
        
        doc.rect(margin, y, 4, 45)
           .fillColor('#3b82f6')
           .fill();
        
        doc.fontSize(8)
           .font('Helvetica-Bold')
           .fillColor('#6b7280')
           .text('DESPESA ADICIONAL', margin + 15, y + 12);
        
        doc.fontSize(10)
           .font('Helvetica')
           .fillColor('#1f2937')
           .text(despesa.descricao, margin + 15, y + 27, { width: boxWidth - 180 });
        
        doc.fontSize(12)
           .font('Helvetica-Bold')
           .fillColor('#3b82f6')
           .text(this._formatarMoeda(despesa.valor), pageWidth - margin - 130, y + 20, { 
             width: 120, 
             align: 'right' 
           });
        
        y += 55;
      }
    }
    
    if (data.frete && data.freteDesc && data.freteValor) {
      if (y > doc.page.height - 100) {
        doc.addPage();
        y = 60;
      }
      
      doc.roundedRect(margin, y, boxWidth, 45, 6)
         .fillColor('#f0fdf4')
         .fill();
      
      doc.rect(margin, y, 4, 45)
         .fillColor('#22c55e')
         .fill();
      
      doc.fontSize(8)
         .font('Helvetica-Bold')
         .fillColor('#6b7280')
         .text('FRETE', margin + 15, y + 12);
      
      doc.fontSize(10)
         .font('Helvetica')
         .fillColor('#1f2937')
         .text(data.freteDesc, margin + 15, y + 27, { width: boxWidth - 180 });
      
      doc.fontSize(12)
         .font('Helvetica-Bold')
         .fillColor('#22c55e')
         .text(this._formatarMoeda(data.freteValor), pageWidth - margin - 130, y + 20, { 
           width: 120, 
           align: 'right' 
         });
      
      y += 55;
    }
    
    if (data.caminhaoMunck && data.caminhaoMunckHoras && data.caminhaoMunckValorHora) {
      if (y > doc.page.height - 100) {
        doc.addPage();
        y = 60;
      }
      
      const totalMunck = data.caminhaoMunckHoras * data.caminhaoMunckValorHora;
      
      doc.roundedRect(margin, y, boxWidth, 45, 6)
         .fillColor('#fef3c7')
         .fill();
      
      doc.rect(margin, y, 4, 45)
         .fillColor('#f59e0b')
         .fill();
      
      doc.fontSize(8)
         .font('Helvetica-Bold')
         .fillColor('#6b7280')
         .text('CAMINHÃO MUNCK', margin + 15, y + 12);
      
      doc.fontSize(10)
         .font('Helvetica')
         .fillColor('#1f2937')
         .text(`${this._formatarQuantidade(data.caminhaoMunckHoras, 'h')} horas × ${this._formatarMoeda(data.caminhaoMunckValorHora)}/h`, 
                margin + 15, y + 27, { width: boxWidth - 180 });
      
      doc.fontSize(12)
         .font('Helvetica-Bold')
         .fillColor('#f59e0b')
         .text(this._formatarMoeda(totalMunck), pageWidth - margin - 130, y + 20, { 
           width: 120, 
           align: 'right' 
         });
      
      y += 55;
    }
  }

  _desenharResumo(doc, data) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    let y = doc.y + 30;
    
    if (y > doc.page.height - 150) {
      doc.addPage();
      y = 60;
    }
    
    const boxWidth = 250;
    const boxX = pageWidth - margin - boxWidth;
    
    let subtotal = 0;
    data.materiais.forEach(mat => {
      subtotal += this._calcularTotalItem(mat.quantidade, mat.materialCusto);
    });
    
    doc.fontSize(9)
       .font('Helvetica')
       .fillColor('#6b7280')
       .text('Subtotal Materiais', boxX, y, { width: boxWidth - 120, align: 'left' });
    
    doc.fontSize(10)
       .font('Helvetica-Bold')
       .fillColor('#374151')
       .text(this._formatarMoeda(subtotal), boxX + boxWidth - 110, y, { width: 110, align: 'right' });
    
    y += 20;
    
    if (data.despesasAdicionais && data.despesasAdicionais.length > 0) {
      for (const despesa of data.despesasAdicionais) {
        doc.fontSize(9)
           .font('Helvetica')
           .fillColor('#6b7280')
           .text(despesa.descricao, boxX, y, { width: boxWidth - 120, align: 'left', lineBreak: false, ellipsis: true });
        
        doc.fontSize(10)
           .font('Helvetica')
           .fillColor('#374151')
           .text(this._formatarMoeda(despesa.valor), boxX + boxWidth - 110, y, { width: 110, align: 'right' });
        
        y += 18;
      }
    }
    
    if (data.frete && data.freteValor) {
      doc.fontSize(9)
         .font('Helvetica')
         .fillColor('#6b7280')
         .text('Frete', boxX, y, { width: boxWidth - 120, align: 'left' });
      
      doc.fontSize(10)
         .font('Helvetica')
         .fillColor('#374151')
         .text(this._formatarMoeda(data.freteValor), boxX + boxWidth - 110, y, { width: 110, align: 'right' });
      
      y += 18;
    }
    
    if (data.caminhaoMunck && data.caminhaoMunckHoras && data.caminhaoMunckValorHora) {
      const totalMunck = data.caminhaoMunckHoras * data.caminhaoMunckValorHora;
      
      doc.fontSize(9)
         .font('Helvetica')
         .fillColor('#6b7280')
         .text('Caminhão Munck', boxX, y, { width: boxWidth - 120, align: 'left' });
      
      doc.fontSize(10)
         .font('Helvetica')
         .fillColor('#374151')
         .text(this._formatarMoeda(totalMunck), boxX + boxWidth - 110, y, { width: 110, align: 'right' });
      
      y += 18;
    }
    
    y += 10;
    doc.moveTo(boxX, y)
       .lineTo(pageWidth - margin, y)
       .strokeColor('#e5e7eb')
       .lineWidth(1)
       .stroke();
    
    y += 15;
    
    let totalGeral = subtotal;
    
    if (data.despesasAdicionais && data.despesasAdicionais.length > 0) {
      totalGeral += data.despesasAdicionais.reduce((sum, d) => sum + d.valor, 0);
    }
    
    if (data.freteValor) totalGeral += data.freteValor;
    
    if (data.caminhaoMunckHoras && data.caminhaoMunckValorHora) {
      totalGeral += data.caminhaoMunckHoras * data.caminhaoMunckValorHora;
    }
    
    doc.fontSize(10)
       .font('Helvetica-Bold')
       .fillColor('#6b7280')
       .text('VALOR TOTAL', boxX, y, { width: boxWidth, align: 'right' });
    
    doc.fontSize(24)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text(this._formatarMoeda(totalGeral), boxX, y + 20, { width: boxWidth, align: 'right' });
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