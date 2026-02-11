const prisma = require('../config/prisma');
const logService = require('./log.service');

class AlmoxarifadoService {
  async listar() {
      return prisma.almoxarifado.findMany({
        include: {
          orcamento: {
            include: {
              produto: true,
              materiais: {
                include: {
                  material: true
                }
              },
              despesasAdicionais: true,
              opcoesExtras: {
                include: {
                  produtoOpcao: true
                }
              }
            }
          },
          materiais: {
            include: {
              material: true
            }
          },
          despesasAdicionais: true,
          opcoesExtras: {
            include: {
              produtoOpcao: true
            }
          },
          relatorioComparativo: true
        },
        orderBy: {
          createdAt: 'desc'
        }
      });
    }

    async buscarPorId(id) {
      const almoxarifado = await prisma.almoxarifado.findUnique({
        where: { id },
        include: {
          orcamento: {
            include: {
              produto: true,
              materiais: {
                include: {
                  material: true
                }
              },
              despesasAdicionais: true,
              opcoesExtras: {
                include: {
                  produtoOpcao: true
                }
              }
            }
          },
          materiais: {
            include: {
              material: true
            }
          },
          despesasAdicionais: true,
          opcoesExtras: {
            include: {
              produtoOpcao: true
            }
          },
          relatorioComparativo: true
        }
      });

      if (!almoxarifado) {
        throw new Error('Almoxarifado não encontrado');
      }

      return almoxarifado;
    }

    async buscarPorOrcamento(orcamentoId) {
      return prisma.almoxarifado.findUnique({
        where: { orcamentoId },
        include: {
          orcamento: {
            include: {
              produto: true,
              materiais: {
                include: {
                  material: true
                }
              },
              despesasAdicionais: true,
              opcoesExtras: {
                include: {
                  produtoOpcao: true
                }
              }
            }
          },
          materiais: {
            include: {
              material: true
            }
          },
          despesasAdicionais: true,
          opcoesExtras: {
            include: {
              produtoOpcao: true
            }
          },
          relatorioComparativo: true
        }
      });
    }

