const prisma = require('../config/prisma');
const logService = require('../services/log.service');

class ConfiguracaoPrecoController {
  // ==================== CONFIGURAÇÃO GERAL ====================
  
  async obterConfig(req, res) {
    try {
      let config = await prisma.configuracaoPreco.findFirst();
      
      if (!config) {
        // Criar configuração padrão se não existir
        config = await prisma.configuracaoPreco.create({
          data: {
            faturamentoMedio: 0,
            custoOperacional: 0,
            custoProdutivo: null,
            percentualComissao: 5.0,
            percentualImpostos: 12.0,
            percentualJuros: 2.0,
            markupPadrao: 40.0
          }
        });
      }
      
      return res.json(config);
    } catch (error) {
      console.error('Erro ao obter configuração:', error);
      return res.status(500).json({ error: 'Erro ao obter configuração' });
    }
  }

  async atualizarConfig(req, res) {
    try {
      const {
        faturamentoMedio,
        custoOperacional,
        custoProdutivo,
        percentualComissao,
        percentualImpostos,
        percentualJuros,
        markupPadrao
      } = req.body;

      // Validações
      if (faturamentoMedio < 0) {
        return res.status(400).json({ error: 'Faturamento médio não pode ser negativo' });
      }

      if (custoOperacional < 0) {
        return res.status(400).json({ error: 'Custo operacional não pode ser negativo' });
      }

      let config = await prisma.configuracaoPreco.findFirst();
      
      const data = {
        faturamentoMedio: parseFloat(faturamentoMedio) || 0,
        custoOperacional: parseFloat(custoOperacional) || 0,
        custoProdutivo: custoProdutivo ? parseFloat(custoProdutivo) : null,
        percentualComissao: parseFloat(percentualComissao) || 5.0,
        percentualImpostos: parseFloat(percentualImpostos) || 12.0,
        percentualJuros: parseFloat(percentualJuros) || 2.0,
        markupPadrao: parseFloat(markupPadrao) || 40.0
      };

      if (config) {
        config = await prisma.configuracaoPreco.update({
          where: { id: config.id },
          data
        });
      } else {
        config = await prisma.configuracaoPreco.create({
          data
        });
      }

      await logService.registrar({
        usuarioId: req.user?.id || 1,
        usuarioNome: req.user?.nome || 'Sistema',
        acao: 'EDITAR',
        entidade: 'CONFIGURACAO_PRECO',
        entidadeId: config.id,
        descricao: 'Atualizou configuração de formação de preço',
        detalhes: config
      });

      return res.json(config);
    } catch (error) {
      console.error('Erro ao atualizar configuração:', error);
      return res.status(500).json({ error: 'Erro ao atualizar configuração' });
    }
  }

  // ==================== FOLHA DE PAGAMENTO ====================

  async listarFolhaPagamento(req, res) {
    try {
      const folha = await prisma.folhaPagamento.findMany({
        orderBy: { profissao: 'asc' }
      });
      return res.json(folha);
    } catch (error) {
      console.error('Erro ao listar folha de pagamento:', error);
      return res.status(500).json({ error: 'Erro ao listar folha de pagamento' });
    }
  }

  async criarFolhaPagamento(req, res) {
    try {
      const {
        profissao,
        salarioBase,
        quantidade,
        totalComEncargos,
        ehProdutivo
      } = req.body;

      // Validações
      if (!profissao || profissao.trim() === '') {
        return res.status(400).json({ error: 'Profissão é obrigatória' });
      }

      if (!salarioBase || salarioBase <= 0) {
        return res.status(400).json({ error: 'Salário base deve ser maior que zero' });
      }

      if (!quantidade || quantidade <= 0) {
        return res.status(400).json({ error: 'Quantidade deve ser maior que zero' });
      }

      if (!totalComEncargos || totalComEncargos <= 0) {
        return res.status(400).json({ error: 'Total com encargos deve ser maior que zero' });
      }

      const folha = await prisma.folhaPagamento.create({
        data: {
          profissao: profissao.trim(),
          salarioBase: parseFloat(salarioBase),
          quantidade: parseInt(quantidade),
          totalComEncargos: parseFloat(totalComEncargos),
          ehProdutivo: ehProdutivo || false
        }
      });

      await logService.registrar({
        usuarioId: req.user?.id || 1,
        usuarioNome: req.user?.nome || 'Sistema',
        acao: 'CRIAR',
        entidade: 'FOLHA_PAGAMENTO',
        entidadeId: folha.id,
        descricao: `Criou registro de folha de pagamento: ${folha.profissao}`,
        detalhes: folha
      });

      return res.status(201).json(folha);
    } catch (error) {
      console.error('Erro ao criar folha de pagamento:', error);
      return res.status(500).json({ error: 'Erro ao criar folha de pagamento' });
    }
  }

