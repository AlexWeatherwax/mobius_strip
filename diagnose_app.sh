# Создаем скрипт diagnose_app.sh
sudo tee /srv/mobius_strip/diagnose_app.sh > /dev/null << 'EOF'
#!/bin/bash

echo "🔍 Диагностика приложения..."

# Проверяем статус
echo "📊 Статус приложения:"
sudo supervisorctl status mobius_strip

# Проверяем процессы
echo "🔄 Процессы Gunicorn:"
ps aux | grep gunicorn

# Проверяем порт
echo "🔌 Проверка порта 8001:"
sudo netstat -tlnp | grep :8001

# Проверяем логи
echo "📝 Последние логи ошибок:"
sudo tail -20 /var/log/mobius_strip/gunicorn.err.log

echo "📝 Последние stdout логи:"
sudo tail -20 /var/log/mobius_strip/gunicorn.out.log

# Проверяем настройки Django
echo "⚙️  Проверка настроек Django:"
sudo -u django -H bash -c "
  cd /srv/mobius_strip
  source .venv/bin/activate
  export DJANGO_SETTINGS_MODULE='mobius_clinica.production_settings'
  python -c \"
import django
django.setup()
from django.conf import settings
print('DEBUG:', settings.DEBUG)
print('ALLOWED_HOSTS:', settings.ALLOWED_HOSTS)
print('DATABASES:', settings.DATABASES['default']['NAME'])
print('Installed apps:', [app for app in settings.INSTALLED_APPS if 'mobius' in app or 'clinica' in app])
  \"
"

# Пробуем ручной запрос
echo "🌐 Тестовый запрос к приложению:"
timeout 5 curl -v http://127.0.0.1:8001/ 2>&1 | head -20 || echo "Запрос завершился таймаутом"

echo "✅ Диагностика завершена"
EOF

sudo chmod +x /srv/mobius_strip/diagnose_app.sh
