const { PrismaClient } = require('@prisma/client');

// Tentar usar adapter do PostgreSQL se disponível
let prisma;

try {
  // Verificar se os pacotes do adapter estão instalados
  const { PrismaPg } = require('@prisma/adapter-pg');
  const { Pool } = require('pg');

  const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
  });

  const adapter = new PrismaPg(pool);

  prisma = new PrismaClient({ 
    adapter,
    log: process.env.NODE_ENV === 'development' 
      ? ['query', 'error', 'warn'] 
      : ['error', 'warn'],
  });

  console.log('✅ Prisma inicializado com adapter PostgreSQL');
} catch (error) {
  // Se adapter não estiver disponível, usar conexão padrão
  console.warn('⚠️  Adapter PostgreSQL não disponível, usando conexão padrão');
  console.warn('   Erro:', error.message);
  
  prisma = new PrismaClient({
    log: process.env.NODE_ENV === 'development' 
      ? ['query', 'error', 'warn'] 
      : ['error', 'warn'],
    errorFormat: 'pretty',
  });

  console.log('✅ Prisma inicializado com conexão padrão');
}

// Conexão e tratamento de erros
prisma.$connect()
  .then(() => {
    console.log('✅ Prisma conectado ao banco de dados');
  })
  .catch((error) => {
    console.error('❌ Erro ao conectar Prisma ao banco:', error.message);
    // Não encerrar processo, apenas logar o erro
  });

// Graceful shutdown
process.on('beforeExit', async () => {
  await prisma.$disconnect();
});

process.on('SIGINT', async () => {
  await prisma.$disconnect();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  await prisma.$disconnect();
  process.exit(0);
});

// IMPORTANTE: Exportar a instância do prisma
module.exports = prisma;