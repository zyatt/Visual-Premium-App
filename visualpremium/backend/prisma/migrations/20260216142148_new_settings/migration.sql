-- AlterTable
ALTER TABLE "orcamentos" ADD COLUMN     "custoMaoObraProducao" DOUBLE PRECISION,
ADD COLUMN     "custoMinutoProdutivo" DOUBLE PRECISION,
ADD COLUMN     "percentualCustoFixo" DOUBLE PRECISION,
ADD COLUMN     "percentualMarkup" DOUBLE PRECISION,
ADD COLUMN     "percentualSobreVenda" DOUBLE PRECISION DEFAULT 19.00,
ADD COLUMN     "valorAntesMarkup" DOUBLE PRECISION,
ADD COLUMN     "valorBase" DOUBLE PRECISION,
ADD COLUMN     "valorComMarkup" DOUBLE PRECISION,
ADD COLUMN     "valorFinalVenda" DOUBLE PRECISION,
ADD COLUMN     "valorMateriaMinuto" DOUBLE PRECISION;

-- AlterTable
ALTER TABLE "produtos" ADD COLUMN     "tempoProdutivoMinutos" INTEGER NOT NULL DEFAULT 0;

-- CreateTable
CREATE TABLE "configuracao_preco" (
    "id" SERIAL NOT NULL,
    "faturamentoMedio" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "custoOperacional" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "custoProdutivo" DOUBLE PRECISION,
    "percentualComissao" DOUBLE PRECISION NOT NULL DEFAULT 5.0,
    "percentualImpostos" DOUBLE PRECISION NOT NULL DEFAULT 12.0,
    "percentualJuros" DOUBLE PRECISION NOT NULL DEFAULT 2.0,
    "markupPadrao" DOUBLE PRECISION NOT NULL DEFAULT 40.0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "configuracao_preco_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "folha_pagamento" (
    "id" SERIAL NOT NULL,
    "profissao" TEXT NOT NULL,
    "salarioBase" DOUBLE PRECISION NOT NULL,
    "quantidade" INTEGER NOT NULL,
    "totalComEncargos" DOUBLE PRECISION NOT NULL,
    "ehProdutivo" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "folha_pagamento_pkey" PRIMARY KEY ("id")
);
