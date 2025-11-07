# Создаем скрипт fix_nginx.sh
sudo tee /srv/mobius_strip/fix_nginx.sh > /dev/null << 'EOF'
#!/bin/bash

echo "🔧 Исправление конфигурации Nginx..."

# Останавливаем Nginx для безопасности
sudo systemctl stop nginx

# Удаляем неправильные конфиги
echo "🗑️  Удаление неправильных конфигов..."
sudo rm -f /etc/nginx/sites-enabled/sites-available
sudo rm -f /etc/nginx/sites-enabled/default

# Создаем правильный конфиг
echo "📝 Создание конфига Nginx..."
sudo tee /etc/nginx/sites-available/mobius_strip > /dev/null << 'CONFIG'
server {
    listen 80;
    server_name vm-2fa9a6;

    client_max_body_size 20m;

    location /static/ {
        alias /srv/mobius_strip/staticfiles/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    location /media/ {
        alias /srv/mobius_strip/media/;
        expires 30d;
        add_header Cache-Control "public";
    }

    location / {
        proxy_pass http://127.0.0.1:8001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
CONFIG

# Активируем сайт
echo "🔗 Активация сайта..."
sudo ln -sf /etc/nginx/sites-available/mobius_strip /etc/nginx/sites-enabled/

# Проверяем конфигурацию
echo "🔍 Проверка конфигурации Nginx..."
if sudo nginx -t; then
    echo "✅ Конфигурация Nginx верна"
    
    # Запускаем Nginx
    echo "🚀 Запуск Nginx..."
    sudo systemctl start nginx
    sudo systemctl enable nginx
    
    # Проверяем статус
    echo "📊 Статус Nginx:"
    sudo systemctl status nginx --no-pager
    
    # Проверяем порты
    echo "🔌 Проверка портов:"
    sudo netstat -tlnp | grep :80
else
    echo "❌ Ошибка в конфигурации Nginx"
    exit 1
fi

echo "✅ Исправление Nginx завершено"
EOF

# Делаем исполняемым
sudo chmod +x /srv/mobius_strip/fix_nginx.sh
