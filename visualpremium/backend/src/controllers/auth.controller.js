const prisma = require('../config/prisma');
const bcrypt = require('bcrypt');

class AuthController {
  // Login
  async login(req, res) {
    try {
      const { username, password } = req.body;

      // Validações
      if (!username || !password) {
        return res.status(400).json({ 
          error: 'Usuário e senha são obrigatórios' 
        });
      }

      // Busca usuário
      const usuario = await prisma.usuario.findUnique({
        where: { username },
      });

      if (!usuario) {
        return res.status(401).json({ 
          error: 'Usuário ou senha incorretos' 
        });
      }

      // Verifica se usuário está ativo
      if (!usuario.ativo) {
        return res.status(401).json({ 
          error: 'Usuário ou senha incorretos' 
        });
      }

      // Verifica senha
      const senhaValida = await bcrypt.compare(password, usuario.password);

      if (!senhaValida) {
        return res.status(401).json({ 
          error: 'Usuário ou senha incorretos' 
        });
      }

      // Retorna dados do usuário (sem a senha)
      return res.json({
        id: usuario.id,
        username: usuario.username,
        nome: usuario.nome,
        role: usuario.role,
      });
    } catch (error) {
      return res.status(500).json({ error: 'Erro ao fazer login' });
    }
  }

  // Verificar sessão (se implementar JWT no futuro)
  async verificarSessao(req, res) {
    try {
      // Por enquanto, apenas retorna sucesso
      // No futuro, pode validar JWT aqui
      return res.json({ valid: true });
    } catch (error) {
      return res.status(500).json({ error: 'Erro ao verificar sessão' });
    }
  }
}

module.exports = new AuthController();