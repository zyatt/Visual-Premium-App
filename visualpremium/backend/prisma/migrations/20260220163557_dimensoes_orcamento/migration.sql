-- AlterTable
ALTER TABLE "orcamento_materiais" ADD COLUMN     "altura" DOUBLE PRECISION,
ADD COLUMN     "comprimento" DOUBLE PRECISION,
ADD COLUMN     "largura" DOUBLE PRECISION;

-- AlterTable
ALTER TABLE "pedido_materiais" ADD COLUMN     "altura" DOUBLE PRECISION,
ADD COLUMN     "comprimento" DOUBLE PRECISION,
ADD COLUMN     "largura" DOUBLE PRECISION;
