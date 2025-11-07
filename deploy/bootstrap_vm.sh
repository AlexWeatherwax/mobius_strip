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
DJANGO_SETTINGS_MODULE="${DJANGO_SETTINGS_MODULE:-mobius_clinica.production_settings}"

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
        redis-server nginx supervisor curl
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
    
    # Сбор статических файлов (только если STATIC_ROOT настроен)
    log "Сбор статических файлов..."
    django_manage "python manage.py collectstatic --noinput --clear"
    
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
        python manage.py check --deploy 2>&1
    ")
    local check_exit_code=$?
    set -e
    
    if [ $check_exit_code -eq 0 ]; then
        log "✅ Проверка конфигурации прошла успешно"
    else
        warn "⚠️  Проверка конфигурации выявила проблемы:"
        echo "$check_output" | while IFS= read -r line; do
            if echo "$line" | grep -q "WARNINGS:" || echo "$line" | grep -q "SystemCheckError"; then
                warn "$line"
            else
                echo "$line"
            fi
        done
        
        # Проверяем, есть ли критические ошибки
        if echo "$check_output" | grep -q "ERROR"; then
            error "Обнаружены критические ошибки конфигурации"
        else
            log "Предупреждения проигнорированы, продолжаем деплой..."
        fi
    fi
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
startretries=3
stopsignal=TERM
stopwaitsecs=10
stopasgroup=true
killasgroup=true
stdout_logfile=/var/log/${APP_NAME}/gunicorn.out.log
stderr_logfile=/var/log/${APP_NAME}/gunicorn.err.log
environment=DJANGO_SETTINGS_MODULE="${DJANGO_SETTINGS_MODULE}",PYTHONUNBUFFERED="1",DEBUG="${DEBUG}",SECRET_KEY="${SECRET_KEY}",ALLOWED_HOSTS="${ALLOWED_HOSTS_ESCAPED}",CSRF_TRUSTED_ORIGINS="${CSRF_TRUSTED_ORIGINS_ESCAPED}",DB_NAME="${DB_NAME}",DB_USER="${DB_USER}",DB_PASSWORD="${DB_PASSWORD}",DB_HOST="${DB_HOST}",DB_PORT="${DB_PORT}",USE_REDIS="${USE_REDIS}",REDIS_URL="${REDIS_URL}",STATIC_ROOT="${STATIC_ROOT}",MEDIA_ROOT="${MEDIA_ROOT}"
EOF
    
    # Применение конфигурации Supervisor
    sudo supervisorctl reread || error "Ошибка reread supervisor"
    sudo supervisorctl update || error "Ошибка update supervisor"
    
    # Даем время для обновления конфигурации
    sleep 2
    
    # Останавливаем старый процесс если он существует
    if sudo supervisorctl status "${APP_NAME}" >/dev/null 2>&1; then
        log "Остановка существующего процесса..."
        sudo supervisorctl stop "${APP_NAME}" || warn "Не удалось остановить существующий процесс"
        sleep 2
    fi
    
    # Запускаем приложение
    log "Запуск приложения..."
    if sudo supervisorctl start "${APP_NAME}"; then
        log "✅ Приложение успешно запущено"
    else
        error "Не удалось запустить приложение через supervisor"
    fi
    
    # Ждем и проверяем статус
    log "Проверка статуса приложения..."
    sleep 3
    
    local max_attempts=5
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        local status_output
        status_output=$(sudo supervisorctl status "${APP_NAME}" 2>&1)
        
        if echo "$status_output" | grep -q "RUNNING"; then
            log "✅ Приложение успешно запущено и работает"
            log "Статус: $status_output"
            return 0
        elif echo "$status_output" | grep -q "STARTING"; then
            log "🔄 Приложение запускается... (попытка $attempt/$max_attempts)"
            sleep 3
            ((attempt++))
        else
            error "❌ Ошибка запуска приложения: $status_output"
        fi
    done
    
    error "❌ Приложение не запустилось после $max_attempts попыток"
}

configure_nginx() {
    log "Настройка Nginx..."
    
    local nginx_available="/etc/nginx/sites-available/${APP_NAME}"
    local nginx_enabled="/etc/nginx/sites-enabled/${APP_NAME}"
    
    # Убедимся, что директории существуют
    sudo mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
    
    # Удаляем старый конфиг если он существует
    sudo rm -f "$nginx_available" "$nginx_enabled"
    
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
    sudo ln -sf "$nginx_available" "$nginx_enabled" || error "Не удалось создать симлинк для nginx"
    
    # Удаляем дефолтный конфиг nginx если он существует
    if [ -f "/etc/nginx/sites-enabled/default" ]; then
        sudo rm -f "/etc/nginx/sites-enabled/default"
    fi
    
    # Проверка конфигурации и перезагрузка
    log "Проверка конфигурации Nginx..."
    if sudo nginx -t; then
        log "✅ Конфигурация Nginx верна"
        sudo systemctl reload nginx || error "Не удалось перезагрузить nginx"
    else
        error "❌ Ошибка конфигурации nginx"
    fi
}

# Функция для проверки работоспособности приложения
check_application() {
    log "Проверка работоспособности приложения..."
    
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "http://${BIND_ADDR}/" >/dev/null 2>&1 || \
           curl -s -f "http://${BIND_ADDR}/admin" >/dev/null 2>&1 || \
           curl -s -f "http://${BIND_ADDR}/api" >/dev/null 2>&1; then
            log "✅ Приложение отвечает на запросы"
            return 0
        else
            log "🔄 Ожидание запуска приложения... (попытка $attempt/$max_attempts)"
            sleep 3
            ((attempt++))
        fi
    done
    
    warn "⚠️  Приложение не отвечает на запросы, но продолжаем деплой"
    return 1
}

# Функция для отображения информации о доступе
show_access_info() {
    local ip_address
    ip_address=$(hostname -I | awk '{print $1}')
    
    log ""
    log "🎉 Деплой завершен!"
    log ""
    log "🌐 Сайт доступен по адресам:"
    log "   http://${SERVER_NAME}"
    log "   http://${ip_address}"
    log ""
    log "📊 Для проверки статуса сервисов выполните:"
    log "   sudo supervisorctl status ${APP_NAME}"
    log "   sudo systemctl status nginx"
    log ""
    log "📝 Для просмотра логов выполните:"
    log "   sudo tail -f /var/log/${APP_NAME}/gunicorn.out.log"
    log "   sudo tail -f /var/log/${APP_NAME}/gunicorn.err.log"
    log ""
    
    # Проверяем, доступен ли сайт
    if curl -s -f "http://${ip_address}" >/dev/null 2>&1; then
        log "✅ Сайт успешно запущен и доступен!"
    else
        warn "⚠️  Сайт может быть недоступен. Проверьте логи для диагностики."
    fi
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
    
    # Проверяем работоспособность
    check_application
    
    # Показываем информацию о доступе
    show_access_info
}

# Запуск главной функции
main "$@"
