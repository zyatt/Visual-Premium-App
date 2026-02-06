-- AlterTable
ALTER TABLE "produto_avisos" ADD COLUMN     "opcaoExtraId" INTEGER;

-- AddForeignKey
ALTER TABLE "produto_avisos" ADD CONSTRAINT "produto_avisos_opcaoExtraId_fkey" FOREIGN KEY ("opcaoExtraId") REFERENCES "produto_opcoes_extras"("id") ON DELETE SET NULL ON UPDATE CASCADE;
