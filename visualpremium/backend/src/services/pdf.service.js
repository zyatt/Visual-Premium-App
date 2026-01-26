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
    this._desenharResumo(doc, data.total);
    this._desenharFooter(doc);
    
    doc.end();
    return doc;
  }

  _desenharHeader(doc, logoPath, numero, titulo) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    
    // Logo à esquerda - Verificação e debug
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
    
    // Título e número centralizados
    doc.fontSize(11)
       .font('Helvetica')
       .fillColor('#666666')
       .text(titulo, 0, 50, { width: pageWidth, align: 'center' });
    
    doc.fontSize(32)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text(numero.toString(), 0, 68, { width: pageWidth, align: 'center' });
    
    // Linha divisória
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
    
    // Card com informações do cliente e produto
    const cardHeight = 90;
    const cardY = y;
    
    doc.roundedRect(margin, cardY, pageWidth - 2 * margin, cardHeight, 8)
       .fillColor('#f8f9fa')
       .fill();
    
    // Borda lateral colorida
    doc.rect(margin, cardY, 4, cardHeight)
       .fillColor('#1a1a1a')
       .fill();
    
    // Cliente
    doc.fontSize(9)
       .font('Helvetica-Bold')
       .fillColor('#6b7280')
       .text('CLIENTE', margin + 20, cardY + 20);
    
    doc.fontSize(16)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text(cliente, margin + 20, cardY + 35, { width: pageWidth - 2 * margin - 40 });
    
    // Produto
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
    
    // Título da seção
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
    
    // Header da tabela
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
    
    // Linhas dos materiais
    doc.fontSize(9)
       .font('Helvetica')
       .fillColor('#1f2937');
    
    materiais.forEach((material, index) => {
      if (y > doc.page.height - 180) {
        doc.addPage();
        y = 60;
      }
      
      const rowHeight = 35;
      
      // Fundo alternado
      if (index % 2 === 0) {
        doc.rect(margin, y, tableWidth, rowHeight)
           .fillColor('#f9fafb')
           .fill();
      }
      
      // Linha divisória sutil
      doc.moveTo(margin, y + rowHeight)
         .lineTo(pageWidth - margin, y + rowHeight)
         .strokeColor('#e5e7eb')
         .lineWidth(0.5)
         .stroke();
      
      x = margin + 15;
      const textY = y + 12;
      
      // Material
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
      
      // Unidade
      doc.fillColor('#6b7280')
         .fontSize(8)
         .text(material.materialUnidade, x - 10, textY, { width: colWidths.unidade, align: 'center' });
      
      x += colWidths.unidade;
      
      // Quantidade
      const quantidade = this._formatarQuantidade(material.quantidade, material.materialUnidade);
      doc.fillColor('#1f2937')
         .font('Helvetica-Bold')
         .fontSize(9)
         .text(quantidade, x - 10, textY, { width: colWidths.quantidade, align: 'center' });
      
      x += colWidths.quantidade;
      
      // Valor unitário
      doc.fillColor('#6b7280')
         .font('Helvetica')
         .fontSize(8)
         .text(this._formatarMoeda(material.materialCusto), x - 10, textY, { width: colWidths.valorUnit, align: 'right' });
      
      x += colWidths.valorUnit;
      
      // Total do item
      const totalItem = this._calcularTotalItem(material.quantidade, material.materialCusto);
      doc.fillColor('#1f2937')
         .font('Helvetica-Bold')
         .fontSize(9)
         .text(this._formatarMoeda(totalItem), x - 10, textY, { width: colWidths.total - 15, align: 'right' });
      
      y += rowHeight;
    });
    
    return y;
  }

  _desenharResumo(doc, total) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    const y = doc.y + 30;
    
    const boxWidth = 250;
    const boxHeight = 70;
    const boxX = pageWidth - margin - boxWidth;
    
    // Box do total com sombra
    doc.rect(boxX + 2, y + 2, boxWidth, boxHeight)
       .fillColor('#000000')
       .opacity(0.05)
       .fill();
    
    doc.opacity(1);
    doc.roundedRect(boxX, y, boxWidth, boxHeight, 8)
       .fillColor('#1a1a1a')
       .fill();
    
    // Label TOTAL
    doc.fontSize(10)
       .font('Helvetica-Bold')
       .fillColor('#ffffff')
       .text('VALOR TOTAL', boxX + 20, y + 18, { width: boxWidth - 40, align: 'left' });
    
    // Valor do total
    doc.fontSize(22)
       .font('Helvetica-Bold')
       .fillColor('#ffffff')
       .text(this._formatarMoeda(total), boxX + 20, y + 35, { width: boxWidth - 40, align: 'left' });
  }

  _desenharFooter(doc) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    const pageHeight = doc.page.height;
    
    // Linha decorativa
    doc.moveTo(margin, pageHeight - 50)
       .lineTo(pageWidth - margin, pageHeight - 50)
       .strokeColor('#e5e7eb')
       .lineWidth(1)
       .stroke();
    
    // Texto do footer
    doc.fontSize(7)
       .font('Helvetica')
       .fillColor('#9ca3af')
       .text(
         'Documento gerado automaticamente pelo sistema Visual Premium', 
         margin, 
         pageHeight - 35, 
         { width: pageWidth - 2 * margin, align: 'center' }
       );
  }

  _formatarMoeda(valor) {
    return new Intl.NumberFormat('pt-BR', {
      style: 'currency',
      currency: 'BRL'
    }).format(valor);
  }

  _formatarQuantidade(quantidade, unidade) {
    const num = parseFloat(quantidade.toString().replace(',', '.'));
    
    if (unidade === 'Kg') {
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