/*
  Warnings:

  - You are about to drop the column `produtoNome` on the `orcamentos` table. All the data in the column will be lost.
  - You are about to drop the column `produtoNome` on the `pedidos` table. All the data in the column will be lost.

*/
-- AlterTable
ALTER TABLE "orcamentos" DROP COLUMN "produtoNome";

-- AlterTable
ALTER TABLE "pedidos" DROP COLUMN "produtoNome";
