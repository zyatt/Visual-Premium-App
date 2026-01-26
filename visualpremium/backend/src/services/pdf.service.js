const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');

class PdfService {
  /**
   * Gera PDF de orçamento ou pedido
   * @param {Object} data - Dados do documento
   * @param {string} type - Tipo do documento ('orcamento' ou 'pedido')
   * @returns {PDFDocument} Stream do PDF
   */
  gerarDocumento(data, type = 'orcamento') {
    const doc = new PDFDocument({ margin: 50, size: 'A4' });

    // Configurações
    const logoPath = path.join(__dirname, '../../assets/image/logo preta.png');
    const titulo = type === 'orcamento' ? 'Orçamento' : 'Pedido';
    
    // Header
    this._desenharHeader(doc, logoPath, data.numero, titulo, data.createdAt);
    
    // Informações do cliente e produto
    this._desenharInfoCliente(doc, data.cliente, data.produtoNome);
    
    // Tabela de materiais
    this._desenharTabelaMateriais(doc, data.materiais);
    
    // Total
    this._desenharTotal(doc, data.total);
    
    // Footer
    this._desenharFooter(doc);
    
    doc.end();
    return doc;
  }

  _desenharHeader(doc, logoPath, numero, titulo, data) {
    const pageWidth = doc.page.width;
    const margin = doc.page.margins.left;
    
    // Logo à esquerda
    if (fs.existsSync(logoPath)) {
      doc.image(logoPath, margin, 50, { width: 120 });
    }
    
    // Informações à direita
    const rightX = pageWidth - margin - 200;
    
    // Número grande
    doc.fontSize(32)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text(`#${numero}`, rightX, 50, { width: 200, align: 'right' });
    
    // Texto do tipo de documento
    doc.fontSize(16)
       .font('Helvetica')
       .fillColor('#666666')
       .text(titulo, rightX, 90, { width: 200, align: 'right' });
    
    // Data com ícones (usando caracteres Unicode)
    const dataFormatada = this._formatarDataHora(data);
    doc.fontSize(10)
       .fillColor('#888888')
       .text(`📅 ${dataFormatada.data}`, rightX, 115, { width: 200, align: 'right' })
       .text(`🕐 ${dataFormatada.hora}`, rightX, 130, { width: 200, align: 'right' });
    
    // Linha separadora
    doc.moveTo(margin, 170)
       .lineTo(pageWidth - margin, 170)
       .strokeColor('#e0e0e0')
       .lineWidth(1)
       .stroke();
  }

  _desenharInfoCliente(doc, cliente, produto) {
    const margin = doc.page.margins.left;
    let y = 190;
    
    // Cliente
    doc.fontSize(10)
       .font('Helvetica-Bold')
       .fillColor('#666666')
       .text('CLIENTE', margin, y);
    
    doc.fontSize(14)
       .font('Helvetica-Bold')
       .fillColor('#1a1a1a')
       .text(cliente, margin, y + 15);
    
    y += 50;
    
    // Produto
    doc.fontSize(10)
       .font('Helvetica-Bold')
       .fillColor('#666666')
       .text('PRODUTO', margin, y);
    
    doc.fontSize(14)
       .font('Helvetica')
       .fillColor('#1a1a1a')
       .text(produto, margin, y + 15);
  }

  _desenharTabelaMateriais(doc, materiais) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    let y = 310;
    
    // Cabeçalho da tabela
    const colWidths = {
      material: 220,
      unidade: 80,
      quantidade: 80,
      valorUnit: 90,
      total: 90
    };
    
    const headerY = y;
    
    // Fundo do cabeçalho
    doc.rect(margin, headerY, pageWidth - 2 * margin, 25)
       .fillColor('#f5f5f5')
       .fill();
    
    // Textos do cabeçalho
    doc.fontSize(9)
       .font('Helvetica-Bold')
       .fillColor('#333333');
    
