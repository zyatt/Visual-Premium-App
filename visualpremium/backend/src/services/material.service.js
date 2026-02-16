const prisma = require('../config/prisma');
const logService = require('./log.service');

class MaterialService {
  listar() {
    return prisma.material.findMany();
  }

  async criar(data, user) {
    const { nome, custo, unidade, quantidade, altura, largura, comprimento } = data;
    
    if (nome === undefined || nome === null || 
        custo === undefined || custo === null || 
        unidade === undefined || unidade === null || 
        quantidade === undefined || quantidade === null) {
      throw new Error('Todos os campos são obrigatórios');
    }

    if (nome.trim() === '') {
      throw new Error('Nome não pode estar vazio');
    }

    // VALIDAÇÃO PARA m²
    if (unidade === 'm²' || unidade === 'm2') {
      if (!altura || !largura) {
        throw new Error('Altura e largura são obrigatórios para unidade m²');
      }
      const alturaNum = parseFloat(altura);
      const larguraNum = parseFloat(largura);
      if (isNaN(alturaNum) || alturaNum <= 0 || isNaN(larguraNum) || larguraNum <= 0) {
        throw new Error('Altura e largura devem ser números positivos');
      }
    }

    // VALIDAÇÃO PARA m/l (metro linear)
    if (unidade === 'm/l' || unidade === 'ml') {
      if (!comprimento) {
        throw new Error('Comprimento é obrigatório para unidade m/l');
      }
      const comprimentoNum = parseFloat(comprimento);
      if (isNaN(comprimentoNum) || comprimentoNum <= 0) {
        throw new Error('Comprimento deve ser um número positivo (em mm)');
      }
    }

    const nomeNormalizado = nome.trim().toLowerCase();
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
    };

    // Adiciona altura e largura apenas se for m²
    if (unidade === 'm²' || unidade === 'm2') {
      materialData.altura = parseFloat(altura);
      materialData.largura = parseFloat(largura);
    }

    // Adiciona comprimento apenas se for m/l
    if (unidade === 'm/l' || unidade === 'ml') {
      materialData.comprimento = parseFloat(comprimento);
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
    const { nome, custo, unidade, quantidade, altura, largura, comprimento } = data;

    const materialAntigo = await prisma.material.findUnique({
      where: { id }
    });

    if (!materialAntigo) {
      throw new Error('Material não encontrado');
    }

    // VALIDAÇÃO PARA m²
    const unidadeAtualizada = unidade || materialAntigo.unidade;
    if (unidadeAtualizada === 'm²' || unidadeAtualizada === 'm2') {
      const alturaFinal = altura !== undefined ? altura : materialAntigo.altura;
      const larguraFinal = largura !== undefined ? largura : materialAntigo.largura;
      
      if (!alturaFinal || !larguraFinal) {
        throw new Error('Altura e largura são obrigatórios para unidade m²');
      }
      const alturaNum = parseFloat(alturaFinal);
      const larguraNum = parseFloat(larguraFinal);
      if (isNaN(alturaNum) || alturaNum <= 0 || isNaN(larguraNum) || larguraNum <= 0) {
        throw new Error('Altura e largura devem ser números positivos');
      }
    }

    // VALIDAÇÃO PARA m/l (metro linear)
    if (unidadeAtualizada === 'm/l' || unidadeAtualizada === 'ml') {
      const comprimentoFinal = comprimento !== undefined ? comprimento : materialAntigo.comprimento;
      
      if (!comprimentoFinal) {
        throw new Error('Comprimento é obrigatório para unidade m/l');
      }
      const comprimentoNum = parseFloat(comprimentoFinal);
      if (isNaN(comprimentoNum) || comprimentoNum <= 0) {
        throw new Error('Comprimento deve ser um número positivo (em mm)');
      }
    }

    if (nome) {
      const nomeNormalizado = nome.trim().toLowerCase();
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

    const updateData = {
      nome: nome ? nome.trim() : undefined,
      custo: custoNum !== undefined ? custoNum : undefined,
      unidade,
      quantidade: quantidadeNum,
    };

    // Adiciona ou limpa altura/largura baseado na unidade
    if (unidadeAtualizada === 'm²' || unidadeAtualizada === 'm2') {
      if (altura !== undefined) updateData.altura = parseFloat(altura);
      if (largura !== undefined) updateData.largura = parseFloat(largura);
      // Limpa comprimento se mudar para m²
      updateData.comprimento = null;
    } else if (unidadeAtualizada === 'm/l' || unidadeAtualizada === 'ml') {
      // Adiciona comprimento para m/l
      if (comprimento !== undefined) updateData.comprimento = parseFloat(comprimento);
      // Limpa altura/largura se mudar para m/l
      updateData.altura = null;
      updateData.largura = null;
    } else {
      // Se mudou para outra unidade, limpa todos os campos dimensionais
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