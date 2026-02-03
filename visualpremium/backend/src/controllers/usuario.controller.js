const prisma = require('../config/prisma');
const bcrypt = require('bcrypt');
const LogService = require('../services/log.service');

class UsuarioController {
  // Listar todos os usuários
  async listar(req, res) {
    try {
      const usuarios = await prisma.usuario.findMany({
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

      return res.json(usuarios);
    } catch (error) {
      return res.status(500).json({ error: 'Erro ao listar usuários' });
    }
  }

  // Buscar usuário por ID
  async buscarPorId(req, res) {
    try {
      const { id } = req.params;

      const usuario = await prisma.usuario.findUnique({
        where: { id: parseInt(id) },
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
        return res.status(404).json({ error: 'Usuário não encontrado' });
      }

      return res.json(usuario);
    } catch (error) {
      return res.status(500).json({ error: 'Erro ao buscar usuário' });
    }
  }

  // Criar novo usuário
  async criar(req, res) {
    try {
      const { username, password, nome, role, ativo } = req.body;

      // Validações
      if (!username || !password || !nome) {
        return res.status(400).json({ 
          error: 'Username, senha e nome são obrigatórios' 
        });
      }

      if (password.length < 6) {
        return res.status(400).json({ 
          error: 'A senha deve ter no mínimo 6 caracteres' 
        });
      }

      // Verifica se username já existe
      const usuarioExistente = await prisma.usuario.findUnique({
        where: { username },
      });

      if (usuarioExistente) {
        return res.status(400).json({ 
          error: 'Username já está em uso' 
        });
      }

      // Hash da senha
      const hashedPassword = await bcrypt.hash(password, 10);

      // Cria o usuário
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

      await LogService.registrar({
        usuarioId: req.usuarioId || 1, // ID do usuário logado (implementar auth)
        usuarioNome: req.usuarioNome || 'Sistema',
        acao: 'CRIAR',
        entidade: 'USUARIO',
        entidadeId: usuario.id,
        descricao: `Criou o usuário "${usuario.nome}" (${usuario.username})`,
        detalhes: { role: usuario.role, ativo: usuario.ativo },
      });

      return res.status(201).json(usuario);
    } catch (error) {
      return res.status(500).json({ error: 'Erro ao criar usuário' });
    }
  }

  // Atualizar usuário
  async atualizar(req, res) {
    try {
      const { id } = req.params;
      const { username, password, nome, role, ativo } = req.body;

      // Verifica se usuário existe
      const usuarioExistente = await prisma.usuario.findUnique({
        where: { id: parseInt(id) },
      });

      if (!usuarioExistente) {
        return res.status(404).json({ error: 'Usuário não encontrado' });
      }

      // Se está alterando username, verifica se já existe
      if (username && username !== usuarioExistente.username) {
        const usernameEmUso = await prisma.usuario.findUnique({
          where: { username },
        });

        if (usernameEmUso) {
          return res.status(400).json({ 
            error: 'Username já está em uso' 
          });
        }
      }

      // Prepara dados para atualização
      const dadosAtualizacao = {};
      
      if (username) dadosAtualizacao.username = username;
      if (nome) dadosAtualizacao.nome = nome;
      if (role) dadosAtualizacao.role = role;
      if (typeof ativo === 'boolean') dadosAtualizacao.ativo = ativo;
      
      // Se forneceu nova senha, faz hash
      if (password) {
        if (password.length < 6) {
          return res.status(400).json({ 
            error: 'A senha deve ter no mínimo 6 caracteres' 
          });
        }
        dadosAtualizacao.password = await bcrypt.hash(password, 10);
      }

      const usuario = await prisma.usuario.update({
        where: { id: parseInt(id) },
        data: dadosAtualizacao,
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

      // 📝 Registrar log
      await LogService.registrar({
        usuarioId: req.usuarioId || 1,
        usuarioNome: req.usuarioNome || 'Sistema',
        acao: 'EDITAR',
        entidade: 'USUARIO',
        entidadeId: usuario.id,
        descricao: `Editou o usuário "${usuario.nome}" (${usuario.username})`,
        detalhes: dadosAtualizacao,
      });

      return res.json(usuario);
    } catch (error) {
      return res.status(500).json({ error: 'Erro ao atualizar usuário' });
    }
  }

  // Deletar usuário
  async deletar(req, res) {
    try {
      const { id } = req.params;

      // Verifica se usuário existe
      const usuario = await prisma.usuario.findUnique({
        where: { id: parseInt(id) },
      });

      if (!usuario) {
        return res.status(404).json({ error: 'Usuário não encontrado' });
      }

      // Não permite deletar o próprio usuário (se implementar auth)
      // if (req.userId === parseInt(id)) {
      //   return res.status(400).json({ error: 'Não é possível deletar seu próprio usuário' });
      // }

      await prisma.usuario.delete({
        where: { id: parseInt(id) },
      });

      // 📝 Registrar log
      await LogService.registrar({
        usuarioId: req.usuarioId || 1,
        usuarioNome: req.usuarioNome || 'Sistema',
        acao: 'DELETAR',
        entidade: 'USUARIO',
        entidadeId: usuario.id,
        descricao: `Deletou o usuário "${usuario.nome}" (${usuario.username})`,
      });

      return res.status(204).send();
    } catch (error) {
      return res.status(500).json({ error: 'Erro ao deletar usuário' });
    }
  }
}

module.exports = new UsuarioController();