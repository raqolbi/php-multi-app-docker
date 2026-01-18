# Docker PHP Multi-App (ENV-Driven, Auto-Generated)

This repository provides a **fully automated Docker-based PHP multi-application setup**.

The core principle is simple:

> **Users only edit `.env`. Everything else is generated automatically by `setup.sh`.**

No manual Docker, Nginx, or PHP configuration is required.

---

## 1. What This Repository Is

This project allows you to:

- Run **multiple PHP applications** on a single machine
- Each application:
  - Has its own port
  - Has its own Nginx container
  - Has its own access & error logs
- All applications share:
  - One PHP-FPM runtime
  - One Docker network

The system is **data-driven**, meaning:

- `.env` is the **single source of truth**
- `setup.sh` reads `.env` and generates everything else

---

## 2. Key Features

- ENV-driven configuration (no hardcoded values)
- Multiple PHP applications (APP1, APP2, APP3, ...)
- One Nginx container per application
- Shared PHP-FPM container
- External application paths (no code inside container)
- Per-application log directories
- Safe to re-run (`setup.sh` is idempotent)
- Docker Compose v2 compatible (no `version` field)

---

## 3. Repository Structure

Before running `setup.sh`, the repository looks like this:

```
.
├── .env.example
├── setup.sh
└── README.md
```

After running `setup.sh`, **these files and folders are generated automatically**:

```
.
├── docker/
│   ├── php/
│   │   ├── Dockerfile        # auto-generated
│   │   ├── php.ini           # auto-generated
│   │   └── php-fpm.conf      # auto-generated
│   └── nginx/
│       ├── nginx.conf        # auto-generated
│       └── conf.d/
│           ├── app1.conf     # auto-generated per app
│           ├── app2.conf
│           └── ...
├── docker-compose.yml        # auto-generated
├── logs/
│   ├── app1/                 # auto-generated if not specified
│   ├── app2/
│   └── ...
└── README.md
```

> **Do not manually edit generated files.**
> Always change `.env` and re-run `setup.sh`.

---

## 4. Prerequisites

You need:

- Docker (20+ recommended)
- Docker Compose v2 (`docker compose` command)
- A Linux or macOS host (WSL2 also works)

---

## 5. Initial Setup (First Time)

### Step 1: Copy Environment File

```bash
cp .env.example .env
```

### Step 2: Edit `.env`

At minimum, define one application:

```env
APP1_NAME=app1
APP1_PORT=8081
APP1_PATH=/absolute/path/to/your/php/app
```

The application path **must already exist** and contain `index.php`.

### Step 3: Run Setup

```bash
chmod +x setup.sh
./setup.sh
```

This will generate:

- Dockerfile for PHP
- PHP configuration
- Nginx configuration
- docker-compose.yml

### Step 4: Start Containers

```bash
docker compose build
docker compose up -d
```

Open in browser:

```
http://localhost:8081
```

---

## 6. Adding More Applications

To add another application, **only edit `.env`**.

Example:

```env
APP2_NAME=app2
APP2_PORT=8082
APP2_PATH=/absolute/path/to/app2
```

Then run:

```bash
./setup.sh
docker compose up -d
```

No rebuild is required.

Docker will:

- Create a new Nginx container
- Keep existing applications running

---

## 7. Updating Existing Applications

### Change Application Path

```bash
./setup.sh
docker compose up -d
```

### Change Application Port

```bash
./setup.sh
docker compose down
docker compose up -d
```

### Remove an Application

1. Remove APP entry from `.env`
2. Run:

```bash
./setup.sh
docker compose down
docker compose up -d
```

---

## 8. PHP Configuration (Performance & Extensions)

All PHP settings are controlled via `.env`.

### PHP Performance

```env
PHP_MEMORY_LIMIT=256M
PHP_MAX_EXECUTION_TIME=60
PHP_UPLOAD_MAX_FILESIZE=50M
PHP_POST_MAX_SIZE=50M
```

### PHP Extensions

```env
PHP_ENABLE_MYSQL=true
PHP_ENABLE_PGSQL=false
PHP_ENABLE_ZIP=true
PHP_ENABLE_INTL=true
PHP_ENABLE_OPCACHE=true
```

If you change any PHP-related values:

```bash
./setup.sh
docker compose build
docker compose up -d
```

---

## 9. Logs

Each application has its own logs:

```
logs/app1/
├── access.log
└── error.log
```

If `APPx_LOG_PATH` is empty, logs default to `./logs/<app>`.

Logs are persisted on the host and writable.

---

## 10. Common Command Reference

| Action | Command |
|------|--------|
| Initial start | `./setup.sh && docker compose build && docker compose up -d` |
| Add app | `./setup.sh && docker compose up -d` |
| Update PHP config | `./setup.sh && docker compose build && docker compose up -d` |
| Remove app | `./setup.sh && docker compose down && docker compose up -d` |
| Full reset | `docker compose down -v && docker compose build --no-cache` |

---

## 11. Important Notes

- PHP tuning is **global** (shared by all apps)
- Each app has its own Nginx container
- Application directories are mounted **read-only**
- Logs are mounted **read-write**
- This setup is ideal for:
  - VPS
  - Dedicated servers
  - Homelab environments

---

## 12. License

MIT

---

## 13. Status

This repository is:

- Stable
- Production-safe for single-host deployments
- Designed for clarity and simplicity

Future extensions (not included by default):

- Per-app PHP-FPM
- HTTPS via reverse proxy
- Health checks
- Resource limits

