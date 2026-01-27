/*
  Warnings:

  - You are about to drop the column `despesaAdicional` on the `orcamentos` table. All the data in the column will be lost.
  - You are about to drop the column `despesaAdicionalDesc` on the `orcamentos` table. All the data in the column will be lost.
  - You are about to drop the column `despesaAdicionalValor` on the `orcamentos` table. All the data in the column will be lost.

*/
-- AlterTable
ALTER TABLE "orcamentos" DROP COLUMN "despesaAdicional",
DROP COLUMN "despesaAdicionalDesc",
DROP COLUMN "despesaAdicionalValor";

-- CreateTable
CREATE TABLE "despesas_adicionais" (
    "id" SERIAL NOT NULL,
    "orcamentoId" INTEGER NOT NULL,
    "descricao" TEXT NOT NULL,
    "valor" DOUBLE PRECISION NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "despesas_adicionais_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "despesas_adicionais" ADD CONSTRAINT "despesas_adicionais_orcamentoId_fkey" FOREIGN KEY ("orcamentoId") REFERENCES "orcamentos"("id") ON DELETE CASCADE ON UPDATE CASCADE;
