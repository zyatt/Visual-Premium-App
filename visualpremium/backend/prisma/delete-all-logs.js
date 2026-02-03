require('dotenv').config();

const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const pg = require('pg');
const readline = require('readline');

// Pool do PostgreSQL
const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
});

// Adapter do Prisma
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

// Interface de leitura no terminal
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

async function deleteAllLogs() {
  try {
    console.log('🗑️  Script de Exclusão de Logs\n');

    // Conta quantos logs existem
    const count = await prisma.log.count();
    console.log(`📊 Total de logs no banco: ${count}`);

    if (count === 0) {
      console.log('✅ Não há logs para deletar.');
      return;
    }

    // Pede confirmação
    rl.question(
      '\n⚠️  Tem certeza que deseja deletar TODOS os logs? (sim/não): ',
      async (answer) => {
        if (answer.toLowerCase() === 'sim') {
          console.log('\n🔄 Deletando logs...');

          const result = await prisma.log.deleteMany({});
          console.log(`✅ ${result.count} logs deletados com sucesso!`);
        } else {
          console.log('❌ Operação cancelada.');
        }

        await prisma.$disconnect();
        await pool.end();
        rl.close();
      }
    );
  } catch (error) {
    console.error('❌ Erro ao deletar logs:', error.message);

    await prisma.$disconnect();
    await pool.end();
    rl.close();
    process.exit(1);
  }
}

deleteAllLogs();
