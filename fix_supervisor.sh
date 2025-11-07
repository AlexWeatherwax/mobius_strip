#!/bin/bash

echo "🔧 Исправление конфигурации mobius_strip..."

# Останавливаем приложение
sudo supervisorctl stop mobius_strip 2>/dev/null || true

# Создаем директорию для логов
echo "📁 Создание директории для логов..."
sudo mkdir -p /var/log/mobius_strip
sudo chown django:django /var/log/mobius_strip
sudo chmod 755 /var/log/mobius_strip

# Создаем лог файлы
sudo touch /var/log/mobius_strip/gunicorn.out.log
sudo touch /var/log/mobius_strip/gunicorn.err.log
sudo chown django:django /var/log/mobius_strip/*.log

# Создаем исправленный конфиг Supervisor
echo "⚙️  Обновление конфигурации Supervisor..."
sudo tee /etc/supervisor/conf.d/mobius_strip.conf > /dev/null << 'EOF'
[program:mobius_strip]
directory=/srv/mobius_strip
command=/srv/mobius_strip/.venv/bin/gunicorn mobius_clinica.wsgi:application --bind 127.0.0.1:8001 --workers 3 --timeout 120
user=django
autostart=true
autorestart=true
startretries=3
stopsignal=TERM
stopwaitsecs=10
stopasgroup=true
killasgroup=true
stdout_logfile=/var/log/mobius_strip/gunicorn.out.log
stderr_logfile=/var/log/mobius_strip/gunicorn.err.log
environment=DJANGO_SETTINGS_MODULE="mobius_clinica.production_settings",PYTHONUNBUFFERED="1",DEBUG="0",SECRET_KEY="19416a10003fd3e48def80c5576e719bba694de54f5615152c06e72e5afba364",ALLOWED_HOSTS="vm-2fa9a6,127.0.0.1,localhost",CSRF_TRUSTED_ORIGINS="",DB_NAME="mobius_clinica",DB_USER="mobius_user",DB_PASSWORD="AlexWeatherwax_90",DB_HOST="127.0.0.1",DB_PORT="5432",USE_REDIS="1",REDIS_URL="redis://127.0.0.1:6379/1",STATIC_ROOT="/srv/mobius_strip/staticfiles",MEDIA_ROOT="/srv/mobius_strip/media"
EOF

# Обновляем Supervisor
echo "🔄 Обновление Supervisor..."
sudo supervisorctl reread
sudo supervisorctl update

# Запускаем приложение
echo "🚀 Запуск приложения..."
sudo supervisorctl start mobius_strip

# Ждем запуска
sleep 5

# Проверяем статус
echo "📊 Статус приложения:"
sudo supervisorctl status mobius_strip

# Показываем логи
echo "📝 Последние логи ошибок:"
sudo tail -20 /var/log/mobius_strip/gunicorn.err.log

echo "✅ Исправление завершено"
