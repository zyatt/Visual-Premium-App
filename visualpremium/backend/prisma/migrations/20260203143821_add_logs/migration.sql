-- CreateTable
CREATE TABLE "logs" (
    "id" SERIAL NOT NULL,
    "usuarioId" INTEGER NOT NULL,
    "usuarioNome" TEXT NOT NULL,
    "acao" TEXT NOT NULL,
    "entidade" TEXT NOT NULL,
    "entidadeId" INTEGER NOT NULL,
    "descricao" TEXT NOT NULL,
    "detalhes" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "logs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "logs_usuarioId_idx" ON "logs"("usuarioId");

-- CreateIndex
CREATE INDEX "logs_entidade_idx" ON "logs"("entidade");

-- CreateIndex
CREATE INDEX "logs_createdAt_idx" ON "logs"("createdAt");