  async atualizarFolhaPagamento(req, res) {
    try {
      const { id } = req.params;
      const {
        profissao,
        salarioBase,
        quantidade,
        totalComEncargos,
        ehProdutivo
      } = req.body;

      const folhaAtual = await prisma.folhaPagamento.findUnique({
        where: { id: parseInt(id) }
      });

      if (!folhaAtual) {
        return res.status(404).json({ error: 'Registro não encontrado' });
      }

      const folha = await prisma.folhaPagamento.update({
        where: { id: parseInt(id) },
        data: {
          profissao: profissao.trim(),
          salarioBase: parseFloat(salarioBase),
          quantidade: parseInt(quantidade),
          totalComEncargos: parseFloat(totalComEncargos),
          ehProdutivo: ehProdutivo || false
        }
      });

      await logService.registrar({
        usuarioId: req.user?.id || 1,
        usuarioNome: req.user?.nome || 'Sistema',
        acao: 'EDITAR',
        entidade: 'FOLHA_PAGAMENTO',
        entidadeId: parseInt(id),
        descricao: `Editou registro de folha de pagamento: ${folha.profissao}`,
        detalhes: { antes: folhaAtual, depois: folha }
      });

      return res.json(folha);
    } catch (error) {
      console.error('Erro ao atualizar folha de pagamento:', error);
      return res.status(500).json({ error: 'Erro ao atualizar folha de pagamento' });
    }
  }

  async deletarFolhaPagamento(req, res) {
    try {
      const { id } = req.params;

      const folha = await prisma.folhaPagamento.findUnique({
        where: { id: parseInt(id) }
      });

      if (!folha) {
        return res.status(404).json({ error: 'Registro não encontrado' });
      }

      await prisma.folhaPagamento.delete({
        where: { id: parseInt(id) }
      });

      await logService.registrar({
        usuarioId: req.user?.id || 1,
        usuarioNome: req.user?.nome || 'Sistema',
        acao: 'DELETAR',
        entidade: 'FOLHA_PAGAMENTO',
        entidadeId: parseInt(id),
        descricao: `Excluiu registro de folha de pagamento: ${folha.profissao}`,
        detalhes: folha
      });

      return res.json({ message: 'Registro excluído com sucesso' });
    } catch (error) {
      console.error('Erro ao deletar folha de pagamento:', error);
      return res.status(500).json({ error: 'Erro ao deletar folha de pagamento' });
    }
  }

  // ==================== CÁLCULO DE PREVIEW ====================

  async calcularPreview(req, res) {
    try {
      const {
        materiais,
        despesasAdicionais,
        opcoesExtras,
        tempoProdutivoMinutos,
        percentualMarkup
      } = req.body;

      const formacaoPrecoService = require('../services/formacaoPreco.service');

      const resultado = await formacaoPrecoService.calcularFormacaoPrecoCompleta({
        materiais,
        despesasAdicionais,
        opcoesExtras,
        tempoProdutivoMinutos,
        percentualMarkup
      });

      return res.json(resultado);
    } catch (error) {
      console.error('Erro ao calcular preview:', error);
      return res.status(500).json({ 
        error: 'Erro ao calcular preview',
        message: error.message 
      });
    }
  }
}

module.exports = new ConfiguracaoPrecoController();