#!/usr/bin/env bash
set -euo pipefail

# Конфигурационные переменные
APP_NAME="mobius_strip"
REPO_URL="https://github.com/AlexWeatherwax/mobius_strip.git"
PROJECT_DIR="/srv/mobius_strip"
DJANGO_USER="django"
PROJECT_PACKAGE="mobius_clinica"
BIND_ADDR="127.0.0.1:8001"

# Переменные окружения Django
SERVER_NAME="${SERVER_NAME:-vm-2fa9a6}"
ALLOWED_HOSTS="${ALLOWED_HOSTS:-vm-2fa9a6,127.0.0.1,localhost}"
CSRF_TRUSTED_ORIGINS="${CSRF_TRUSTED_ORIGINS:-}"
DEBUG="${DEBUG:-0}"
SECRET_KEY="${SECRET_KEY:-$(openssl rand -hex 32)}"
DJANGO_SETTINGS_MODULE="${DJANGO_SETTINGS_MODULE:-mobius_clinica.settings}"

# Настройки базы данных
DB_NAME="${DB_NAME:-mobius_clinica}"
DB_USER="${DB_USER:-mobius_user}"
DB_PASSWORD="${DB_PASSWORD:-ChangeMeStrong}"
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-5432}"

# Настройки Redis
USE_REDIS="${USE_REDIS:-1}"
REDIS_URL="${REDIS_URL:-redis://127.0.0.1:6379/1}"

# Экранирование для конфигурационных файлов
ALLOWED_HOSTS_ESCAPED="${ALLOWED_HOSTS//,/\\,}"
CSRF_TRUSTED_ORIGINS_ESCAPED="${CSRF_TRUSTED_ORIGINS//,/\\,}"

# Функции утилиты
log() {
    echo -e "\033[1;32m[INFO]\033[0m $*"
}

error() {
    echo -e "\033[1;31m[ERROR]\033[0m $*" >&2
    exit 1
}

ensure_pkg() {
    if ! dpkg -s "$1" >/dev/null 2>&1; then
        log "Установка пакета: $1"
        sudo apt-get install -y "$1" || error "Не удалось установить пакет: $1"
    fi
}

psql_exec() {
    sudo -u postgres psql -tAc "$1" || error "Ошибка выполнения SQL: $1"
}

# Основные функции
ensure_system() {
    log "Обновление системы и установка пакетов..."
    sudo apt-get update -y || error "Не удалось обновить пакеты"
    
    local packages=(
        git python3-venv python3-pip build-essential
        libpq-dev postgresql postgresql-contrib
        redis-server nginx supervisor
    )
    
    for pkg in "${packages[@]}"; do
        ensure_pkg "$pkg"
    done
    
    # Включение и запуск сервисов
    local services=(postgresql redis-server nginx supervisor)
    for service in "${services[@]}"; do
        if ! sudo systemctl is-enabled "$service" >/dev/null 2>&1; then
            sudo systemctl enable "$service" || error "Не удалось включить сервис: $service"
        fi
        if ! sudo systemctl is-active "$service" >/dev/null; then
            sudo systemctl start "$service" || error "Не удалось запустить сервис: $service"
        fi
    done
}

ensure_user() {
    if ! id -u "$DJANGO_USER" >/dev/null 2>&1; then
        log "Создание пользователя: $DJANGO_USER"
        sudo adduser --disabled-password --gecos "" "$DJANGO_USER" || error "Не удалось создать пользователя"
    fi
}

ensure_repo() {
    log "Настройка репозитория..."
    sudo mkdir -p "$PROJECT_DIR" || error "Не удалось создать директорию проекта"
    sudo chown -R "$DJANGO_USER:$DJANGO_USER" "$PROJECT_DIR" || error "Не удалось изменить владельца директории"
    
    if [ -d "${PROJECT_DIR}/.git" ]; then
        log "Репозиторий найден, обновление..."
        sudo -u "$DJANGO_USER" -H bash -c "
            cd '$PROJECT_DIR' && 
            git fetch --all && 
            git checkout main && 
            git pull --ff-only
        " || error "Не удалось обновить репозиторий"
    else
        log "Клонирование репозитория..."
        sudo -u "$DJANGO_USER" -H bash -c "git clone '$REPO_URL' '$PROJECT_DIR'" || error "Не удалось клонировать репозиторий"
    fi
}

ensure_venv() {
    log "Создание виртуального окружения и установка зависимостей..."
    
    # Создание venv
    sudo -u "$DJANGO_USER" -H bash -c "
        cd '$PROJECT_DIR' && 
        python3 -m venv .venv && 
        .venv/bin/pip install --upgrade pip
    " || error "Не удалось создать виртуальное окружение"
    
    # Установка зависимостей
    if [ -f "${PROJECT_DIR}/requirements.txt" ]; then
        log "Установка Python зависимостей..."
        sudo -u "$DJANGO_USER" -H bash -c "
            cd '$PROJECT_DIR' && 
            .venv/bin/pip install -r requirements.txt
        " || error "Не удалось установить зависимости"
    fi
}

