-- CreateTable
CREATE TABLE "faixas_custo_markup" (
    "id" SERIAL NOT NULL,
    "custoAte" DOUBLE PRECISION,
    "markup" DOUBLE PRECISION NOT NULL,
    "ordem" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "faixas_custo_markup_pkey" PRIMARY KEY ("id")
);
