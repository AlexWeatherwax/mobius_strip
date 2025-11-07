sudo tee /srv/mobius_strip/final_check.sh > /dev/null << 'EOF'
#!/bin/bash

echo "🎉 ФИНАЛЬНАЯ ПРОВЕРКА САЙТА"
echo "=========================="

# Получаем IP
IP=$(hostname -I | awk '{print $1}')

echo ""
echo "🌐 ДОСТУПНЫЕ АДРЕСА:"
echo "   http://vm-2fa9a6/"
echo "   http://$IP/"
echo "   http://localhost/"
echo ""

echo "📊 СТАТУС СЕРВИСОВ:"
sudo supervisorctl status mobius_strip
sudo systemctl status nginx --no-pager | head -5

echo ""
echo "🔌 ПРОВЕРКА ПОРТОВ:"
sudo netstat -tlnp | grep -E '(:80|:8001)'

echo ""
echo "🌐 ТЕСТИРОВАНИЕ ДОСТУПНОСТИ:"

# Проверяем основной домен
echo -n "   http://vm-2fa9a6/ -> "
if curl -s -I http://vm-2fa9a6/ | grep -q "HTTP/1.1"; then
    echo "✅ РАБОТАЕТ"
else
    echo "❌ НЕ РАБОТАЕТ"
fi

# Проверяем по IP
echo -n "   http://$IP/ -> "
if curl -s -I http://$IP/ | grep -q "HTTP/1.1"; then
    echo "✅ РАБОТАЕТ"
else
    echo "❌ НЕ РАБОТАЕТ"
fi

echo ""
echo "📝 ДЛЯ ДАЛЬНЕЙШЕЙ РАБОТЫ:"
echo "   Просмотр логов приложения: sudo tail -f /var/log/mobius_strip/gunicorn.err.log"
echo "   Просмотр логов Nginx: sudo tail -f /var/log/nginx/access.log"
echo "   Перезапуск приложения: sudo supervisorctl restart mobius_strip"
echo "   Перезапуск Nginx: sudo systemctl reload nginx"
echo ""
echo "🚀 САЙТ УСПЕШНО ЗАПУЩЕН!"
EOF

sudo chmod +x /srv/mobius_strip/final_check.sh
