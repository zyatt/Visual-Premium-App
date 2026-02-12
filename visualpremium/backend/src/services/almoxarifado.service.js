const prisma = require('../config/prisma');
const logService = require('./log.service');

class AlmoxarifadoService {
  async listar() {
      return prisma.almoxarifado.findMany({
        include: {
          pedido: {
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
          pedido: {
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

    async buscarPorPedido(pedidoId) {
      return prisma.almoxarifado.findUnique({
        where: { pedidoId },
        include: {
          pedido: {
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

    async salvar(pedidoId, data, user) {
      try {
        const pedido = await prisma.pedido.findUnique({
          where: { id: pedidoId },
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

        if (!pedido) {
          throw new Error('Pedido não encontrado');
        }

        if (pedido.status !== 'Concluído') {
          throw new Error('Apenas pedidos concluídos podem ter almoxarifado registrado');
        }

        const { materiais, despesasAdicionais, opcoesExtras, observacoes } = data;

        const materiaisValidados = [];
        if (materiais && materiais.length > 0) {
          for (const m of materiais) {
            const materialPedido = pedido.materiais.find(pm => pm.materialId === m.materialId);
            if (!materialPedido) {
              throw new Error(`Material ${m.materialId} não pertence ao pedido`);
            }

            const custoRealizado = parseFloat(m.custoRealizado);
            if (isNaN(custoRealizado) || custoRealizado < 0) {
              throw new Error(`Custo realizado inválido para material ${materialPedido.material.nome}`);
            }

            materiaisValidados.push({
              materialId: m.materialId,
              quantidade: materialPedido.quantidade,
              custoRealizado: custoRealizado,
            });
          }
        }

        const despesasValidadas = [];
        if (despesasAdicionais && despesasAdicionais.length > 0) {
          for (const d of despesasAdicionais) {
            const despesaPedido = pedido.despesasAdicionais.find(
              pd => pd.descricao === d.descricao
            );

            if (!despesaPedido) {
              throw new Error(`Despesa "${d.descricao}" não pertence ao pedido`);
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
            const opcaoPedido = pedido.opcoesExtras.find(
              po => po.produtoOpcaoId === o.produtoOpcaoId
            );

            if (!opcaoPedido) {
              throw new Error(`Opção extra ${o.produtoOpcaoId} não pertence ao pedido`);
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
          where: { pedidoId }
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
                pedido: {
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
            descricao: `Atualizou dados do almoxarifado do pedido ${pedido.numero ? `#${pedido.numero}` : `(ID: ${pedido.id})`}`,
            detalhes: { pedidoId, materiaisCount: materiaisValidados.length }
          });
        } else {
          // Criar novo
          almoxarifado = await prisma.almoxarifado.create({
            data: {
              pedidoId,
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
              pedido: {
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
            descricao: `Criou registro de almoxarifado para pedido ${pedido.numero ? `#${pedido.numero}` : `(ID: ${pedido.id})`}`,
            detalhes: { pedidoId, materiaisCount: materiaisValidados.length }
          });
        }

        return almoxarifado;
      } catch (error) {
        throw error;
      }
    }  
  // MÉTODO FINALIZAR CORRIGIDO
  async finalizar(pedidoId, user) {
    try {
      const almoxarifado = await prisma.almoxarifado.findUnique({
        where: { pedidoId },
        include: {
          pedido: {
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

      const totalOrcadoMateriais = this._calcularTotalMateriais(almoxarifado.pedido.materiais);
      const totalOrcadoDespesas = this._calcularTotalDespesas(almoxarifado.pedido.despesasAdicionais);
      const totalOrcadoOpcoesExtras = this._calcularTotalOpcoesExtras(almoxarifado.pedido.opcoesExtras);
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

      const analiseDetalhada = this._gerarAnaliseDetalhada(almoxarifado.pedido, almoxarifado);

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
                  pedido: {
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
                  pedido: {
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
        descricao: `Finalizou almoxarifado do pedido ${almoxarifado.pedido.numero ? `#${almoxarifado.pedido.numero}` : `(ID: ${almoxarifado.pedido.id})`} e gerou relatório comparativo`,
        detalhes: {
          pedidoId,
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
  _gerarAnaliseDetalhada(pedido, almoxarifado) {
    const analise = {
      materiais: [],
      despesas: [],
      opcoesExtras: []
    };

    const EPSILON = 0.0001;

    // Análise de materiais
    for (const materialPed of pedido.materiais) {
      const materialAlm = almoxarifado.materiais.find(m => m.materialId === materialPed.materialId);
      
      const valorOrcado = materialPed.custo * materialPed.quantidade;
      const valorRealizado = materialAlm ? materialAlm.custoRealizado : 0;
      const diferenca = valorRealizado - valorOrcado;
      const percentual = Math.abs(valorOrcado) > EPSILON ? (diferenca / valorOrcado) * 100 : 0;

      analise.materiais.push({
        materialId: materialPed.materialId,
        materialNome: materialPed.material.nome,
        quantidade: materialPed.quantidade,
        unidade: materialPed.material.unidade,
        custoUnitarioOrcado: materialPed.custo,
        valorOrcado,
        custoRealizadoTotal: valorRealizado,
        diferenca,
        percentual,
        status: Math.abs(diferenca) < EPSILON ? 'igual' : (diferenca > 0 ? 'acima' : 'abaixo')
      });
    }

    // Análise de despesas
    for (const despesaPed of pedido.despesasAdicionais) {
      const despesaAlm = almoxarifado.despesasAdicionais.find(
        d => d.descricao === despesaPed.descricao
      );
      
      const valorOrcado = despesaPed.valor;
      const valorRealizado = despesaAlm ? despesaAlm.valorRealizado : 0;
      const diferenca = valorRealizado - valorOrcado;
      const percentual = Math.abs(valorOrcado) > EPSILON ? (diferenca / valorOrcado) * 100 : 0;

      analise.despesas.push({
        descricao: despesaPed.descricao,
        valorOrcado,
        valorRealizado,
        diferenca,
        percentual,
        status: Math.abs(diferenca) < EPSILON ? 'igual' : (diferenca > 0 ? 'acima' : 'abaixo')
      });
    }

    // Análise de opções extras
    for (const opcaoPed of pedido.opcoesExtras) {
      const opcaoAlm = almoxarifado.opcoesExtras.find(
        o => o.produtoOpcaoId === opcaoPed.produtoOpcaoId
      );
      
      let valorOrcado = 0;
      let valorRealizado = 0;

      if (opcaoPed.produtoOpcao.tipo === 'STRINGFLOAT') {
        valorOrcado = opcaoPed.valorFloat1 || 0;
        valorRealizado = opcaoAlm ? (opcaoAlm.valorFloat1 || 0) : 0;
      } else if (opcaoPed.produtoOpcao.tipo === 'FLOATFLOAT') {
        valorOrcado = (opcaoPed.valorFloat1 || 0) * (opcaoPed.valorFloat2 || 0);
        valorRealizado = opcaoAlm 
          ? ((opcaoAlm.valorFloat1 || 0) * (opcaoAlm.valorFloat2 || 0))
          : 0;
      } else if (opcaoPed.produtoOpcao.tipo === 'PERCENTFLOAT') {
        valorOrcado = ((opcaoPed.valorFloat1 || 0) / 100) * (opcaoPed.valorFloat2 || 0);
        valorRealizado = opcaoAlm 
          ? (((opcaoAlm.valorFloat1 || 0) / 100) * (opcaoAlm.valorFloat2 || 0))
          : 0;
      }

      const diferenca = valorRealizado - valorOrcado;
      const percentual = Math.abs(valorOrcado) > EPSILON ? (diferenca / valorOrcado) * 100 : 0;

      analise.opcoesExtras.push({
        nome: opcaoPed.produtoOpcao.nome,
        tipo: opcaoPed.produtoOpcao.tipo,
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
            pedido: {
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
            pedido: {
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
            pedido: {
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