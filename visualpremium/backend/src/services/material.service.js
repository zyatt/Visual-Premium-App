const prisma = require('../config/prisma');
const logService = require('./log.service');

class MaterialService {
  listar() {
    return prisma.material.findMany();
  }

  async criar(data, user) {
    const { nome, custo, unidade, quantidade, altura, largura, comprimento, sobras } = data;
    
    if (nome === undefined || nome === null || 
        custo === undefined || custo === null || 
        unidade === undefined || unidade === null || 
        quantidade === undefined || quantidade === null) {
      throw new Error('Todos os campos são obrigatórios');
    }

    if (nome.trim() === '') {
      throw new Error('Nome não pode estar vazio');
    }

    // altura, largura (m²) e comprimento (m/l) são opcionais — preenchidos depois no orçamento

    const existente = await prisma.material.findFirst({
      where: {
        nome: {
          mode: 'insensitive',
          equals: nome.trim(),
        },
      },
    });

    if (existente) {
      throw new Error('Já existe um material com este nome');
    }

    const quantidadeNum = parseFloat(quantidade);
    if (isNaN(quantidadeNum) || quantidadeNum < 0) {
      throw new Error('Quantidade inválida');
    }

    const custoNum = parseFloat(custo);
    if (isNaN(custoNum) || custoNum < 0) {
      throw new Error('Custo inválido');
    }

    const materialData = {
      nome: nome.trim(),
      custo: custoNum,
      unidade,
      quantidade: quantidadeNum,
      sobras: sobras === true || sobras === 'true',
    };

    // Adiciona altura e largura se fornecidos (m²)
    if ((unidade === 'm²' || unidade === 'm2') && altura && largura) {
      const alturaNum = parseFloat(altura);
      const larguraNum = parseFloat(largura);
      if (!isNaN(alturaNum) && alturaNum > 0) materialData.altura = alturaNum;
      if (!isNaN(larguraNum) && larguraNum > 0) materialData.largura = larguraNum;
    }

    // Adiciona comprimento se fornecido (m/l)
    if ((unidade === 'm/l' || unidade === 'ml') && comprimento) {
      const comprimentoNum = parseFloat(comprimento);
      if (!isNaN(comprimentoNum) && comprimentoNum > 0) materialData.comprimento = comprimentoNum;
    }

    const material = await prisma.material.create({
      data: materialData,
    });

    await logService.registrar({
      usuarioId: user?.id || 1,
      usuarioNome: user?.nome || 'Sistema',
      acao: 'CRIAR',
      entidade: 'MATERIAL',
      entidadeId: material.id,
      descricao: `Criou o material "${material.nome}"`,
      detalhes: material,
    });

    return material;
  }

  async atualizar(id, data, user) {
    const { nome, custo, unidade, quantidade, altura, largura, comprimento, sobras } = data;

    const materialAntigo = await prisma.material.findUnique({
      where: { id }
    });

    if (!materialAntigo) {
      throw new Error('Material não encontrado');
    }

    // altura, largura (m²) e comprimento (m/l) são opcionais — preenchidos depois no orçamento

    if (nome) {
      const existente = await prisma.material.findFirst({
        where: {
          nome: {
            mode: 'insensitive',
            equals: nome.trim(),
          },
          NOT: {
            id: id,
          },
        },
      });

      if (existente) {
        throw new Error('Já existe um material com este nome');
      }
    }

    let quantidadeNum;
    if (quantidade !== undefined) {
      quantidadeNum = parseFloat(quantidade);
      if (isNaN(quantidadeNum) || quantidadeNum < 0) {
        throw new Error('Quantidade inválida');
      }
    }

    let custoNum;
    if (custo !== undefined) {
      custoNum = parseFloat(custo);
      if (isNaN(custoNum) || custoNum < 0) {
        throw new Error('Custo inválido');
      }
    }

    const unidadeAtualizada = unidade || materialAntigo.unidade;

    const updateData = {
      nome: nome ? nome.trim() : undefined,
      custo: custoNum !== undefined ? custoNum : undefined,
      unidade,
      quantidade: quantidadeNum,
      sobras: sobras !== undefined ? (sobras === true || sobras === 'true') : undefined,
    };

    // Gerencia campos dimensionais conforme a unidade
    if (unidadeAtualizada === 'm²' || unidadeAtualizada === 'm2') {
      // Salva altura/largura se fornecidos, senão mantém o valor anterior
      if (altura !== undefined) {
        const alturaNum = parseFloat(altura);
        updateData.altura = (!isNaN(alturaNum) && alturaNum > 0) ? alturaNum : null;
      }
      if (largura !== undefined) {
        const larguraNum = parseFloat(largura);
        updateData.largura = (!isNaN(larguraNum) && larguraNum > 0) ? larguraNum : null;
      }
      // Limpa comprimento ao mudar para m²
      updateData.comprimento = null;
    } else if (unidadeAtualizada === 'm/l' || unidadeAtualizada === 'ml') {
      // Salva comprimento se fornecido, senão mantém o valor anterior
      if (comprimento !== undefined) {
        const comprimentoNum = parseFloat(comprimento);
        updateData.comprimento = (!isNaN(comprimentoNum) && comprimentoNum > 0) ? comprimentoNum : null;
      }
      // Limpa altura/largura ao mudar para m/l
      updateData.altura = null;
      updateData.largura = null;
    } else {
      // Outra unidade: limpa todos os campos dimensionais
      updateData.altura = null;
      updateData.largura = null;
      updateData.comprimento = null;
    }

    const material = await prisma.material.update({
      where: { id },
      data: updateData,
    });

    await logService.registrar({
      usuarioId: user?.id || 1,
      usuarioNome: user?.nome || 'Sistema',
      acao: 'EDITAR',
      entidade: 'MATERIAL',
      entidadeId: id,
      descricao: `Editou o material "${material.nome}"`,
      detalhes: {
        antes: materialAntigo,
        depois: material,
      },
    });

    return material;
  }

  async deletar(id, user) {
    const material = await prisma.material.findUnique({
      where: { id }
    });

    if (!material) {
      throw new Error('Material não encontrado');
    }

    const usados = await prisma.produtoMaterial.findMany({
      where: { materialId: id },
      include: { produto: true },
    });

    if (usados.length) {
      return Promise.reject({
        message: 'Material em uso',
        error: 'Material em uso',
        produtos: usados.map(u => u.produto.nome),
      });
    }

    await prisma.material.delete({ where: { id } });

    await logService.registrar({
      usuarioId: user?.id || 1,
      usuarioNome: user?.nome || 'Sistema',
      acao: 'DELETAR',
      entidade: 'MATERIAL',
      entidadeId: id,
      descricao: `Excluiu o material "${material.nome}"`,
      detalhes: material,
    });

    return material;
  }
}

module.exports = new MaterialService();