    let x = margin + 10;
    doc.text('MATERIAL', x, headerY + 8);
    x += colWidths.material;
    doc.text('UNIDADE', x, headerY + 8);
    x += colWidths.unidade;
    doc.text('QTDE', x, headerY + 8);
    x += colWidths.quantidade;
    doc.text('VALOR UNIT.', x, headerY + 8);
    x += colWidths.valorUnit;
    doc.text('TOTAL', x, headerY + 8);
    
    y += 35;
    
    // Linhas de materiais
    doc.fontSize(10)
       .font('Helvetica')
       .fillColor('#1a1a1a');
    
    materiais.forEach((material, index) => {
      // Verifica se precisa de nova página
      if (y > doc.page.height - 150) {
        doc.addPage();
        y = 50;
      }
      
      // Fundo alternado
      if (index % 2 === 0) {
        doc.rect(margin, y - 5, pageWidth - 2 * margin, 30)
           .fillColor('#fafafa')
           .fill();
      }
      
      x = margin + 10;
      
      // Material
      doc.fillColor('#1a1a1a')
         .text(material.materialNome, x, y, { width: colWidths.material - 10 });
      
      // Unidade
      x += colWidths.material;
      doc.text(material.materialUnidade, x, y);
      
      // Quantidade
      x += colWidths.unidade;
      const quantidade = this._formatarQuantidade(material.quantidade, material.materialUnidade);
      doc.text(quantidade, x, y);
      
      // Valor unitário
      x += colWidths.quantidade;
      doc.text(this._formatarMoeda(material.materialCusto), x, y);
      
      // Total
      x += colWidths.valorUnit;
      const totalItem = this._calcularTotalItem(material.quantidade, material.materialCusto);
      doc.font('Helvetica-Bold')
         .text(this._formatarMoeda(totalItem), x, y);
      
      doc.font('Helvetica');
      
      y += 30;
    });
    
    return y;
  }

  _desenharTotal(doc, total) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    const y = doc.y + 20;
    
    // Linha separadora
    doc.moveTo(pageWidth - margin - 200, y)
       .lineTo(pageWidth - margin, y)
       .strokeColor('#e0e0e0')
       .lineWidth(1)
       .stroke();
    
    // Texto e valor do total
    const totalY = y + 15;
    
    doc.fontSize(14)
       .font('Helvetica-Bold')
       .fillColor('#333333')
       .text('TOTAL', pageWidth - margin - 200, totalY);
    
    doc.fontSize(18)
       .fillColor('#2563eb')
       .text(this._formatarMoeda(total), pageWidth - margin - 200, totalY, { 
         width: 200, 
         align: 'right' 
       });
  }

  _desenharFooter(doc) {
    const margin = doc.page.margins.left;
    const pageWidth = doc.page.width;
    const pageHeight = doc.page.height;
    
    // Linha separadora
    doc.moveTo(margin, pageHeight - 80)
       .lineTo(pageWidth - margin, pageHeight - 80)
       .strokeColor('#e0e0e0')
       .lineWidth(1)
       .stroke();
    
    // Texto do footer
    doc.fontSize(8)
       .font('Helvetica')
       .fillColor('#888888')
       .text(
         'Este documento foi gerado automaticamente pelo sistema Visual Premium',
         margin,
         pageHeight - 65,
         { width: pageWidth - 2 * margin, align: 'center' }
       );
    
    doc.text(
      `Gerado em ${this._formatarDataHora(new Date()).dataCompleta}`,
      margin,
      pageHeight - 50,
      { width: pageWidth - 2 * margin, align: 'center' }
    );
  }

  _formatarDataHora(data) {
    const d = new Date(data);
    
    const dia = String(d.getDate()).padStart(2, '0');
    const mes = String(d.getMonth() + 1).padStart(2, '0');
    const ano = d.getFullYear();
    
    const hora = String(d.getHours()).padStart(2, '0');
    const minuto = String(d.getMinutes()).padStart(2, '0');
    
    return {
      data: `${dia}/${mes}/${ano}`,
      hora: `${hora}:${minuto}`,
      dataCompleta: `${dia}/${mes}/${ano} às ${hora}:${minuto}`
    };
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