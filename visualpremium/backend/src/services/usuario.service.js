const prisma = require('../config/prisma');
const bcrypt = require('bcrypt');
const logService = require('./log.service');

class UsuarioService {
  async listar() {
    return prisma.usuario.findMany({
      select: {
        id: true,
        username: true,
        nome: true,
        role: true,
        ativo: true,
        createdAt: true,
        updatedAt: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async buscarPorId(id) {
    const usuario = await prisma.usuario.findUnique({
      where: { id },
      select: {
        id: true,
        username: true,
        nome: true,
        role: true,
        ativo: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    if (!usuario) {
      throw new Error('Usuário não encontrado');
    }

    return usuario;
  }

  async criar(data, user) {
    const { username, password, nome, role, ativo } = data;

    if (!username || !password || !nome) {
      throw new Error('Username, senha e nome são obrigatórios');
    }

    if (password.length < 6) {
      throw new Error('A senha deve ter no mínimo 6 caracteres');
    }

    const rolesPermitidas = ['admin', 'compras', 'user'];
    if (role && !rolesPermitidas.includes(role)) {
      throw new Error('Role inválida. Use: admin, compras ou user');
    }

    const existente = await prisma.usuario.findUnique({
      where: { username },
    });

    if (existente) {
      throw new Error('Username já está em uso');
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const usuario = await prisma.usuario.create({
      data: {
        username,
        password: hashedPassword,
        nome,
        role: role || 'user',
        ativo: typeof ativo === 'boolean' ? ativo : true,
      },
      select: {
        id: true,
        username: true,
        nome: true,
        role: true,
        ativo: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    await logService.registrar({
      usuarioId: user?.id || 1,
      usuarioNome: user?.nome || 'Sistema',
      acao: 'CRIAR',
      entidade: 'USUARIO',
      entidadeId: usuario.id,
      descricao: `Criou o usuário "${usuario.nome}" (${usuario.username})`,
      detalhes: usuario,
    });

    return usuario;
  }


  async atualizar(id, data, user) {
    const { username, password, nome, role, ativo } = data;

    const usuarioAntigo = await prisma.usuario.findUnique({
      where: { id },
    });

    if (!usuarioAntigo) {
      throw new Error('Usuário não encontrado');
    }

    if (username && username !== usuarioAntigo.username) {
      const emUso = await prisma.usuario.findUnique({
        where: { username },
      });

      if (emUso) {
        throw new Error('Username já está em uso');
      }
    }

    const dados = {
      username,
      nome,
      role,
      ativo: typeof ativo === 'boolean' ? ativo : undefined,
    };

    if (password) {
      if (password.length < 6) {
        throw new Error('A senha deve ter no mínimo 6 caracteres');
      }
      dados.password = await bcrypt.hash(password, 10);
    }

    const usuario = await prisma.usuario.update({
      where: { id },
      data: dados,
      select: {
        id: true,
        username: true,
        nome: true,
        role: true,
        ativo: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    await logService.registrar({
      usuarioId: user?.id || 1,
      usuarioNome: user?.nome || 'Sistema',
      acao: 'EDITAR',
      entidade: 'USUARIO',
      entidadeId: id,
      descricao: `Editou o usuário "${usuario.nome}" (${usuario.username})`,
      detalhes: {
        antes: usuarioAntigo,
        depois: usuario,
      },
    });

    return usuario;
  }

  async deletar(id, user) {
    const usuario = await prisma.usuario.findUnique({
      where: { id },
    });

    if (!usuario) {
      throw new Error('Usuário não encontrado');
    }

    if (user && user.id === id) {
      throw new Error('Você não pode deletar sua própria conta');
    }

    await prisma.usuario.delete({
      where: { id },
    });

    await logService.registrar({
      usuarioId: user?.id || 1,
      usuarioNome: user?.nome || 'Sistema',
      acao: 'DELETAR',
      entidade: 'USUARIO',
      entidadeId: id,
      descricao: `Deletou o usuário "${usuario.nome}" (${usuario.username})`,
      detalhes: usuario,
    });

    return usuario;
  }
}

module.exports = new UsuarioService();
