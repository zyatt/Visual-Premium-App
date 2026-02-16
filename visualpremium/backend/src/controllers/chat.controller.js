const chatService = require('../services/chat.service');

class ChatController {
  async enviarMensagem(req, res) {
    try {
      const { destinatarioId, conteudo } = req.body;
      const remetenteId = req.user.id;

      if (!destinatarioId || !conteudo) {
        return res.status(400).json({ 
          error: 'Destinatário e conteúdo são obrigatórios' 
        });
      }

      const mensagem = await chatService.enviarMensagem(
        remetenteId,
        destinatarioId,
        conteudo
      );

      return res.status(201).json(mensagem);
    } catch (error) {
      return res.status(400).json({ error: error.message });
    }
  }

  async listarConversas(req, res) {
    try {
      const usuarioId = req.user.id;
      const conversas = await chatService.listarConversas(usuarioId);
      return res.json(conversas);
    } catch (error) {
      return res.status(500).json({ error: error.message });
    }
  }

  async listarMensagens(req, res) {
    try {
      const usuarioId = req.user.id;
      const outroUsuarioId = parseInt(req.params.usuarioId);
      const limit = parseInt(req.query.limit) || 50;

      if (isNaN(outroUsuarioId)) {
        return res.status(400).json({ error: 'ID de usuário inválido' });
      }

      const mensagens = await chatService.listarMensagens(
        usuarioId,
        outroUsuarioId,
        limit
      );

      return res.json(mensagens);
    } catch (error) {
      return res.status(500).json({ error: error.message });
    }
  }

  async contarNaoLidas(req, res) {
    try {
      const usuarioId = req.user.id;
      const count = await chatService.contarNaoLidas(usuarioId);
      return res.json({ count });
    } catch (error) {
      return res.status(500).json({ error: error.message });
    }
  }

  async marcarComoLida(req, res) {
    try {
      const mensagemId = parseInt(req.params.id);
      const usuarioId = req.user.id;

      if (isNaN(mensagemId)) {
        return res.status(400).json({ error: 'ID de mensagem inválido' });
      }

      await chatService.marcarComoLida(mensagemId, usuarioId);
      return res.status(204).send();
    } catch (error) {
      return res.status(400).json({ error: error.message });
    }
  }
}

module.exports = new ChatController();