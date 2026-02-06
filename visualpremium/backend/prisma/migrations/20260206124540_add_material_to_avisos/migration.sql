-- AlterTable
ALTER TABLE "produto_avisos" ADD COLUMN     "materialId" INTEGER;

-- AddForeignKey
ALTER TABLE "produto_avisos" ADD CONSTRAINT "produto_avisos_materialId_fkey" FOREIGN KEY ("materialId") REFERENCES "materiais"("id") ON DELETE SET NULL ON UPDATE CASCADE;