    async salvar(orcamentoId, data, user) {
      try {
        const orcamento = await prisma.orcamento.findUnique({
          where: { id: orcamentoId },
          include: {
            produto: true,
            materiais: {
              include: {
                material: true
              }
            },
            despesasAdicionais: true,
            opcoesExtras: {
              include: {
                produtoOpcao: true
              }
            }
          }
        });

        if (!orcamento) {
          throw new Error('Orçamento não encontrado');
        }

        if (orcamento.status !== 'Aprovado') {
          throw new Error('Apenas orçamentos aprovados podem ser registrados no almoxarifado');
        }

        const { materiais, despesasAdicionais, opcoesExtras, observacoes } = data;

        // Validar materiais
        const materiaisValidados = [];
        if (materiais && materiais.length > 0) {
          for (const m of materiais) {
            const materialOrcamento = orcamento.materiais.find(om => om.materialId === m.materialId);
            if (!materialOrcamento) {
              throw new Error(`Material ${m.materialId} não pertence ao orçamento`);
            }

            const custoRealizado = parseFloat(m.custoRealizado);
            if (isNaN(custoRealizado) || custoRealizado < 0) {
              throw new Error(`Custo realizado inválido para material ${materialOrcamento.material.nome}`);
            }

            materiaisValidados.push({
              materialId: m.materialId,
              quantidade: materialOrcamento.quantidade,
              custoRealizado: custoRealizado,
            });
          }
        }

        // Validar despesas adicionais
        const despesasValidadas = [];
        if (despesasAdicionais && despesasAdicionais.length > 0) {
          for (const d of despesasAdicionais) {
            const despesaOrcamento = orcamento.despesasAdicionais.find(
              od => od.descricao === d.descricao
            );

            if (!despesaOrcamento) {
              throw new Error(`Despesa "${d.descricao}" não pertence ao orçamento`);
            }

            const valorRealizado = parseFloat(d.valorRealizado);
            if (isNaN(valorRealizado) || valorRealizado < 0) {
              throw new Error(`Valor realizado inválido para despesa ${d.descricao}`);
            }

            despesasValidadas.push({
              descricao: d.descricao,
              valorRealizado: valorRealizado,
            });
          }
        }

        // Validar opções extras
        const opcoesExtrasValidadas = [];
        if (opcoesExtras && opcoesExtras.length > 0) {
          for (const o of opcoesExtras) {
            const opcaoOrcamento = orcamento.opcoesExtras.find(
              oo => oo.produtoOpcaoId === o.produtoOpcaoId
            );

            if (!opcaoOrcamento) {
              throw new Error(`Opção extra ${o.produtoOpcaoId} não pertence ao orçamento`);
            }

            const opcaoData = {
              produtoOpcaoId: o.produtoOpcaoId,
            };

            // Apenas adicionar os campos que foram enviados
            if (o.valorString !== undefined) {
              opcaoData.valorString = o.valorString;
            }
            
            if (o.valorFloat1 !== undefined) {
              opcaoData.valorFloat1 = parseFloat(o.valorFloat1);
            }
            
            if (o.valorFloat2 !== undefined) {
              opcaoData.valorFloat2 = parseFloat(o.valorFloat2);
            }

            opcoesExtrasValidadas.push(opcaoData);
          }
        }

        const almoxarifadoExistente = await prisma.almoxarifado.findUnique({
          where: { orcamentoId }
        });

        let almoxarifado;

        if (almoxarifadoExistente) {
          // Atualizar existente
          await prisma.$transaction(async (tx) => {
            // Deletar registros antigos
            await tx.almoxarifadoMaterial.deleteMany({
              where: { almoxarifadoId: almoxarifadoExistente.id }
            });
            await tx.almoxarifadoDespesa.deleteMany({
              where: { almoxarifadoId: almoxarifadoExistente.id }
            });
            await tx.almoxarifadoOpcaoExtra.deleteMany({
              where: { almoxarifadoId: almoxarifadoExistente.id }
            });

            // Atualizar almoxarifado
            almoxarifado = await tx.almoxarifado.update({
              where: { id: almoxarifadoExistente.id },
              data: {
                status: 'Não Realizado',
                observacoes: observacoes || null,
                materiais: {
                  create: materiaisValidados
                },
                despesasAdicionais: despesasValidadas.length > 0 ? {
                  create: despesasValidadas
                } : undefined,
                opcoesExtras: opcoesExtrasValidadas.length > 0 ? {
                  create: opcoesExtrasValidadas
                } : undefined,
              },
              include: {
                orcamento: {
                  include: {
                    produto: true,
                    materiais: { include: { material: true } },
                    despesasAdicionais: true,
                    opcoesExtras: { include: { produtoOpcao: true } }
                  }
                },
                materiais: { include: { material: true } },
                despesasAdicionais: true,
                opcoesExtras: { include: { produtoOpcao: true } }
              }
            });
          });

          await logService.registrar({
            usuarioId: user?.id || 1,
            usuarioNome: user?.nome || 'Sistema',
            acao: 'EDITAR',
            entidade: 'ALMOXARIFADO',
            entidadeId: almoxarifado.id,
            descricao: `Atualizou dados do almoxarifado do orçamento #${orcamento.numero}`,
            detalhes: { orcamentoId, materiaisCount: materiaisValidados.length }
          });
        } else {
          // Criar novo
          almoxarifado = await prisma.almoxarifado.create({
            data: {
              orcamentoId,
              status: 'Não Realizado',
              observacoes: observacoes || null,
              materiais: {
                create: materiaisValidados
              },
              despesasAdicionais: despesasValidadas.length > 0 ? {
                create: despesasValidadas
              } : undefined,
              opcoesExtras: opcoesExtrasValidadas.length > 0 ? {
                create: opcoesExtrasValidadas
              } : undefined,
            },
            include: {
              orcamento: {
                include: {
                  produto: true,
                  materiais: { include: { material: true } },
                  despesasAdicionais: true,
                  opcoesExtras: { include: { produtoOpcao: true } }
                }
              },
              materiais: { include: { material: true } },
              despesasAdicionais: true,
              opcoesExtras: { include: { produtoOpcao: true } }
            }
          });

          await logService.registrar({
            usuarioId: user?.id || 1,
            usuarioNome: user?.nome || 'Sistema',
            acao: 'CRIAR',
            entidade: 'ALMOXARIFADO',
            entidadeId: almoxarifado.id,
            descricao: `Criou registro de almoxarifado para orçamento #${orcamento.numero}`,
            detalhes: { orcamentoId, materiaisCount: materiaisValidados.length }
          });
        }

        return almoxarifado;
      } catch (error) {
        throw error;
      }
    }  
  // MÉTODO FINALIZAR CORRIGIDO
  async finalizar(orcamentoId, user) {
    try {
      const almoxarifado = await prisma.almoxarifado.findUnique({
        where: { orcamentoId },
        include: {
          orcamento: {
            include: {
              produto: true,
              materiais: {
                include: {
                  material: true
                }
              },
              despesasAdicionais: true,
              opcoesExtras: {
                include: {
                  produtoOpcao: true
                }
              }
            }
          },
          materiais: {
            include: {
              material: true
            }
          },
          despesasAdicionais: true,
          opcoesExtras: {
            include: {
              produtoOpcao: true
            }
          },
          relatorioComparativo: true
        }
      });

      if (!almoxarifado) {
        throw new Error('Almoxarifado não encontrado');
      }

      if (almoxarifado.status === 'Realizado') {
        throw new Error('Almoxarifado já finalizado');
      }

      const totalOrcadoMateriais = this._calcularTotalMateriais(almoxarifado.orcamento.materiais);
      const totalOrcadoDespesas = this._calcularTotalDespesas(almoxarifado.orcamento.despesasAdicionais);
      const totalOrcadoOpcoesExtras = this._calcularTotalOpcoesExtras(almoxarifado.orcamento.opcoesExtras);
      const totalOrcado = totalOrcadoMateriais + totalOrcadoDespesas + totalOrcadoOpcoesExtras;

      const totalRealizadoMateriais = this._calcularTotalMateriaisRealizados(almoxarifado.materiais);
      const totalRealizadoDespesas = this._calcularTotalDespesasRealizadas(almoxarifado.despesasAdicionais);
      const totalRealizadoOpcoesExtras = this._calcularTotalOpcoesExtrasRealizadas(almoxarifado.opcoesExtras);
      const totalRealizado = totalRealizadoMateriais + totalRealizadoDespesas + totalRealizadoOpcoesExtras;

      const diferencaMateriais = totalRealizadoMateriais - totalOrcadoMateriais;
      const diferencaDespesas = totalRealizadoDespesas - totalOrcadoDespesas;
      const diferencaOpcoesExtras = totalRealizadoOpcoesExtras - totalOrcadoOpcoesExtras;
      const diferencaTotal = totalRealizado - totalOrcado;

      const EPSILON = 0.0001;
      const percentualMateriais = Math.abs(totalOrcadoMateriais) > EPSILON 
        ? (diferencaMateriais / totalOrcadoMateriais) * 100 
        : 0;
      const percentualDespesas = Math.abs(totalOrcadoDespesas) > EPSILON 
        ? (diferencaDespesas / totalOrcadoDespesas) * 100 
        : 0;
      const percentualOpcoesExtras = Math.abs(totalOrcadoOpcoesExtras) > EPSILON 
        ? (diferencaOpcoesExtras / totalOrcadoOpcoesExtras) * 100 
        : 0;
      const percentualTotal = Math.abs(totalOrcado) > EPSILON 
        ? (diferencaTotal / totalOrcado) * 100 
        : 0;

      const analiseDetalhada = this._gerarAnaliseDetalhada(almoxarifado.orcamento, almoxarifado);

      const resultado = await prisma.$transaction(async (tx) => {
        const almoxarifadoAtualizado = await tx.almoxarifado.update({
          where: { id: almoxarifado.id },
          data: {
            status: 'Realizado',
            finalizadoEm: new Date(),
            finalizadoPor: user.username
          }
        });

        const relatorioExistente = await tx.relatorioComparativo.findUnique({
          where: { almoxarifadoId: almoxarifado.id }
        });

        let relatorio;
        if (relatorioExistente) {
          relatorio = await tx.relatorioComparativo.update({
            where: { id: relatorioExistente.id },
            data: {
              totalOrcadoMateriais,
              totalOrcadoDespesas,
              totalOrcadoOpcoesExtras,
              totalOrcado,
              totalRealizadoMateriais,
              totalRealizadoDespesas,
              totalRealizadoOpcoesExtras,
              totalRealizado,
              diferencaMateriais,
              diferencaDespesas,
              diferencaOpcoesExtras,
              diferencaTotal,
              percentualMateriais,
              percentualDespesas,
              percentualOpcoesExtras,
              percentualTotal,
              analiseDetalhada,
              updatedAt: new Date()
            },
            include: {
              almoxarifado: {
                include: {
                  orcamento: {
                    include: {
                      produto: true
                    }
                  }
                }
              }
            }
          });
        } else {
          relatorio = await tx.relatorioComparativo.create({
            data: {
              almoxarifadoId: almoxarifado.id,
              totalOrcadoMateriais,
              totalOrcadoDespesas,
              totalOrcadoOpcoesExtras,
              totalOrcado,
              totalRealizadoMateriais,
              totalRealizadoDespesas,
              totalRealizadoOpcoesExtras,
              totalRealizado,
              diferencaMateriais,
              diferencaDespesas,
              diferencaOpcoesExtras,
              diferencaTotal,
              percentualMateriais,
              percentualDespesas,
              percentualOpcoesExtras,
              percentualTotal,
              analiseDetalhada
            },
            include: {
              almoxarifado: {
                include: {
                  orcamento: {
                    include: {
                      produto: true
                    }
                  }
                }
              }
            }
          });
        }

        return {
          almoxarifado: almoxarifadoAtualizado,
          relatorio
        };
      });

      await logService.registrar({
        usuarioId: user.id,
        usuarioNome: user.nome,
        acao: 'FINALIZAR',
        entidade: 'ALMOXARIFADO',
        entidadeId: almoxarifado.id,
        descricao: `Finalizou almoxarifado do orçamento #${almoxarifado.orcamento.numero} e gerou relatório comparativo`,
        detalhes: {
          orcamentoId,
          totalOrcado,
          totalRealizado,
          diferencaTotal,
          percentualTotal,
          relatorioId: resultado.relatorio.id
        }
      });

      return resultado;
    } catch (error) {
      throw error;
    }
  }

