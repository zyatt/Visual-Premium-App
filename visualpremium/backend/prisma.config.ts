import { config } from 'dotenv';
import { defineConfig } from 'prisma/config';
import path from 'path';

// Define o arquivo .env conforme NODE_ENV
const envFile = process.env.NODE_ENV === 'production' ? '.env.production' : '.env';

// Carrega as variáveis do arquivo correto
config({
  path: path.resolve(process.cwd(), envFile),
});

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
    seed: 'node ./prisma/seed.js',
  },
  datasource: {
    url: process.env.DATABASE_URL!,
  },
});
