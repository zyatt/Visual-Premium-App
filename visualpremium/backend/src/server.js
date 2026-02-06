const path = require('path');
const dotenv = require('dotenv');

// 🔁 Escolhe o arquivo de ambiente
const envFile = process.env.NODE_ENV === 'production' ? '.env.production' : '.env';

// 📦 Carrega variáveis de ambiente
dotenv.config({
  path: path.resolve(process.cwd(), envFile),
});

// 🔎 Logs de inicialização
console.log('🚀 Iniciando backend…');
console.log('📍 Ambiente:', process.env.NODE_ENV || 'development');
console.log('📡 Porta:', process.env.PORT);
console.log('🧠 Banco:', process.env.DATABASE_URL);

// ✅ IMPORTA O APP
const app = require('./app');

// 🚀 INICIA O SERVIDOR (IMPORTANTE!)
const PORT = process.env.PORT;

const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Servidor rodando em http://0.0.0.0:${PORT}`);
  console.log(`📍 Ambiente: ${process.env.NODE_ENV || 'development'}`);
});

// 🛡️ Tratamento de erros
server.on('error', (error) => {
  if (error.code === 'EADDRINUSE') {
    console.error(`❌ Porta ${PORT} já está em uso!`);
    process.exit(1);
  } else {
    console.error('❌ Erro no servidor:', error);
    process.exit(1);
  }
});

// 🧹 Graceful shutdown
process.on('SIGTERM', () => {
  console.log('👋 SIGTERM recebido, fechando servidor...');
  server.close(() => {
    console.log('✅ Servidor fechado');
    process.exit(0);
  });
});