#!/usr/bin/env bash
set -euo pipefail

# Конфигурационные переменные
APP_NAME="mobius_strip"
PROJECT_DIR="/srv/mobius_strip"
DJANGO_USER="django"
BRANCH="${BRANCH:-main}"

# Функции утилиты
log() {
    echo -e "\033[1;32m[INFO]\033[0m $*"
}

error() {
    echo -e "\033[1;31m[ERROR]\033[0m $*" >&2
    exit 1
}

check_requirements() {
    # Проверка существования пользователя
    if ! id -u "$DJANGO_USER" >/dev/null 2>&1; then
        error "Пользователь $DJANGO_USER не существует"
    fi
    
    # Проверка существования директории проекта
    if [ ! -d "$PROJECT_DIR" ]; then
        error "Директория проекта $PROJECT_DIR не существует"
    fi
    
    # Проверка прав доступа к директории
    if ! sudo -u "$DJANGO_USER" test -w "$PROJECT_DIR"; then
        error "Нет прав на запись в директорию $PROJECT_DIR"
    fi
}

deploy_application() {
    log "Начало деплоя приложения $APP_NAME..."
    
    # Выполнение деплоя от имени пользователя Django
    sudo -u "$DJANGO_USER" -H bash -c "
        set -euo pipefail
        
        echo 'Переход в директорию проекта...'
        cd '$PROJECT_DIR' || exit 1
        
        echo 'Обновление репозитория...'
        git fetch --all || exit 1
        git checkout '$BRANCH' || exit 1
        git pull --ff-only || exit 1
        
        echo 'Активация виртуального окружения и установка зависимостей...'
        source .venv/bin/activate || exit 1
        pip install --upgrade pip || exit 1
        
        echo 'Установка Python зависимостей...'
        if [ -f 'requirements.txt' ]; then
            pip install -r requirements.txt || exit 1
        else
            echo 'Файл requirements.txt не найден, пропускаем установку зависимостей'
        fi
        
        echo 'Применение миграций базы данных...'
        python manage.py migrate || exit 1
        
        echo 'Сбор статических файлов...'
        python manage.py collectstatic --noinput --clear || exit 1
        
        echo 'Django операции завершены успешно'
    " || error "Ошибка во время деплоя приложения"
}

restart_services() {
    log "Перезапуск сервисов..."
    
    # Перезапуск приложения через Supervisor
    if sudo supervisorctl status "$APP_NAME" >/dev/null 2>&1; then
        log "Перезапуск приложения $APP_NAME..."
        sudo supervisorctl restart "$APP_NAME" || error "Не удалось перезапустить приложение $APP_NAME"
    else
        error "Сервис $APP_NAME не найден в Supervisor"
    fi
    
    # Проверка статуса после перезапуска
    log "Проверка статуса приложения..."
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if sudo supervisorctl status "$APP_NAME" | grep -q "RUNNING"; then
            log "Приложение $APP_NAME успешно запущено"
            break
        elif [ $attempt -eq $max_attempts ]; then
            error "Приложение $APP_NAME не запустилось после $max_attempts попыток"
        else
            log "Ожидание запуска приложения... (попытка $attempt/$max_attempts)"
            sleep 5
            ((attempt++))
        fi
    done
}

main() {
    log "Запуск процесса деплоя для $APP_NAME"
    log "Директория проекта: $PROJECT_DIR"
    log "Ветка: $BRANCH"
    log "Пользователь: $DJANGO_USER"
    
    # Проверка требований
    check_requirements
    
    # Выполнение деплоя
    deploy_application
    
    # Перезапуск сервисов
    restart_services
    
    log "Деплой успешно завершен!"
    log "Приложение $APP_NAME обновлено и перезапущено"
}

# Запуск главной функции
main "$@"


