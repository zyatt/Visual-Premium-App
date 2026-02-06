-- CreateTable
CREATE TABLE "produto_avisos" (
    "id" SERIAL NOT NULL,
    "produtoId" INTEGER NOT NULL,
    "mensagem" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "produto_avisos_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "produto_avisos" ADD CONSTRAINT "produto_avisos_produtoId_fkey" FOREIGN KEY ("produtoId") REFERENCES "produtos"("id") ON DELETE CASCADE ON UPDATE CASCADE;
