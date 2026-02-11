[para prod]

$env:NODE_ENV="prod"; npm run prod

flutter run -t lib/main.dart

----------------------
[para dev]

$env:NODE_ENV="dev"; npm run dev

flutter run -t lib/main_dev.dart

\\\\\\\\\\\ CRIAR PRIMEIRO ADMIN \\\\\\\\\\\\\\\

$env:NODE_ENV="dev"; npx prisma db seed  --- ambiente dev
$env:NODE_ENV="prod"; npx prisma db seed --- ambiente prod
