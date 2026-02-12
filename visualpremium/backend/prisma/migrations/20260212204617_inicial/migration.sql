-- CreateEnum
CREATE TYPE "TipoOpcaoExtra" AS ENUM ('STRINGFLOAT', 'FLOATFLOAT', 'PERCENTFLOAT');

-- CreateTable
CREATE TABLE "logs" (
    "id" SERIAL NOT NULL,
    "usuarioId" INTEGER NOT NULL,
    "usuarioNome" TEXT NOT NULL,
    "acao" TEXT NOT NULL,
    "entidade" TEXT NOT NULL,
    "entidadeId" INTEGER NOT NULL,
    "descricao" TEXT NOT NULL,
    "detalhes" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "usuarios" (
    "id" SERIAL NOT NULL,
    "username" TEXT NOT NULL,
    "password" TEXT NOT NULL,
    "nome" TEXT NOT NULL,
    "role" TEXT NOT NULL DEFAULT 'user',
    "ativo" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "usuarios_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "produtos" (
    "id" SERIAL NOT NULL,
    "nome" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "produtos_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "produto_avisos" (
    "id" SERIAL NOT NULL,
    "produtoId" INTEGER NOT NULL,
    "mensagem" TEXT NOT NULL,
    "materialId" INTEGER,
    "opcaoExtraId" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "produto_avisos_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "produto_opcoes_extras" (
    "id" SERIAL NOT NULL,
    "produtoId" INTEGER NOT NULL,
    "nome" TEXT NOT NULL,
    "tipo" "TipoOpcaoExtra" NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "produto_opcoes_extras_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "orcamentos" (
    "id" SERIAL NOT NULL,
    "cliente" TEXT NOT NULL,
    "numero" INTEGER NOT NULL,
    "status" TEXT NOT NULL,
    "produtoId" INTEGER NOT NULL,
    "formaPagamento" TEXT NOT NULL,
    "condicoesPagamento" TEXT NOT NULL,
    "prazoEntrega" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "orcamentos_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "orcamento_informacoes_adicionais" (
    "id" SERIAL NOT NULL,
    "orcamentoId" INTEGER NOT NULL,
    "data" TIMESTAMP(3) NOT NULL,
    "descricao" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "orcamento_informacoes_adicionais_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "orcamento_opcoes_extras" (
    "id" SERIAL NOT NULL,
    "orcamentoId" INTEGER NOT NULL,
    "produtoOpcaoId" INTEGER NOT NULL,
    "valorString" TEXT,
    "valorFloat1" DOUBLE PRECISION,
    "valorFloat2" DOUBLE PRECISION,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "orcamento_opcoes_extras_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pedidos" (
    "id" SERIAL NOT NULL,
    "cliente" TEXT NOT NULL,
    "numero" INTEGER,
    "status" TEXT NOT NULL,
    "produtoId" INTEGER NOT NULL,
    "formaPagamento" TEXT NOT NULL,
    "condicoesPagamento" TEXT NOT NULL,
    "prazoEntrega" TEXT NOT NULL,
    "orcamentoId" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "pedidos_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pedido_informacoes_adicionais" (
    "id" SERIAL NOT NULL,
    "pedidoId" INTEGER NOT NULL,
    "data" TIMESTAMP(3) NOT NULL,
    "descricao" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "pedido_informacoes_adicionais_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pedido_opcoes_extras" (
    "id" SERIAL NOT NULL,
    "pedidoId" INTEGER NOT NULL,
    "produtoOpcaoId" INTEGER NOT NULL,
    "valorString" TEXT,
    "valorFloat1" DOUBLE PRECISION,
    "valorFloat2" DOUBLE PRECISION,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pedido_opcoes_extras_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "despesas_adicionais" (
    "id" SERIAL NOT NULL,
    "orcamentoId" INTEGER NOT NULL,
    "descricao" TEXT NOT NULL,
    "valor" DOUBLE PRECISION NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "despesas_adicionais_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pedidos_despesas_adicionais" (
    "id" SERIAL NOT NULL,
    "pedidoId" INTEGER NOT NULL,
    "descricao" TEXT NOT NULL,
    "valor" DOUBLE PRECISION NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pedidos_despesas_adicionais_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "materiais" (
    "id" SERIAL NOT NULL,
    "nome" TEXT NOT NULL,
    "custo" DOUBLE PRECISION NOT NULL,
    "unidade" TEXT NOT NULL,
    "quantidade" DOUBLE PRECISION NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "materiais_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "produto_materiais" (
    "id" SERIAL NOT NULL,
    "produtoId" INTEGER NOT NULL,
    "materialId" INTEGER NOT NULL,

    CONSTRAINT "produto_materiais_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "orcamento_materiais" (
    "id" SERIAL NOT NULL,
    "orcamentoId" INTEGER NOT NULL,
    "materialId" INTEGER NOT NULL,
    "quantidade" DOUBLE PRECISION NOT NULL,
    "custo" DOUBLE PRECISION NOT NULL,

    CONSTRAINT "orcamento_materiais_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pedido_materiais" (
    "id" SERIAL NOT NULL,
    "pedidoId" INTEGER NOT NULL,
    "materialId" INTEGER NOT NULL,
    "quantidade" DOUBLE PRECISION NOT NULL,
    "custo" DOUBLE PRECISION NOT NULL,

    CONSTRAINT "pedido_materiais_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "almoxarifados" (
    "id" SERIAL NOT NULL,
    "pedidoId" INTEGER NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'Não Realizado',
    "observacoes" TEXT,
    "finalizadoEm" TIMESTAMP(3),
    "finalizadoPor" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "almoxarifados_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "almoxarifado_materiais" (
    "id" SERIAL NOT NULL,
    "almoxarifadoId" INTEGER NOT NULL,
    "materialId" INTEGER NOT NULL,
    "quantidade" DOUBLE PRECISION NOT NULL,
    "custoRealizado" DOUBLE PRECISION NOT NULL,

    CONSTRAINT "almoxarifado_materiais_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "almoxarifado_despesas" (
    "id" SERIAL NOT NULL,
    "almoxarifadoId" INTEGER NOT NULL,
    "descricao" TEXT NOT NULL,
    "valorRealizado" DOUBLE PRECISION NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "almoxarifado_despesas_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "almoxarifado_opcoes_extras" (
    "id" SERIAL NOT NULL,
    "almoxarifadoId" INTEGER NOT NULL,
    "produtoOpcaoId" INTEGER NOT NULL,
    "valorString" TEXT,
    "valorFloat1" DOUBLE PRECISION,
    "valorFloat2" DOUBLE PRECISION,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "almoxarifado_opcoes_extras_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "relatorios_comparativos" (
    "id" SERIAL NOT NULL,
    "almoxarifadoId" INTEGER NOT NULL,
    "totalOrcadoMateriais" DOUBLE PRECISION NOT NULL,
    "totalOrcadoDespesas" DOUBLE PRECISION NOT NULL,
    "totalOrcadoOpcoesExtras" DOUBLE PRECISION NOT NULL,
    "totalOrcado" DOUBLE PRECISION NOT NULL,
    "totalRealizadoMateriais" DOUBLE PRECISION NOT NULL,
    "totalRealizadoDespesas" DOUBLE PRECISION NOT NULL,
    "totalRealizadoOpcoesExtras" DOUBLE PRECISION NOT NULL,
    "totalRealizado" DOUBLE PRECISION NOT NULL,
    "diferencaMateriais" DOUBLE PRECISION NOT NULL,
    "diferencaDespesas" DOUBLE PRECISION NOT NULL,
    "diferencaOpcoesExtras" DOUBLE PRECISION NOT NULL,
    "diferencaTotal" DOUBLE PRECISION NOT NULL,
    "percentualMateriais" DOUBLE PRECISION NOT NULL,
    "percentualDespesas" DOUBLE PRECISION NOT NULL,
    "percentualOpcoesExtras" DOUBLE PRECISION NOT NULL,
    "percentualTotal" DOUBLE PRECISION NOT NULL,
    "analiseDetalhada" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "relatorios_comparativos_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "faixas_custo_margem" (
    "id" SERIAL NOT NULL,
    "custoInicio" DOUBLE PRECISION NOT NULL,
    "custoFim" DOUBLE PRECISION,
    "margem" DOUBLE PRECISION NOT NULL,
    "ordem" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "faixas_custo_margem_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "usuarios_username_key" ON "usuarios"("username");

-- CreateIndex
CREATE UNIQUE INDEX "produto_opcoes_extras_produtoId_nome_key" ON "produto_opcoes_extras"("produtoId", "nome");

-- CreateIndex
CREATE UNIQUE INDEX "orcamentos_numero_key" ON "orcamentos"("numero");

-- CreateIndex
CREATE UNIQUE INDEX "orcamento_opcoes_extras_orcamentoId_produtoOpcaoId_key" ON "orcamento_opcoes_extras"("orcamentoId", "produtoOpcaoId");

-- CreateIndex
CREATE UNIQUE INDEX "pedidos_numero_key" ON "pedidos"("numero");

-- CreateIndex
CREATE UNIQUE INDEX "pedidos_orcamentoId_key" ON "pedidos"("orcamentoId");

-- CreateIndex
CREATE UNIQUE INDEX "pedido_opcoes_extras_pedidoId_produtoOpcaoId_key" ON "pedido_opcoes_extras"("pedidoId", "produtoOpcaoId");

-- CreateIndex
CREATE UNIQUE INDEX "produto_materiais_produtoId_materialId_key" ON "produto_materiais"("produtoId", "materialId");

-- CreateIndex
CREATE UNIQUE INDEX "almoxarifados_pedidoId_key" ON "almoxarifados"("pedidoId");

-- CreateIndex
CREATE UNIQUE INDEX "almoxarifado_opcoes_extras_almoxarifadoId_produtoOpcaoId_key" ON "almoxarifado_opcoes_extras"("almoxarifadoId", "produtoOpcaoId");

-- CreateIndex
CREATE UNIQUE INDEX "relatorios_comparativos_almoxarifadoId_key" ON "relatorios_comparativos"("almoxarifadoId");

-- AddForeignKey
ALTER TABLE "produto_avisos" ADD CONSTRAINT "produto_avisos_materialId_fkey" FOREIGN KEY ("materialId") REFERENCES "materiais"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "produto_avisos" ADD CONSTRAINT "produto_avisos_opcaoExtraId_fkey" FOREIGN KEY ("opcaoExtraId") REFERENCES "produto_opcoes_extras"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "produto_avisos" ADD CONSTRAINT "produto_avisos_produtoId_fkey" FOREIGN KEY ("produtoId") REFERENCES "produtos"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "produto_opcoes_extras" ADD CONSTRAINT "produto_opcoes_extras_produtoId_fkey" FOREIGN KEY ("produtoId") REFERENCES "produtos"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "orcamentos" ADD CONSTRAINT "orcamentos_produtoId_fkey" FOREIGN KEY ("produtoId") REFERENCES "produtos"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "orcamento_informacoes_adicionais" ADD CONSTRAINT "orcamento_informacoes_adicionais_orcamentoId_fkey" FOREIGN KEY ("orcamentoId") REFERENCES "orcamentos"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "orcamento_opcoes_extras" ADD CONSTRAINT "orcamento_opcoes_extras_orcamentoId_fkey" FOREIGN KEY ("orcamentoId") REFERENCES "orcamentos"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "orcamento_opcoes_extras" ADD CONSTRAINT "orcamento_opcoes_extras_produtoOpcaoId_fkey" FOREIGN KEY ("produtoOpcaoId") REFERENCES "produto_opcoes_extras"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pedidos" ADD CONSTRAINT "pedidos_orcamentoId_fkey" FOREIGN KEY ("orcamentoId") REFERENCES "orcamentos"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pedidos" ADD CONSTRAINT "pedidos_produtoId_fkey" FOREIGN KEY ("produtoId") REFERENCES "produtos"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pedido_informacoes_adicionais" ADD CONSTRAINT "pedido_informacoes_adicionais_pedidoId_fkey" FOREIGN KEY ("pedidoId") REFERENCES "pedidos"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pedido_opcoes_extras" ADD CONSTRAINT "pedido_opcoes_extras_pedidoId_fkey" FOREIGN KEY ("pedidoId") REFERENCES "pedidos"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pedido_opcoes_extras" ADD CONSTRAINT "pedido_opcoes_extras_produtoOpcaoId_fkey" FOREIGN KEY ("produtoOpcaoId") REFERENCES "produto_opcoes_extras"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "despesas_adicionais" ADD CONSTRAINT "despesas_adicionais_orcamentoId_fkey" FOREIGN KEY ("orcamentoId") REFERENCES "orcamentos"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pedidos_despesas_adicionais" ADD CONSTRAINT "pedidos_despesas_adicionais_pedidoId_fkey" FOREIGN KEY ("pedidoId") REFERENCES "pedidos"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "produto_materiais" ADD CONSTRAINT "produto_materiais_materialId_fkey" FOREIGN KEY ("materialId") REFERENCES "materiais"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "produto_materiais" ADD CONSTRAINT "produto_materiais_produtoId_fkey" FOREIGN KEY ("produtoId") REFERENCES "produtos"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "orcamento_materiais" ADD CONSTRAINT "orcamento_materiais_materialId_fkey" FOREIGN KEY ("materialId") REFERENCES "materiais"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "orcamento_materiais" ADD CONSTRAINT "orcamento_materiais_orcamentoId_fkey" FOREIGN KEY ("orcamentoId") REFERENCES "orcamentos"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pedido_materiais" ADD CONSTRAINT "pedido_materiais_materialId_fkey" FOREIGN KEY ("materialId") REFERENCES "materiais"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pedido_materiais" ADD CONSTRAINT "pedido_materiais_pedidoId_fkey" FOREIGN KEY ("pedidoId") REFERENCES "pedidos"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "almoxarifados" ADD CONSTRAINT "almoxarifados_pedidoId_fkey" FOREIGN KEY ("pedidoId") REFERENCES "pedidos"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "almoxarifado_materiais" ADD CONSTRAINT "almoxarifado_materiais_almoxarifadoId_fkey" FOREIGN KEY ("almoxarifadoId") REFERENCES "almoxarifados"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "almoxarifado_materiais" ADD CONSTRAINT "almoxarifado_materiais_materialId_fkey" FOREIGN KEY ("materialId") REFERENCES "materiais"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "almoxarifado_despesas" ADD CONSTRAINT "almoxarifado_despesas_almoxarifadoId_fkey" FOREIGN KEY ("almoxarifadoId") REFERENCES "almoxarifados"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "almoxarifado_opcoes_extras" ADD CONSTRAINT "almoxarifado_opcoes_extras_almoxarifadoId_fkey" FOREIGN KEY ("almoxarifadoId") REFERENCES "almoxarifados"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "almoxarifado_opcoes_extras" ADD CONSTRAINT "almoxarifado_opcoes_extras_produtoOpcaoId_fkey" FOREIGN KEY ("produtoOpcaoId") REFERENCES "produto_opcoes_extras"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "relatorios_comparativos" ADD CONSTRAINT "relatorios_comparativos_almoxarifadoId_fkey" FOREIGN KEY ("almoxarifadoId") REFERENCES "almoxarifados"("id") ON DELETE CASCADE ON UPDATE CASCADE;
