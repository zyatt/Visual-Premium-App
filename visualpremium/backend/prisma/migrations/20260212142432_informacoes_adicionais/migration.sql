-- CreateTable
CREATE TABLE "orcamento_informacoes_adicionais" (
    "id" SERIAL NOT NULL,
    "orcamentoId" INTEGER NOT NULL,
    "data" TIMESTAMP(3) NOT NULL,
    "descricao" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "orcamento_informacoes_adicionais_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pedido_informacoes_adicionais" (
    "id" SERIAL NOT NULL,
    "pedidoId" INTEGER NOT NULL,
    "data" TIMESTAMP(3) NOT NULL,
    "descricao" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pedido_informacoes_adicionais_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "orcamento_informacoes_adicionais" ADD CONSTRAINT "orcamento_informacoes_adicionais_orcamentoId_fkey" FOREIGN KEY ("orcamentoId") REFERENCES "orcamentos"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pedido_informacoes_adicionais" ADD CONSTRAINT "pedido_informacoes_adicionais_pedidoId_fkey" FOREIGN KEY ("pedidoId") REFERENCES "pedidos"("id") ON DELETE CASCADE ON UPDATE CASCADE;
