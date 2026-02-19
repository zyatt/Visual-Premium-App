function roleMiddleware(allowedRoles) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Não autenticado' });
    }

    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({ 
        error: 'Acesso negado',
        message: 'Você não tem permissão para acessar este recurso'
      });
    }

    next();
  };
}

function adminOnly(req, res, next) {
  return roleMiddleware(['admin'])(req, res, next);
}

function almoxarifadoAccess(req, res, next) {
  return roleMiddleware(['admin', 'compras'])(req, res, next);
}

module.exports = {
  roleMiddleware,
  adminOnly,
  almoxarifadoAccess,
};