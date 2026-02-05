/*
  Warnings:

  - A unique constraint covering the columns `[numero]` on the table `orcamentos` will be added. If there are existing duplicate values, this will fail.
  - A unique constraint covering the columns `[numero]` on the table `pedidos` will be added. If there are existing duplicate values, this will fail.
  - Added the required column `produtoNome` to the `orcamentos` table without a default value. This is not possible if the table is not empty.
  - Added the required column `produtoNome` to the `pedidos` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE "orcamentos" ADD COLUMN     "produtoNome" TEXT NOT NULL;

-- AlterTable
ALTER TABLE "pedidos" ADD COLUMN     "produtoNome" TEXT NOT NULL,
ALTER COLUMN "status" DROP DEFAULT;

-- CreateIndex
CREATE UNIQUE INDEX "orcamentos_numero_key" ON "orcamentos"("numero");

-- CreateIndex
CREATE UNIQUE INDEX "pedidos_numero_key" ON "pedidos"("numero");
