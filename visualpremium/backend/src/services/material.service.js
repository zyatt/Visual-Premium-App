const prisma = require('../config/prisma');
const logService = require('./log.service');

class MaterialService {
  listar() {
    return prisma.material.findMany();
  }

  async criar(data, user) {
    const { nome, custo, unidade, quantidade } = data;
    
    // ✅ ALTERADO: Verificar se os campos existem (não são undefined/null), permitindo valor 0
    if (nome === undefined || nome === null || 
        custo === undefined || custo === null || 
        unidade === undefined || unidade === null || 
        quantidade === undefined || quantidade === null) {
      throw new Error('Todos os campos são obrigatórios');
    }

    // ✅ ALTERADO: Verificar se nome não está vazio após trim
    if (nome.trim() === '') {
      throw new Error('Nome não pode estar vazio');
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
    // ✅ ALTERADO: Remover validação quantidadeNum < 0, permitindo 0
    if (isNaN(quantidadeNum) || quantidadeNum < 0) {
      throw new Error('Quantidade inválida');
    }

    // ✅ ALTERADO: Validar custo (permitindo 0)
    const custoNum = parseFloat(custo);
    if (isNaN(custoNum) || custoNum < 0) {
      throw new Error('Custo inválido');
    }

    const material = await prisma.material.create({
      data: {
        nome: nome.trim(),
        custo: custoNum,
        unidade,
        quantidade: quantidadeNum,
      },
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
    const { nome, custo, unidade, quantidade } = data;

    const materialAntigo = await prisma.material.findUnique({
      where: { id }
    });

    if (!materialAntigo) {
      throw new Error('Material não encontrado');
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
      // ✅ ALTERADO: Permitir quantidade = 0
      if (isNaN(quantidadeNum) || quantidadeNum < 0) {
        throw new Error('Quantidade inválida');
      }
    }

    // ✅ ALTERADO: Validar custo se fornecido (permitindo 0)
    let custoNum;
    if (custo !== undefined) {
      custoNum = parseFloat(custo);
      if (isNaN(custoNum) || custoNum < 0) {
        throw new Error('Custo inválido');
      }
    }

    const material = await prisma.material.update({
      where: { id },
      data: {
        nome: nome ? nome.trim() : undefined,
        custo: custoNum !== undefined ? custoNum : undefined,
        unidade,
        quantidade: quantidadeNum,
      },
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