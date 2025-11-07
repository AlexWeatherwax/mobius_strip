#!/usr/bin/env python3
"""
Скрипт для настройки Django settings
"""

import os
import django
from django.core.management import execute_from_command_line

def setup_django():
    """Настраивает Django окружение"""
    
    # Устанавливаем настройки
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'mobius_clinica.settings')
    
    # Инициализируем Django
    django.setup()
    
    # Проверяем настройки
    from django.conf import settings
    
    print("Проверка настроек Django:")
    print(f"DEBUG: {settings.DEBUG}")
    print(f"ALLOWED_HOSTS: {settings.ALLOWED_HOSTS}")
    print(f"STATIC_ROOT: {getattr(settings, 'STATIC_ROOT', 'Not set')}")
    print(f"MEDIA_ROOT: {getattr(settings, 'MEDIA_ROOT', 'Not set')}")
    print(f"DATABASES: {settings.DATABASES['default']['NAME']}")

if __name__ == "__main__":
    setup_django()
