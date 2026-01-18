#!/usr/bin/env sh
set -eu

echo "[setup] loading environment"

# ==================================================
# Load ENV
# ==================================================
if [ ! -f .env ]; then
  echo "[error] .env not found"
  exit 1
fi

export $(grep -v '^#' .env | xargs)

# ==================================================
# Base directories
# ==================================================
BASE_DOCKER="docker"
PHP_DIR="$BASE_DOCKER/php"
NGINX_DIR="$BASE_DOCKER/nginx"
NGINX_CONF_DIR="$NGINX_DIR/conf.d"
LOGS_DIR="./logs"

mkdir -p "$PHP_DIR" "$NGINX_CONF_DIR" "$LOGS_DIR"

# ==================================================
# Detect applications
# ==================================================
APP_INDEXES=$(env | grep '^APP[0-9]\+_NAME=' | sed 's/APP\([0-9]\+\)_NAME=.*/\1/' | sort -n)

if [ -z "$APP_INDEXES" ]; then
  echo "[error] no applications defined in .env"
  exit 1
fi

# ==================================================
# PHP extensions (ENV driven)
# ==================================================
APK_DEPS=""
PHP_EXTS=""

[ "${PHP_ENABLE_MYSQL:-false}" = "true" ] && PHP_EXTS="$PHP_EXTS pdo_mysql"
[ "${PHP_ENABLE_PGSQL:-false}" = "true" ] && {
  APK_DEPS="$APK_DEPS postgresql-dev"
  PHP_EXTS="$PHP_EXTS pdo_pgsql"
}
[ "${PHP_ENABLE_ZIP:-false}" = "true" ] && {
  APK_DEPS="$APK_DEPS libzip-dev"
  PHP_EXTS="$PHP_EXTS zip"
}
[ "${PHP_ENABLE_INTL:-false}" = "true" ] && {
  APK_DEPS="$APK_DEPS icu-dev"
  PHP_EXTS="$PHP_EXTS intl"
}
[ "${PHP_ENABLE_OPCACHE:-false}" = "true" ] && PHP_EXTS="$PHP_EXTS opcache"

# ==================================================
# Generate PHP Dockerfile
# ==================================================
cat > "$PHP_DIR/Dockerfile" <<EOF
FROM php:8.3-fpm-alpine

RUN apk add --no-cache \
  bash \
  tzdata \
  oniguruma-dev \
  $APK_DEPS

RUN docker-php-ext-install $PHP_EXTS

WORKDIR /apps
EOF

# ==================================================
# PHP ini
# ==================================================
cat > "$PHP_DIR/php.ini" <<EOF
memory_limit=${PHP_MEMORY_LIMIT}
max_execution_time=${PHP_MAX_EXECUTION_TIME}
upload_max_filesize=${PHP_UPLOAD_MAX_FILESIZE}
post_max_size=${PHP_POST_MAX_SIZE}

opcache.enable=${PHP_OPCACHE_ENABLE}
opcache.memory_consumption=${PHP_OPCACHE_MEMORY}
opcache.max_accelerated_files=${PHP_OPCACHE_MAX_FILES}
EOF

# ==================================================
# PHP-FPM config
# ==================================================
cat > "$PHP_DIR/php-fpm.conf" <<EOF
[global]
daemonize = no

[www]
listen = 9000
pm = ${PHP_FPM_PM}
pm.max_children = ${PHP_FPM_MAX_CHILDREN}
pm.start_servers = ${PHP_FPM_START_SERVERS}
pm.min_spare_servers = ${PHP_FPM_MIN_SPARE_SERVERS}
pm.max_spare_servers = ${PHP_FPM_MAX_SPARE_SERVERS}
EOF

# ==================================================
# Global nginx.conf
# ==================================================
cat > "$NGINX_DIR/nginx.conf" <<'EOF'
worker_processes auto;

events {
  worker_connections 1024;
}

http {
  include /etc/nginx/mime.types;
  sendfile on;
  keepalive_timeout 65;
  include /etc/nginx/conf.d/*.conf;
}
EOF

# ==================================================
# Build PHP volumes FIRST (critical)
# ==================================================
PHP_VOLUMES=""

for IDX in $APP_INDEXES; do
  APP_NAME=$(printenv "APP${IDX}_NAME")
  APP_PATH=$(printenv "APP${IDX}_PATH")

  if [ -z "$APP_NAME" ] || [ -z "$APP_PATH" ]; then
    echo "[error] APP${IDX} missing NAME or PATH"
    exit 1
  fi

  PHP_VOLUMES="$PHP_VOLUMES
      - $APP_PATH:/apps/$APP_NAME:ro"
done

# ==================================================
# Write docker-compose.yml (php service ONLY)
# ==================================================
cat > docker-compose.yml <<EOF
services:
  php:
    build: ./docker/php
    restart: unless-stopped
    environment:
      TZ: ${TZ}
    volumes:$PHP_VOLUMES
EOF

# ==================================================
# Per-app nginx services + vhosts
# ==================================================
for IDX in $APP_INDEXES; do
  APP_NAME=$(printenv "APP${IDX}_NAME")
  APP_PORT=$(printenv "APP${IDX}_PORT")
  APP_PATH=$(printenv "APP${IDX}_PATH")
  APP_LOG_PATH=$(printenv "APP${IDX}_LOG_PATH" || true)

  if [ -z "$APP_NAME" ] || [ -z "$APP_PORT" ] || [ -z "$APP_PATH" ]; then
    echo "[error] APP${IDX} config incomplete"
    exit 1
  fi

  [ -z "$APP_LOG_PATH" ] && APP_LOG_PATH="$LOGS_DIR/$APP_NAME"
  mkdir -p "$APP_LOG_PATH"

  # nginx vhost
  cat > "$NGINX_CONF_DIR/$APP_NAME.conf" <<EOF
server {
  listen 80;
  root /apps/$APP_NAME;
  index index.php index.html;

  access_log /var/log/nginx/$APP_NAME/access.log;
  error_log  /var/log/nginx/$APP_NAME/error.log;

  location / {
    try_files \$uri \$uri/ /index.php?\$query_string;
  }

  location ~ \\.php\$ {
    include fastcgi.conf;
    fastcgi_pass php:9000;
  }
}
EOF

  # nginx service
  cat >> docker-compose.yml <<EOF

  nginx-$APP_NAME:
    image: nginx:alpine
    restart: unless-stopped
    ports:
      - "$APP_PORT:80"
    volumes:
      - $APP_PATH:/apps/$APP_NAME:ro
      - $APP_LOG_PATH:/var/log/nginx/$APP_NAME
      - ./docker/nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./docker/nginx/conf.d/$APP_NAME.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - php
EOF
done

echo
echo "[setup] COMPLETE"
echo "Next steps:"
echo "  docker compose down"
echo "  docker compose config   # should be clean"
echo "  docker compose up -d"
