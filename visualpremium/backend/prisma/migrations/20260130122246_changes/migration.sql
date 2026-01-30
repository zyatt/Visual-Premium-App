/*
  Warnings:

  - Added the required column `condicoesPagamento` to the `orcamentos` table without a default value. This is not possible if the table is not empty.
  - Added the required column `prazoEntrega` to the `orcamentos` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE "orcamentos" ADD COLUMN     "condicoesPagamento" TEXT NOT NULL,
ADD COLUMN     "prazoEntrega" TEXT NOT NULL;
