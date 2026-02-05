/*
  Warnings:

  - The values [STRING_FLOAT,FLOAT_FLOAT,PERCENT_FLOAT] on the enum `TipoOpcaoExtra` will be removed. If these variants are still used in the database, this will fail.

*/
-- AlterEnum
BEGIN;
CREATE TYPE "TipoOpcaoExtra_new" AS ENUM ('STRINGFLOAT', 'FLOATFLOAT', 'PERCENTFLOAT');
ALTER TABLE "produto_opcoes_extras" ALTER COLUMN "tipo" TYPE "TipoOpcaoExtra_new" USING ("tipo"::text::"TipoOpcaoExtra_new");
ALTER TYPE "TipoOpcaoExtra" RENAME TO "TipoOpcaoExtra_old";
ALTER TYPE "TipoOpcaoExtra_new" RENAME TO "TipoOpcaoExtra";
DROP TYPE "public"."TipoOpcaoExtra_old";
COMMIT;