  _calcularTotalMateriais(materiais) {
    return materiais.reduce((total, m) => total + (m.custo * m.quantidade), 0);
  }

  _calcularTotalDespesas(despesas) {
    return despesas.reduce((total, d) => total + d.valor, 0);
  }

  // Calcular total de opções extras orçadas
  _calcularTotalOpcoesExtras(opcoesExtras) {
    return opcoesExtras.reduce((total, opcao) => {
      if (opcao.produtoOpcao.tipo === 'STRINGFLOAT') {
        return total + (opcao.valorFloat1 || 0);
      } else if (opcao.produtoOpcao.tipo === 'FLOATFLOAT') {
        return total + ((opcao.valorFloat1 || 0) * (opcao.valorFloat2 || 0));
      } else if (opcao.produtoOpcao.tipo === 'PERCENTFLOAT') {
        return total + (((opcao.valorFloat1 || 0) / 100) * (opcao.valorFloat2 || 0));
      }
      return total;
    }, 0);
  }

  // Calcular total de materiais realizados
  _calcularTotalMateriaisRealizados(materiais) {
    return materiais.reduce((total, m) => total + m.custoRealizado, 0);
  }

  // Calcular total de despesas realizadas
  _calcularTotalDespesasRealizadas(despesas) {
    return despesas.reduce((total, d) => total + d.valorRealizado, 0);
  }

