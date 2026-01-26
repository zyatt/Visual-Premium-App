-- DropForeignKey
ALTER TABLE "OrcamentoMaterial" DROP CONSTRAINT "OrcamentoMaterial_materialId_fkey";

-- DropForeignKey
ALTER TABLE "OrcamentoMaterial" DROP CONSTRAINT "OrcamentoMaterial_orcamentoId_fkey";

-- DropForeignKey
ALTER TABLE "PedidoMaterial" DROP CONSTRAINT "PedidoMaterial_materialId_fkey";

-- DropForeignKey
ALTER TABLE "PedidoMaterial" DROP CONSTRAINT "PedidoMaterial_pedidoId_fkey";

-- DropForeignKey
ALTER TABLE "ProdutoMaterial" DROP CONSTRAINT "ProdutoMaterial_materialId_fkey";

-- DropForeignKey
ALTER TABLE "ProdutoMaterial" DROP CONSTRAINT "ProdutoMaterial_produtoId_fkey";

-- AddForeignKey
ALTER TABLE "ProdutoMaterial" ADD CONSTRAINT "ProdutoMaterial_produtoId_fkey" FOREIGN KEY ("produtoId") REFERENCES "Produto"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ProdutoMaterial" ADD CONSTRAINT "ProdutoMaterial_materialId_fkey" FOREIGN KEY ("materialId") REFERENCES "Material"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "OrcamentoMaterial" ADD CONSTRAINT "OrcamentoMaterial_orcamentoId_fkey" FOREIGN KEY ("orcamentoId") REFERENCES "Orcamento"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "OrcamentoMaterial" ADD CONSTRAINT "OrcamentoMaterial_materialId_fkey" FOREIGN KEY ("materialId") REFERENCES "Material"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PedidoMaterial" ADD CONSTRAINT "PedidoMaterial_pedidoId_fkey" FOREIGN KEY ("pedidoId") REFERENCES "Pedido"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PedidoMaterial" ADD CONSTRAINT "PedidoMaterial_materialId_fkey" FOREIGN KEY ("materialId") REFERENCES "Material"("id") ON DELETE CASCADE ON UPDATE CASCADE;
