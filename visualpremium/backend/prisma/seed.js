require('dotenv').config();

const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const pg = require('pg');
const bcrypt = require('bcrypt');

const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
});

const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function main() {
  console.log('🌱 Iniciando seed...');
  console.log('🧠 DATABASE_URL:', process.env.DATABASE_URL);

  const adminPassword = await bcrypt.hash('mvds01', 10);

  await prisma.usuario.upsert({
    where: { username: 'mattvds' },
    update: {},
    create: {
      username: 'mattvds',
      password: adminPassword,
      nome: 'Matheus',
      role: 'admin',
    },
  });

  console.log('✅ Admin criado/confirmado');
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