  // Calcular total de opções extras realizadas
  _calcularTotalOpcoesExtrasRealizadas(opcoesExtras) {
    return opcoesExtras.reduce((total, opcao) => {
      if (opcao.produtoOpcao.tipo === 'STRINGFLOAT') {
        return total + (opcao.valorFloat1 || 0);
      } else if (opcao.produtoOpcao.tipo === 'FLOATFLOAT') {
        return total + ((opcao.valorFloat1 || 0) * (opcao.valorFloat2 || 0));
      } else if (opcao.produtoOpcao.tipo === 'PERCENTFLOAT') {
        return total + (((opcao.valorFloat1 || 0) / 100) * (opcao.valorFloat2 || 0));
      }
      return total;
    }, 0);
  }

  // Gerar análise detalhada
  _gerarAnaliseDetalhada(orcamento, almoxarifado) {
    const analise = {
      materiais: [],
      despesas: [],
      opcoesExtras: []
    };

    const EPSILON = 0.0001;

    // Análise de materiais
    for (const materialOrc of orcamento.materiais) {
      const materialAlm = almoxarifado.materiais.find(m => m.materialId === materialOrc.materialId);
      
      const valorOrcado = materialOrc.custo * materialOrc.quantidade;
      const valorRealizado = materialAlm ? materialAlm.custoRealizado : 0;
      const diferenca = valorRealizado - valorOrcado;
      const percentual = Math.abs(valorOrcado) > EPSILON ? (diferenca / valorOrcado) * 100 : 0;

      analise.materiais.push({
        materialId: materialOrc.materialId,
        materialNome: materialOrc.material.nome,
        quantidade: materialOrc.quantidade,
        unidade: materialOrc.material.unidade,
        custoUnitarioOrcado: materialOrc.custo,
        valorOrcado,
        custoRealizadoTotal: valorRealizado,
        diferenca,
        percentual,
        status: Math.abs(diferenca) < EPSILON ? 'igual' : (diferenca > 0 ? 'acima' : 'abaixo')
      });
    }

    // Análise de despesas
    for (const despesaOrc of orcamento.despesasAdicionais) {
      const despesaAlm = almoxarifado.despesasAdicionais.find(
        d => d.descricao === despesaOrc.descricao
      );
      
      const valorOrcado = despesaOrc.valor;
      const valorRealizado = despesaAlm ? despesaAlm.valorRealizado : 0;
      const diferenca = valorRealizado - valorOrcado;
      const percentual = Math.abs(valorOrcado) > EPSILON ? (diferenca / valorOrcado) * 100 : 0;

      analise.despesas.push({
        descricao: despesaOrc.descricao,
        valorOrcado,
        valorRealizado,
        diferenca,
        percentual,
        status: Math.abs(diferenca) < EPSILON ? 'igual' : (diferenca > 0 ? 'acima' : 'abaixo')
      });
    }

    // Análise de opções extras
    for (const opcaoOrc of orcamento.opcoesExtras) {
      const opcaoAlm = almoxarifado.opcoesExtras.find(
        o => o.produtoOpcaoId === opcaoOrc.produtoOpcaoId
      );
      
      let valorOrcado = 0;
      let valorRealizado = 0;

      if (opcaoOrc.produtoOpcao.tipo === 'STRINGFLOAT') {
        valorOrcado = opcaoOrc.valorFloat1 || 0;
        valorRealizado = opcaoAlm ? (opcaoAlm.valorFloat1 || 0) : 0;
      } else if (opcaoOrc.produtoOpcao.tipo === 'FLOATFLOAT') {
        valorOrcado = (opcaoOrc.valorFloat1 || 0) * (opcaoOrc.valorFloat2 || 0);
        valorRealizado = opcaoAlm 
          ? ((opcaoAlm.valorFloat1 || 0) * (opcaoAlm.valorFloat2 || 0))
          : 0;
      } else if (opcaoOrc.produtoOpcao.tipo === 'PERCENTFLOAT') {
        valorOrcado = ((opcaoOrc.valorFloat1 || 0) / 100) * (opcaoOrc.valorFloat2 || 0);
        valorRealizado = opcaoAlm 
          ? (((opcaoAlm.valorFloat1 || 0) / 100) * (opcaoAlm.valorFloat2 || 0))
          : 0;
      }

      const diferenca = valorRealizado - valorOrcado;
      const percentual = Math.abs(valorOrcado) > EPSILON ? (diferenca / valorOrcado) * 100 : 0;

      analise.opcoesExtras.push({
        nome: opcaoOrc.produtoOpcao.nome,
        tipo: opcaoOrc.produtoOpcao.tipo,
        valorOrcado,
        valorRealizado,
        diferenca,
        percentual,
        status: Math.abs(diferenca) < EPSILON ? 'igual' : (diferenca > 0 ? 'acima' : 'abaixo')
      });
    }

    return analise;
  }

