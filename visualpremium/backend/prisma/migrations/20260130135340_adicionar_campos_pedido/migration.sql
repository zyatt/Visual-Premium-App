/*
  Warnings:

  - You are about to drop the `Pedido` table. If the table is not empty, all the data it contains will be lost.

*/
-- DropForeignKey
ALTER TABLE "Pedido" DROP CONSTRAINT "Pedido_orcamentoId_fkey";

-- DropForeignKey
ALTER TABLE "Pedido" DROP CONSTRAINT "Pedido_produtoId_fkey";

-- DropForeignKey
ALTER TABLE "PedidoMaterial" DROP CONSTRAINT "PedidoMaterial_pedidoId_fkey";

-- DropTable
DROP TABLE "Pedido";

-- CreateTable
CREATE TABLE "pedidos" (
    "id" SERIAL NOT NULL,
    "cliente" TEXT NOT NULL,
    "numero" INTEGER NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'Em Andamento',
    "produtoId" INTEGER NOT NULL,
    "frete" BOOLEAN NOT NULL DEFAULT false,
    "freteDesc" TEXT,
    "freteValor" DOUBLE PRECISION,
    "caminhaoMunck" BOOLEAN NOT NULL DEFAULT false,
    "caminhaoMunckHoras" DOUBLE PRECISION,
    "caminhaoMunckValorHora" DOUBLE PRECISION,
    "condicoesPagamento" TEXT NOT NULL,
    "prazoEntrega" TEXT NOT NULL,
    "orcamentoId" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "pedidos_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pedidos_despesas_adicionais" (
    "id" SERIAL NOT NULL,
    "pedidoId" INTEGER NOT NULL,
    "descricao" TEXT NOT NULL,
    "valor" DOUBLE PRECISION NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pedidos_despesas_adicionais_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "pedidos_orcamentoId_key" ON "pedidos"("orcamentoId");

-- AddForeignKey
ALTER TABLE "pedidos" ADD CONSTRAINT "pedidos_produtoId_fkey" FOREIGN KEY ("produtoId") REFERENCES "Produto"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pedidos" ADD CONSTRAINT "pedidos_orcamentoId_fkey" FOREIGN KEY ("orcamentoId") REFERENCES "orcamentos"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pedidos_despesas_adicionais" ADD CONSTRAINT "pedidos_despesas_adicionais_pedidoId_fkey" FOREIGN KEY ("pedidoId") REFERENCES "pedidos"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PedidoMaterial" ADD CONSTRAINT "PedidoMaterial_pedidoId_fkey" FOREIGN KEY ("pedidoId") REFERENCES "pedidos"("id") ON DELETE CASCADE ON UPDATE CASCADE;
