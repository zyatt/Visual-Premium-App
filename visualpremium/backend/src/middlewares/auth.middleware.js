const jwt = require('jsonwebtoken');
const prisma = require('../config/prisma');

// Coloque uma chave secreta forte em produção (use variável de ambiente)
const JWT_SECRET = process.env.JWT_SECRET || 'sua-chave-secreta-aqui';

/**
 * Middleware para autenticação via JWT
 * Extrai o usuário do token e adiciona em req.user
 */
async function authMiddleware(req, res, next) {
  try {
    // Tenta extrair o token do header Authorization
    const authHeader = req.headers.authorization;
    
    if (!authHeader) {
      return res.status(401).json({ error: 'Token não fornecido' });
    }

    // Formato esperado: "Bearer TOKEN"
    const parts = authHeader.split(' ');
    
    if (parts.length !== 2 || parts[0] !== 'Bearer') {
      return res.status(401).json({ error: 'Formato de token inválido' });
    }

    const token = parts[1];

    // Verifica o token
    const decoded = jwt.verify(token, JWT_SECRET);

    // Busca o usuário no banco
    const usuario = await prisma.usuario.findUnique({
      where: { id: decoded.id },
      select: {
        id: true,
        username: true,
        nome: true,
        role: true,
        ativo: true,
      },
    });

    if (!usuario) {
      return res.status(401).json({ error: 'Usuário não encontrado' });
    }

    if (!usuario.ativo) {
      return res.status(401).json({ error: 'Usuário inativo' });
    }

    // Adiciona o usuário na requisição
    req.user = usuario;

    next();
  } catch (error) {
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({ error: 'Token inválido' });
    }
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Token expirado' });
    }
    
    return res.status(500).json({ error: 'Erro ao autenticar' });
  }
}

/**
 * Middleware opcional - não bloqueia se não houver token
 * Apenas adiciona req.user se o token for válido
 */
async function optionalAuthMiddleware(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader) {
      return next();
    }

    const parts = authHeader.split(' ');
    
    if (parts.length !== 2 || parts[0] !== 'Bearer') {
      return next();
    }

    const token = parts[1];
    const decoded = jwt.verify(token, JWT_SECRET);

    const usuario = await prisma.usuario.findUnique({
      where: { id: decoded.id },
      select: {
        id: true,
        username: true,
        nome: true,
        role: true,
        ativo: true,
      },
    });

    if (usuario && usuario.ativo) {
      req.user = usuario;
    }

    next();
  } catch (error) {
    // Ignora erros e continua sem autenticação
    next();
  }
}

module.exports = {
  authMiddleware,
  optionalAuthMiddleware,
  JWT_SECRET,
};  