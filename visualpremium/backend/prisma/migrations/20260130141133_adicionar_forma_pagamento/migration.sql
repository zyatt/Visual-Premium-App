/*
  Warnings:

  - Added the required column `formaPagamento` to the `orcamentos` table without a default value. This is not possible if the table is not empty.
  - Added the required column `formaPagamento` to the `pedidos` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE "orcamentos" ADD COLUMN     "formaPagamento" TEXT NOT NULL;

-- AlterTable
ALTER TABLE "pedidos" ADD COLUMN     "formaPagamento" TEXT NOT NULL;
