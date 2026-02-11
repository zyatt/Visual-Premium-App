\\\\\\\\\\\\\\\\ INICIALIZAR \\\\\\\\\\\\\\\\\\\\
[para prod]

$env:NODE_ENV="prod"; npm run prod  [backend]

flutter run -t lib/main.dart        [frontend]

\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
[para dev]

$env:NODE_ENV="dev"; npm run dev    [backend]

flutter run -t lib/main_dev.dart    [frontend]

\\\\\\\\\\\ CRIAR PRIMEIRO ADMIN \\\\\\\\\\\\\\\

$env:NODE_ENV="dev"; npx prisma db seed  --- ambiente dev
$env:NODE_ENV="prod"; npx prisma db seed --- ambiente prod

\\\\\\\\\\\\\ BUILD \\\\\\\\\\\\\\\\\\\\\\\\\\\\
# flutter clean
# flutter pub get

flutter build windows -t lib/main_dev.dart - dev
flutter build windows -t lib/main.dart - prod
