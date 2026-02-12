/*
  Warnings:

  - You are about to drop the column `orcamentoId` on the `almoxarifados` table. All the data in the column will be lost.
  - A unique constraint covering the columns `[pedidoId]` on the table `almoxarifados` will be added. If there are existing duplicate values, this will fail.
  - Added the required column `pedidoId` to the `almoxarifados` table without a default value. This is not possible if the table is not empty.

*/
-- DropForeignKey
ALTER TABLE "almoxarifados" DROP CONSTRAINT "almoxarifados_orcamentoId_fkey";

-- DropIndex
DROP INDEX "almoxarifados_orcamentoId_key";

-- AlterTable
ALTER TABLE "almoxarifados" DROP COLUMN "orcamentoId",
ADD COLUMN     "pedidoId" INTEGER NOT NULL;

-- CreateIndex
CREATE UNIQUE INDEX "almoxarifados_pedidoId_key" ON "almoxarifados"("pedidoId");

-- AddForeignKey
ALTER TABLE "almoxarifados" ADD CONSTRAINT "almoxarifados_pedidoId_fkey" FOREIGN KEY ("pedidoId") REFERENCES "pedidos"("id") ON DELETE CASCADE ON UPDATE CASCADE;
