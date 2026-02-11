import { config } from 'dotenv';
import { defineConfig } from 'prisma/config';
import path from 'path';

const envFile = process.env.NODE_ENV === 'dev' ? '.env.dev' : '.env';

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
