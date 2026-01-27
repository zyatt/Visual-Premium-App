/*
  Warnings:

  - You are about to drop the `Orcamento` table. If the table is not empty, all the data it contains will be lost.

*/
-- DropForeignKey
ALTER TABLE "Orcamento" DROP CONSTRAINT "Orcamento_produtoId_fkey";

-- DropForeignKey
ALTER TABLE "OrcamentoMaterial" DROP CONSTRAINT "OrcamentoMaterial_orcamentoId_fkey";

-- DropForeignKey
ALTER TABLE "Pedido" DROP CONSTRAINT "Pedido_orcamentoId_fkey";

-- DropTable
DROP TABLE "Orcamento";

-- CreateTable
CREATE TABLE "orcamentos" (
    "id" SERIAL NOT NULL,
    "cliente" TEXT NOT NULL,
    "numero" INTEGER NOT NULL,
    "status" TEXT NOT NULL,
    "produtoId" INTEGER NOT NULL,
    "despesaAdicional" BOOLEAN NOT NULL DEFAULT false,
    "despesaAdicionalDesc" TEXT,
    "despesaAdicionalValor" DOUBLE PRECISION,
    "frete" BOOLEAN NOT NULL DEFAULT false,
    "freteDesc" TEXT,
    "freteValor" DOUBLE PRECISION,
    "caminhaoMunck" BOOLEAN NOT NULL DEFAULT false,
    "caminhaoMunckHoras" DOUBLE PRECISION,
    "caminhaoMunckValorHora" DOUBLE PRECISION,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "orcamentos_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "orcamentos" ADD CONSTRAINT "orcamentos_produtoId_fkey" FOREIGN KEY ("produtoId") REFERENCES "Produto"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Pedido" ADD CONSTRAINT "Pedido_orcamentoId_fkey" FOREIGN KEY ("orcamentoId") REFERENCES "orcamentos"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "OrcamentoMaterial" ADD CONSTRAINT "OrcamentoMaterial_orcamentoId_fkey" FOREIGN KEY ("orcamentoId") REFERENCES "orcamentos"("id") ON DELETE CASCADE ON UPDATE CASCADE;
