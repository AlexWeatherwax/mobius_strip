#!/usr/bin/env bash set -euo pipefail
APP_NAME="mobius_strip"
REPO_URL="https://github.com/AlexWeatherwax/mobius_strip.git"
PROJECT_DIR="/srv/mobius_strip"
DJANGO_USER="django"
PROJECT_PACKAGE="mobius_clinica"
BIND_ADDR="127.0.0.1:8001"

SERVER_NAME="{SERVER_NAME:-vm-686640}"
ALLOWED_HOSTS="{ALLOWED_HOSTS:-vm-686640,127.0.0.1,localhost}"
CSRF_TRUSTED_ORIGINS="${CSRF_TRUSTED_ORIGINS:-}"
DEBUG="\({DEBUG:-0}"
SECRET_KEY="\){SECRET_KEY:-\((openssl rand -hex 32)}"
DJANGO_SETTINGS_MODULE="\){DJANGO_SETTINGS_MODULE:-mobius_clinica.settings}"

DB_NAME="\({DB_NAME:-mobius_clinica}"
DB_USER="\){DB_USER:-mobius_user}"
DB_PASSWORD="\({DB_PASSWORD:-ChangeMeStrong}"
DB_HOST="\){DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-5432}"

USE_REDIS="\({USE_REDIS:-1}"
REDIS_URL="\){REDIS_URL:-redis://127.0.0.1:6379/1}"

ALLOWED_HOSTS_ESCAPED="\({ALLOWED_HOSTS//,/\\,}"
CSRF_TRUSTED_ORIGINS_ESCAPED="\){CSRF_TRUSTED_ORIGINS//,/\,}"

log() { echo -e "\033[1;32mINFO\033[0m $*"; } ensure_pkg() { dpkg -s "$1" >/dev/null 2>&1 || sudo apt-get install -y "$1"; } psql_exec() { sudo -u postgres psql -tAc "$1"; }
ensure_system() { sudo apt-get update -y ensure_pkg git ensure_pkg python3-venv ensure_pkg python3-pip ensure_pkg build-essential ensure_pkg libpq-dev ensure_pkg postgresql ensure_pkg postgresql-contrib ensure_pkg redis-server ensure_pkg nginx ensure_pkg supervisor

sudo systemctl enable --now postgresql sudo systemctl enable --now redis-server sudo systemctl enable --now nginx sudo systemctl enable --now supervisor }

ensure_user() { id -u "\(DJANGO_USER" >/dev/null 2>&1 || sudo adduser --disabled-password --gecos "" "\)DJANGO_USER" }

ensure_repo() { sudo mkdir -p "\(PROJECT_DIR" sudo chown -R "\)DJANGO_USER:\(DJANGO_USER" "\)PROJECT_DIR"
if -d "${PROJECT_DIR}/.git" ; then log "Репозиторий найден, обновляю..." sudo -u "\(DJANGO_USER" -H bash -lc "cd '\)PROJECT_DIR' && git fetch --all && git checkout main || true && git pull --ff-only || true" else log "Клонирую репозиторий..." sudo -u "\(DJANGO_USER" -H bash -lc "git clone '\)REPO_URL' '$PROJECT_DIR'" fi }
ensure_venv() { log "Создаю venv и устанавливаю зависимости..." sudo -u "\(DJANGO_USER" -H bash -lc "cd '\)PROJECT_DIR' && python3 -m venv .venv && .venv/bin/pip install --upgrade pip" if -f "${PROJECT_DIR}/requirements.txt" ; then sudo -u "\(DJANGO_USER" -H bash -lc "cd '\)PROJECT_DIR' && .venv/bin/pip install -r requirements.txt" fi }

ensure_db() { log "Создаю/проверяю БД и пользователя..." psql_exec "DO $$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='\({DB_USER}') THEN CREATE ROLE ${DB_USER} LOGIN PASSWORD '\){DB_PASSWORD}'; END IF; END $$;"
psql_exec "DO $$ BEGIN IF NOT EXISTS (SELECT FROM pg_database WHERE datname='${DB_NAME}') THEN CREATE DATABASE ${DB_NAME} OWNER ${DB_USER}; END IF; END $$;" }
django_manage() { sudo -u "\(DJANGO_USER" -H bash -lc "cd '\)PROJECT_DIR' && $*" }

configure_django() { log "Применяю миграции и собираю статику..." django_manage ".venv/bin/python manage.py migrate" mkdir -p "${PROJECT_DIR}/staticfiles" django_manage ".venv/bin/python manage.py collectstatic --noinput || true" }
configure_supervisor() { log "Пишу конфиг Supervisor..." sudo bash -lc "cat > /etc/supervisor/conf.d/\({APP_NAME}.conf <<'EOF' [program:\){APP_NAME}] directory=\({PROJECT_DIR} command=\){PROJECT_DIR}/.venv/bin/gunicorn \({PROJECT_PACKAGE}.wsgi:application --bind ${BIND_ADDR} --workers 3 --timeout 120 user=\){DJANGO_USER} autostart=true autorestart=true stopsignal=TERM stopasgroup=true killasgroup=true stdout_logfile=/var/log/\({APP_NAME}/gunicorn.out.log stderr_logfile=/var/log/\){APP_NAME}/gunicorn.err.log environment=DJANGO_SETTINGS_MODULE="\({DJANGO_SETTINGS_MODULE}",PYTHONUNBUFFERED="1",DEBUG="\){DEBUG}",SECRET_KEY="\({SECRET_KEY}",ALLOWED_HOSTS="\){ALLOWED_HOSTS_ESCAPED}",CSRF_TRUSTED_ORIGINS="\({CSRF_TRUSTED_ORIGINS_ESCAPED}",DB_NAME="\){DB_NAME}",DB_USER="\({DB_USER}",DB_PASSWORD="\){DB_PASSWORD}",DB_HOST="\({DB_HOST}",DB_PORT="\){DB_PORT}",USE_REDIS="\({USE_REDIS}",REDIS_URL="\){REDIS_URL}" EOF" sudo mkdir -p "/var/log/\({APP_NAME}" sudo chown -R "\)DJANGO_USER:\(DJANGO_USER" "/var/log/\){APP_NAME}" sudo supervisorctl reread sudo supervisorctl update sudo supervisorctl status }

configure_nginx() { log "Пишу конфиг Nginx..." sudo bash -lc "cat > /etc/nginx/sites-available/${APP_NAME} <<EOF server { listen 80; server_name ${SERVER_NAME};

client_max_body_size 20m;

location /static/ { alias ${PROJECT_DIR}/staticfiles/; } location /media/ { alias ${PROJECT_DIR}/media/; }

location / { proxy_pass http://${BIND_ADDR}; proxy_set_header Host $host; proxy_set_header X-Real-IP $remote_addr; proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; proxy_set_header X-Forwarded-Proto $scheme; } } EOF" -f "/etc/nginx/sites-enabled/${APP_NAME}" || sudo ln -s "/etc/nginx/sites-available/\({APP_NAME}" "/etc/nginx/sites-enabled/\){APP_NAME}" sudo nginx -t sudo systemctl reload nginx }


ensure_system ensure_user ensure_repo ensure_venv ensure_db configure_django configure_supervisor configure_nginx

log "Готово. Откройте: http://$(hostname -I | awk '{print $1}')/"

