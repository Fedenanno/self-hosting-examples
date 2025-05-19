#!/bin/bash
set -e

echo "[entrypoint] Preparing Laravel environment..."

# === Fix permissions ===
chown -R 1000:1000 /var/www/html/storage /var/www/html/bootstrap/cache
chmod -R u+rwX /var/www/html/storage /var/www/html/bootstrap/cache

# === Ensure .env is loaded ===
if [ -f ".env" ]; then
  export $(grep -v '^#' .env | xargs)
fi

# === Generate APP_KEY if missing ===
if [ -z "$APP_KEY" ] || [[ "$APP_KEY" == '""' ]]; then
  echo "[entrypoint] Generating APP_KEY..."
  APP_KEY=$(php artisan key:generate --show)
  export APP_KEY
fi

# === Generate Passport keys if missing ===
if [ -z "$PASSPORT_PRIVATE_KEY" ] || [[ "$PASSPORT_PRIVATE_KEY" == '""' ]]; then
  echo "[entrypoint] Generating Passport keys..."
  php artisan passport:keys --force > /dev/null 2>&1

  PASSPORT_PRIVATE_KEY=$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' storage/oauth-private.key)
  PASSPORT_PUBLIC_KEY=$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' storage/oauth-public.key)

  export PASSPORT_PRIVATE_KEY
  export PASSPORT_PUBLIC_KEY
fi

# === Run migrations if requested ===
if [[ "$AUTO_DB_MIGRATE" == "true" ]]; then
  echo "[entrypoint] Running migrations..."
  php artisan migrate --force || echo "⚠️ Migration failed"
fi

# === Start Laravel app ===
echo "[entrypoint] Starting Laravel Octane..."
exec php artisan octane:start --server=swoole --host=0.0.0.0 --port=8000