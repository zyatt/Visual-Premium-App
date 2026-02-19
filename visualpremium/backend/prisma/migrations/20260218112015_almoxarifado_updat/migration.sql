-- CreateTable
CREATE TABLE "AlmoxarifadoMaterialAvulso" (
    "id" SERIAL NOT NULL,
    "almoxarifadoId" INTEGER NOT NULL,
    "materialId" INTEGER NOT NULL,
    "quantidade" DOUBLE PRECISION NOT NULL,
    "custoRealizado" DOUBLE PRECISION NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AlmoxarifadoMaterialAvulso_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "AlmoxarifadoMaterialAvulso" ADD CONSTRAINT "AlmoxarifadoMaterialAvulso_almoxarifadoId_fkey" FOREIGN KEY ("almoxarifadoId") REFERENCES "almoxarifados"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AlmoxarifadoMaterialAvulso" ADD CONSTRAINT "AlmoxarifadoMaterialAvulso_materialId_fkey" FOREIGN KEY ("materialId") REFERENCES "materiais"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
