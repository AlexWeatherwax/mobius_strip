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

# Настройки статических файлов
STATIC_ROOT="${STATIC_ROOT:-${PROJECT_DIR}/staticfiles}"
MEDIA_ROOT="${MEDIA_ROOT:-${PROJECT_DIR}/media}"

# Настройки безопасности (для production)
SECURE_HSTS_SECONDS="${SECURE_HSTS_SECONDS:-0}"
SECURE_SSL_REDIRECT="${SECURE_SSL_REDIRECT:-0}"
SESSION_COOKIE_SECURE="${SESSION_COOKIE_SECURE:-0}"
CSRF_COOKIE_SECURE="${CSRF_COOKIE_SECURE:-0}"

# Экранирование для конфигурационных файлов
ALLOWED_HOSTS_ESCAPED="${ALLOWED_HOSTS//,/\\,}"
CSRF_TRUSTED_ORIGINS_ESCAPED="${CSRF_TRUSTED_ORIGINS//,/\\,}"

# Функции утилиты
log() {
    echo -e "\033[1;32m[INFO]\033[0m $*"
}

warn() {
    echo -e "\033[1;33m[WARN]\033[0m $*"
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
    sudo -u postgres bash -c "cd /tmp && psql -tAc \"$1\"" || error "Ошибка выполнения SQL: $1"
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
    
    # Проверяем, существует ли уже venv
    if [ ! -d "${PROJECT_DIR}/.venv" ]; then
        log "Создание нового виртуального окружения..."
        sudo -u "$DJANGO_USER" -H bash -c "
            cd '$PROJECT_DIR' && 
            python3 -m venv .venv
        " || error "Не удалось создать виртуальное окружение"
    else
        log "Виртуальное окружение уже существует"
    fi
    
    # Обновление pip
    log "Обновление pip..."
    sudo -u "$DJANGO_USER" -H bash -c "
        cd '$PROJECT_DIR' && 
        .venv/bin/pip install --upgrade pip setuptools wheel
    " || error "Не удалось обновить pip"
    
    # Установка зависимостей
    if [ -f "${PROJECT_DIR}/requirements.txt" ]; then
        log "Установка Python зависимостей из requirements.txt..."
        sudo -u "$DJANGO_USER" -H bash -c "
            cd '$PROJECT_DIR' && 
            .venv/bin/pip install -r requirements.txt
        " || error "Не удалось установить зависимости из requirements.txt"
        
        # Проверяем, установлен ли Django
        log "Проверка установки Django..."
        if ! sudo -u "$DJANGO_USER" -H bash -c "
            cd '$PROJECT_DIR' && 
            .venv/bin/python -c 'import django; print(django.__version__)'
        " >/dev/null 2>&1; then
            error "Django не установлен в виртуальном окружении"
        else
            log "Django успешно установлен"
        fi
    else
        error "Файл requirements.txt не найден в ${PROJECT_DIR}"
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
    log "Выполнение Django команды: $*"
    sudo -u "$DJANGO_USER" -H bash -c "
        cd '$PROJECT_DIR' && 
        source .venv/bin/activate && 
        export DJANGO_SETTINGS_MODULE='${DJANGO_SETTINGS_MODULE}' &&
        export DEBUG='${DEBUG}' &&
        export SECRET_KEY='${SECRET_KEY}' &&
        export ALLOWED_HOSTS='${ALLOWED_HOSTS}' &&
        export CSRF_TRUSTED_ORIGINS='${CSRF_TRUSTED_ORIGINS}' &&
        export DB_NAME='${DB_NAME}' &&
        export DB_USER='${DB_USER}' &&
        export DB_PASSWORD='${DB_PASSWORD}' &&
        export DB_HOST='${DB_HOST}' &&
        export DB_PORT='${DB_PORT}' &&
        export USE_REDIS='${USE_REDIS}' &&
        export REDIS_URL='${REDIS_URL}' &&
        export STATIC_ROOT='${STATIC_ROOT}' &&
        export MEDIA_ROOT='${MEDIA_ROOT}' &&
        export SECURE_HSTS_SECONDS='${SECURE_HSTS_SECONDS}' &&
        export SECURE_SSL_REDIRECT='${SECURE_SSL_REDIRECT}' &&
        export SESSION_COOKIE_SECURE='${SESSION_COOKIE_SECURE}' &&
        export CSRF_COOKIE_SECURE='${CSRF_COOKIE_SECURE}' &&
        $*
    " || error "Ошибка выполнения Django команды: $*"
}

