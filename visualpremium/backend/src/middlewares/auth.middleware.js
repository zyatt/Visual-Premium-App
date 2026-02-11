const jwt = require('jsonwebtoken');
const prisma = require('../config/prisma');

const JWT_SECRET = process.env.JWT_SECRET || 'sua-chave-secreta-aqui';

async function authMiddleware(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader) {
      return res.status(401).json({ error: 'Token não fornecido' });
    }

    const parts = authHeader.split(' ');
    
    if (parts.length !== 2 || parts[0] !== 'Bearer') {
      return res.status(401).json({ error: 'Formato de token inválido' });
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

    if (!usuario) {
      return res.status(401).json({ error: 'Usuário não encontrado' });
    }

    if (!usuario.ativo) {
      return res.status(401).json({ error: 'Usuário inativo' });
    }

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
    next();
  }
}

module.exports = {
  authMiddleware,
  optionalAuthMiddleware,
  JWT_SECRET,
};  