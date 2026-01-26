const prisma = require('../config/prisma');

class PedidoService {
  listar() {
    return prisma.pedido.findMany({ include: { produto: true } });
  }

  criar(data) {
    return prisma.pedido.create({ data });
  }

  atualizar(id, data) {
    return prisma.pedido.update({ where: { id }, data });
  }

  deletar(id) {
    return prisma.pedido.delete({ where: { id } });
  }
}

module.exports = new PedidoService();
