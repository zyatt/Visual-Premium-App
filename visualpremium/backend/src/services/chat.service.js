const prisma = require('../config/prisma');

class ChatService {
  async enviarMensagem(remetenteId, destinatarioId, conteudo) {
    if (!conteudo || conteudo.trim().length === 0) {
      throw new Error('Mensagem não pode estar vazia');
    }

    if (remetenteId === destinatarioId) {
      throw new Error('Não é possível enviar mensagem para si mesmo');
    }

    const destinatario = await prisma.usuario.findUnique({
      where: { id: destinatarioId },
    });

    if (!destinatario) {
      throw new Error('Destinatário não encontrado');
    }

    if (!destinatario.ativo) {
      throw new Error('Destinatário está inativo');
    }

    const mensagem = await prisma.mensagem.create({
      data: {
        remetenteId,
        destinatarioId,
        conteudo: conteudo.trim(),
      },
      include: {
        remetente: {
          select: {
            id: true,
            username: true,
            nome: true,
          },
        },
        destinatario: {
          select: {
            id: true,
            username: true,
            nome: true,
          },
        },
      },
    });

    return mensagem;
  }

  async listarConversas(usuarioId) {
    const mensagens = await prisma.mensagem.findMany({
      where: {
        OR: [
          { remetenteId: usuarioId },
          { destinatarioId: usuarioId },
        ],
      },
      include: {
        remetente: {
          select: {
            id: true,
            username: true,
            nome: true,
          },
        },
        destinatario: {
          select: {
            id: true,
            username: true,
            nome: true,
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    const conversasMap = new Map();

    for (const msg of mensagens) {
      const outroUsuarioId = msg.remetenteId === usuarioId 
        ? msg.destinatarioId 
        : msg.remetenteId;
      
      if (!conversasMap.has(outroUsuarioId)) {
        const outroUsuario = msg.remetenteId === usuarioId 
          ? msg.destinatario 
          : msg.remetente;

        const naoLidas = await prisma.mensagem.count({
          where: {
            remetenteId: outroUsuarioId,
            destinatarioId: usuarioId,
            lida: false,
          },
        });

        conversasMap.set(outroUsuarioId, {
          usuario: outroUsuario,
          ultimaMensagem: msg,
          naoLidas,
        });
      }
    }

    return Array.from(conversasMap.values());
  }

  async listarMensagens(usuarioId, outroUsuarioId, limit = 50) {
    const mensagens = await prisma.mensagem.findMany({
      where: {
        OR: [
          {
            remetenteId: usuarioId,
            destinatarioId: outroUsuarioId,
          },
          {
            remetenteId: outroUsuarioId,
            destinatarioId: usuarioId,
          },
        ],
      },
      include: {
        remetente: {
          select: {
            id: true,
            username: true,
            nome: true,
          },
        },
        destinatario: {
          select: {
            id: true,
            username: true,
            nome: true,
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
      take: limit,
    });

    await prisma.mensagem.updateMany({
      where: {
        remetenteId: outroUsuarioId,
        destinatarioId: usuarioId,
        lida: false,
      },
      data: {
        lida: true,
      },
    });

    return mensagens.reverse();
  }

  async contarNaoLidas(usuarioId) {
    return prisma.mensagem.count({
      where: {
        destinatarioId: usuarioId,
        lida: false,
      },
    });
  }

  async marcarComoLida(mensagemId, usuarioId) {
    const mensagem = await prisma.mensagem.findUnique({
      where: { id: mensagemId },
    });

    if (!mensagem) {
      throw new Error('Mensagem não encontrada');
    }

    if (mensagem.destinatarioId !== usuarioId) {
      throw new Error('Você não pode marcar esta mensagem como lida');
    }

    return prisma.mensagem.update({
      where: { id: mensagemId },
      data: { lida: true },
    });
  }
}

module.exports = new ChatService();