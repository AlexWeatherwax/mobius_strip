sudo tee /srv/mobius_strip/start_postgresql.sh << 'EOF'
#!/bin/bash

echo "🚀 ЗАПУСК POSTGRESQL КЛАСТЕРА"

echo "📊 Проверка кластеров:"
sudo pg_lsclusters

echo "🔄 Запуск кластера 14 main..."
sudo systemctl start postgresql@14-main

# Если не сработало, пробуем другой способ
if ! sudo systemctl is-active postgresql@14-main >/dev/null; then
    echo "🔄 Альтернативный запуск..."
    sudo pg_ctlcluster 14 main start
fi

echo "⏳ Ожидание 5 секунд..."
sleep 5

echo "📊 Статус после запуска:"
sudo pg_lsclusters

echo "🔌 Проверка порта 5432:"
sudo netstat -tln | grep :5432 || echo "❌ Порт 5432 не слушается"

echo "🔍 Проверка подключения..."
if PGPASSWORD='AlexWeatherwax_90' psql -h localhost -U mobius_user -d mobius_clinica -c "SELECT 1;" >/dev/null 2>&1; then
    echo "✅ PostgreSQL подключение успешно"
else
    echo "❌ Ошибка подключения к PostgreSQL"
    echo "📝 Логи:"
    sudo tail -10 /var/log/postgresql/postgresql-14-main.log
fi

echo "🐍 Проверка Django..."
sudo -u django -H bash -c "
  cd /srv/mobius_strip
  source .venv/bin/activate
  export DJANGO_SETTINGS_MODULE='mobius_clinica.production_settings'
  python manage.py check --database default
" && echo "✅ Django подключение успешно" || echo "❌ Ошибка Django подключения"
EOF

sudo chmod +x /srv/mobius_strip/start_postgresql.sh
