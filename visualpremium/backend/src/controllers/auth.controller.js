const prisma = require('../config/prisma');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { JWT_SECRET } = require('../middlewares/auth.middleware');

class AuthController {
  async login(req, res) {
    try {
      const { username, password } = req.body;

      if (!username || !password) {
        return res.status(400).json({ 
          error: 'Usuário e senha são obrigatórios' 
        });
      }

      const usuario = await prisma.usuario.findUnique({
        where: { username },
      });

      if (!usuario) {
        return res.status(401).json({ 
          error: 'Usuário ou senha incorretos' 
        });
      }

      if (!usuario.ativo) {
        return res.status(401).json({ 
          error: 'Usuário ou senha incorretos' 
        });
      }

      const senhaValida = await bcrypt.compare(password, usuario.password);

      if (!senhaValida) {
        return res.status(401).json({ 
          error: 'Usuário ou senha incorretos' 
        });
      }

      const token = jwt.sign(
        { 
          id: usuario.id,
          username: usuario.username,
          role: usuario.role,
        },
        JWT_SECRET,
        { expiresIn: '7d' }
      );

      return res.json({
        id: usuario.id,
        username: usuario.username,
        nome: usuario.nome,
        role: usuario.role,
        token,
      });
    } catch (error) {
      console.error('Erro no login:', error);
      return res.status(500).json({ error: 'Erro ao fazer login' });
    }
  }

  async verificarSessao(req, res) {
    try {
      if (req.user) {
        return res.json({ 
          valid: true,
          user: req.user,
        });
      }
      
      return res.status(401).json({ 
        valid: false,
        error: 'Não autenticado',
      });
    } catch (error) {
      return res.status(500).json({ error: 'Erro ao verificar sessão' });
    }
  }
}

module.exports = new AuthController();