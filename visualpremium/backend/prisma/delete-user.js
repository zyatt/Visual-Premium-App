require('dotenv').config();

const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const pg = require('pg');

const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
});

const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function deleteUser() {
  const username = process.argv[2];

  if (!username) {
    console.error('❌ Uso: node prisma/delete-user.js <username>');
    process.exit(1);
  }

  try {
    const user = await prisma.usuario.delete({
      where: { username: username },
    });

    console.log(`✅ Usuário "${user.username}" removido com sucesso!`);
  } catch (error) {
    console.error('❌ Erro ao remover usuário:', error.message);
  }
}

deleteUser()
  .finally(async () => {
    await prisma.$disconnect();
    await pool.end();
  });