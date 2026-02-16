-- AlterTable
ALTER TABLE "materiais" ADD COLUMN     "comprimento" DOUBLE PRECISION;

-- AlterTable
ALTER TABLE "orcamento_materiais" ADD COLUMN     "alturaSobra" DOUBLE PRECISION,
ADD COLUMN     "larguraSobra" DOUBLE PRECISION,
ADD COLUMN     "valorSobra" DOUBLE PRECISION;

-- AlterTable
ALTER TABLE "pedido_materiais" ADD COLUMN     "alturaSobra" DOUBLE PRECISION,
ADD COLUMN     "larguraSobra" DOUBLE PRECISION,
ADD COLUMN     "valorSobra" DOUBLE PRECISION;

-- CreateTable
CREATE TABLE "configuracao_imposto_sobra" (
    "id" SERIAL NOT NULL,
    "percentualImposto" DOUBLE PRECISION NOT NULL DEFAULT 18.0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "configuracao_imposto_sobra_pkey" PRIMARY KEY ("id")
);