configure_django() {
    log "Настройка Django..."
    
    # Проверяем, что Django доступен
    log "Проверка доступности Django..."
    if ! sudo -u "$DJANGO_USER" -H bash -c "
        cd '$PROJECT_DIR' && 
        source .venv/bin/activate && 
        python -c 'import django; print(\"Django version:\", django.get_version())'
    "; then
        error "Django не доступен в виртуальном окружении"
    fi
    
    # Создание директорий для статики и медиа
    log "Создание директорий для статики и медиа..."
    sudo mkdir -p "${STATIC_ROOT}" "${MEDIA_ROOT}"
    sudo chown -R "$DJANGO_USER:$DJANGO_USER" "${STATIC_ROOT}" "${MEDIA_ROOT}"
    sudo chmod -R 755 "${STATIC_ROOT}" "${MEDIA_ROOT}"
    
    # Применение миграций
    log "Применение миграций базы данных..."
    django_manage "python manage.py migrate"
    
    # Проверка валидности конфигурации Django (игнорируем предупреждения)
    log "Проверка конфигурации Django..."
    set +e
    local check_output
    check_output=$(sudo -u "$DJANGO_USER" -H bash -c "
        cd '$PROJECT_DIR' && 
        source .venv/bin/activate && 
        export DJANGO_SETTINGS_MODULE='${DJANGO_SETTINGS_MODULE}' &&
        export DEBUG='${DEBUG}' &&
        export SECRET_KEY='${SECRET_KEY}' &&
        export ALLOWED_HOSTS='${ALLOWED_HOSTS}' &&
        python manage.py check --deploy --fail-level WARNING 2>&1
    ")
    local check_exit_code=$?
    set -e
    
    if [ $check_exit_code -eq 0 ]; then
        log "✅ Проверка конфигурации прошла успешно"
    else
        warn "⚠️  Проверка конфигурации выявила предупреждения:"
        echo "$check_output" | while IFS= read -r line; do
            warn "$line"
        done
        
        # Проверяем, есть ли критические ошибки (не предупреждения)
        if echo "$check_output" | grep -q "ERROR"; then
            error "Обнаружены критические ошибки конфигурации"
        else
            log "Предупреждения безопасности проигнорированы, продолжаем деплой..."
        fi
    fi
    
    # Проверка настроек статических файлов
    log "Проверка настроек статических файлов..."
    if sudo -u "$DJANGO_USER" -H bash -c "
        cd '$PROJECT_DIR' && 
        source .venv/bin/activate && 
        export DJANGO_SETTINGS_MODULE='${DJANGO_SETTINGS_MODULE}' &&
        python -c \"
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', '${DJANGO_SETTINGS_MODULE}')
import django
django.setup()
from django.conf import settings
print('STATIC_ROOT:', getattr(settings, 'STATIC_ROOT', 'Not set'))
print('STATIC_URL:', getattr(settings, 'STATIC_URL', 'Not set'))
        \"
    " | grep -q "Not set"; then
        log "⚠️  STATIC_ROOT не настроен в settings.py, пропускаем collectstatic"
        log "💡 Добавьте STATIC_ROOT = '${STATIC_ROOT}' в настройки Django"
    else
        log "Сбор статических файлов..."
        django_manage "python manage.py collectstatic --noinput --clear"
    fi
    
    # Создание суперпользователя (опционально, можно закомментировать)
    # log "Создание суперпользователя..."
    # django_manage "python manage.py createsuperuser --noinput --username admin --email admin@example.com || true"
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
environment=DJANGO_SETTINGS_MODULE="${DJANGO_SETTINGS_MODULE}",PYTHONUNBUFFERED="1",DEBUG="${DEBUG}",SECRET_KEY="${SECRET_KEY}",ALLOWED_HOSTS="${ALLOWED_HOSTS_ESCAPED}",CSRF_TRUSTED_ORIGINS="${CSRF_TRUSTED_ORIGINS_ESCAPED}",DB_NAME="${DB_NAME}",DB_USER="${DB_USER}",DB_PASSWORD="${DB_PASSWORD}",DB_HOST="${DB_HOST}",DB_PORT="${DB_PORT}",USE_REDIS="${USE_REDIS}",REDIS_URL="${REDIS_URL}",STATIC_ROOT="${STATIC_ROOT}",MEDIA_ROOT="${MEDIA_ROOT}",SECURE_HSTS_SECONDS="${SECURE_HSTS_SECONDS}",SECURE_SSL_REDIRECT="${SECURE_SSL_REDIRECT}",SESSION_COOKIE_SECURE="${SESSION_COOKIE_SECURE}",CSRF_COOKIE_SECURE="${CSRF_COOKIE_SECURE}"
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
        alias ${STATIC_ROOT}/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    location /media/ {
        alias ${MEDIA_ROOT}/;
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
    
    # Удаляем дефолтный конфиг nginx если он существует
    if [ -f "/etc/nginx/sites-enabled/default" ]; then
        sudo rm -f "/etc/nginx/sites-enabled/default"
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