ensure_db() {
    log "Настройка базы данных..."
    
    # Создание пользователя БД (если не существует)
    if ! psql_exec "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | grep -q 1; then
        log "Создание пользователя БД: ${DB_USER}"
        psql_exec "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';" || error "Не удалось создать пользователя БД"
    else
        log "Пользователь БД ${DB_USER} уже существует"
        # Обновление пароля если пользователь уже существует
        psql_exec "ALTER USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';" || error "Не удалось обновить пароль пользователя"
    fi
    
    # Создание базы данных (если не существует)
    if ! psql_exec "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1; then
        log "Создание базы данных: ${DB_NAME}"
        psql_exec "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};" || error "Не удалось создать базу данных"
    else
        log "База данных ${DB_NAME} уже существует"
    fi
    
    # Предоставление прав
    psql_exec "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};" || error "Не удалось предоставить права"
    
    # Дополнительные настройки для базы данных
    psql_exec "ALTER DATABASE ${DB_NAME} SET timezone TO 'UTC';" || log "Не удалось установить часовой пояс, но это не критично"
}

django_manage() {
    sudo -u "$DJANGO_USER" -H bash -c "
        cd '$PROJECT_DIR' && 
        source .venv/bin/activate && 
        $*
    " || error "Ошибка выполнения Django команды: $*"
}

configure_django() {
    log "Настройка Django..."
    
    # Применение миграций
    django_manage "python manage.py migrate"
    
    # Создание директории для статики
    sudo mkdir -p "${PROJECT_DIR}/staticfiles" "${PROJECT_DIR}/media"
    sudo chown -R "$DJANGO_USER:$DJANGO_USER" "${PROJECT_DIR}/staticfiles" "${PROJECT_DIR}/media"
    
    # Сбор статики
    django_manage "python manage.py collectstatic --noinput --clear"
    
    # Создание суперпользователя (опционально, можно закомментировать)
    # django_manage "python manage.py createsuperuser --noinput || true"
}

configure_supervisor() {
    log "Настройка Supervisor..."
    
    local supervisor_conf="/etc/supervisor/conf.d/${APP_NAME}.conf"
    
    # Создание директории для логов
    sudo mkdir -p "/var/log/${APP_NAME}"
    sudo chown -R "$DJANGO_USER:$DJANGO_USER" "/var/log/${APP_NAME}"
    
    # Создание конфигурационного файла
    sudo tee "$supervisor_conf" > /dev/null << EOF
[program:${APP_NAME}]
directory=${PROJECT_DIR}
command=${PROJECT_DIR}/.venv/bin/gunicorn ${PROJECT_PACKAGE}.wsgi:application --bind ${BIND_ADDR} --workers 3 --timeout 120
user=${DJANGO_USER}
autostart=true
autorestart=true
stopsignal=TERM
stopasgroup=true
killasgroup=true
stdout_logfile=/var/log/${APP_NAME}/gunicorn.out.log
stderr_logfile=/var/log/${APP_NAME}/gunicorn.err.log
environment=DJANGO_SETTINGS_MODULE="${DJANGO_SETTINGS_MODULE}",PYTHONUNBUFFERED="1",DEBUG="${DEBUG}",SECRET_KEY="${SECRET_KEY}",ALLOWED_HOSTS="${ALLOWED_HOSTS_ESCAPED}",CSRF_TRUSTED_ORIGINS="${CSRF_TRUSTED_ORIGINS_ESCAPED}",DB_NAME="${DB_NAME}",DB_USER="${DB_USER}",DB_PASSWORD="${DB_PASSWORD}",DB_HOST="${DB_HOST}",DB_PORT="${DB_PORT}",USE_REDIS="${USE_REDIS}",REDIS_URL="${REDIS_URL}"
EOF
    
    # Применение конфигурации Supervisor
    sudo supervisorctl reread || error "Ошибка reread supervisor"
    sudo supervisorctl update || error "Ошибка update supervisor"
    sudo supervisorctl restart "${APP_NAME}" || sudo supervisorctl start "${APP_NAME}" || error "Не удалось запустить приложение через supervisor"
    
    log "Статус сервиса:"
    sudo supervisorctl status "${APP_NAME}"
}

configure_nginx() {
    log "Настройка Nginx..."
    
    local nginx_available="/etc/nginx/sites-available/${APP_NAME}"
    local nginx_enabled="/etc/nginx/sites-enabled/${APP_NAME}"
    
    # Создание конфигурационного файла
    sudo tee "$nginx_available" > /dev/null << EOF
server {
    listen 80;
    server_name ${SERVER_NAME};

    client_max_body_size 20m;

    location /static/ {
        alias ${PROJECT_DIR}/staticfiles/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    location /media/ {
        alias ${PROJECT_DIR}/media/;
        expires 30d;
        add_header Cache-Control "public";
    }

    location / {
        proxy_pass http://${BIND_ADDR};
        proxy_set_header Host              \$host;
        proxy_set_header X-Real-IP         \$remote_addr;
        proxy_set_header X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF
    
    # Активация сайта
    if [ ! -L "$nginx_enabled" ]; then
        sudo ln -s "$nginx_available" "$nginx_enabled" || error "Не удалось создать симлинк для nginx"
    fi
    
    # Проверка конфигурации и перезагрузка
    sudo nginx -t || error "Ошибка конфигурации nginx"
    sudo systemctl reload nginx || error "Не удалось перезагрузить nginx"
}

# Главная функция
main() {
    log "Запуск деплоя приложения ${APP_NAME}..."
    
    ensure_system
    ensure_user
    ensure_repo
    ensure_venv
    ensure_db
    configure_django
    configure_supervisor
    configure_nginx
    
    log "Деплой завершен успешно!"
    log "Приложение доступно по адресу: http://${SERVER_NAME}"
    log "Также попробуйте: http://$(hostname -I | awk '{print $1}')"
}

# Запуск главной функции
main "$@"
