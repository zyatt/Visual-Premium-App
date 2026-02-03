require('dotenv').config();

const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const pg = require('pg');
const bcrypt = require('bcrypt');

// Criar o pool do PostgreSQL
const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
});

// Criar o adapter
const adapter = new PrismaPg(pool);

// Criar o PrismaClient com o adapter
const prisma = new PrismaClient({ adapter });

async function main() {
  console.log('🌱 Iniciando seed...');

  const adminPassword = await bcrypt.hash('123', 10);

  const admin = await prisma.usuario.upsert({
    where: { username: 'User' },  // ALTERADO AQUI
    update: {},
    create: {
      username: 'User',           // ALTERADO AQUI
      password: adminPassword,
      nome: 'Usuário',
      role: 'User',
    },
  });
}

main()
  .catch((e) => {
    console.error('❌ Erro no seed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
    await pool.end();
  });
