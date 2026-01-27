-- AlterTable
ALTER TABLE "Orcamento" ADD COLUMN     "caminhaoMunck" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "despesaAdicional" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "frete" BOOLEAN NOT NULL DEFAULT false;