  // Listar relatórios comparativos
  async listarRelatorios() {
    return prisma.relatorioComparativo.findMany({
      include: {
        almoxarifado: {
          include: {
            orcamento: {
              include: {
                produto: true
              }
            }
          }
        }
      },
      orderBy: {
        createdAt: 'desc'
      }
    });
  }

  async buscarRelatorioPorId(id) {
    
    const relatorio = await prisma.relatorioComparativo.findUnique({
      where: { id: parseInt(id, 10) },
      include: {
        almoxarifado: {
          include: {
            orcamento: {
              include: {
                produto: true
              }
            }
          }
        }
      }
    });

    if (!relatorio) {
      throw new Error('Relatório comparativo não encontrado');
    }

    return relatorio;
  }

  async buscarRelatorioPorAlmoxarifadoId(almoxarifadoId) {
    
    const relatorio = await prisma.relatorioComparativo.findUnique({
      where: { 
        almoxarifadoId: parseInt(almoxarifadoId, 10) 
      },
      include: {
        almoxarifado: {
          include: {
            orcamento: {
              include: {
                produto: true
              }
            }
          }
        }
      }
    });

    if (!relatorio) {
      const almoxarifado = await prisma.almoxarifado.findUnique({
        where: { id: parseInt(almoxarifadoId, 10) },
        select: { id: true, status: true, finalizadoEm: true }
      });
      
      if (!almoxarifado) {
        throw new Error('Almoxarifado não encontrado');
      }
      
      if (almoxarifado.status !== 'Realizado') {
        throw new Error('Almoxarifado ainda não foi finalizado. Finalize o almoxarifado antes de gerar o relatório.');
      }
      
      throw new Error('Relatório comparativo não foi gerado para este almoxarifado. Tente finalizar o almoxarifado novamente.');
    }

    return relatorio;
  }
}

module.exports = new AlmoxarifadoService();