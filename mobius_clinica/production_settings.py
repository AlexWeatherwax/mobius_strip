"""
Production settings for mobius_clinica
"""

import os
from .settings import *

# Security settings
DEBUG = os.environ.get('DEBUG', '0') == '1'
SECRET_KEY = os.environ.get('SECRET_KEY', 'django-insecure-fallback-key')

ALLOWED_HOSTS = os.environ.get('ALLOWED_HOSTS', 'localhost,127.0.0.1').split(',')

# Static files
STATIC_ROOT = os.environ.get('STATIC_ROOT', '/srv/mobius_strip/staticfiles')
STATIC_URL = '/static/'

MEDIA_ROOT = os.environ.get('MEDIA_ROOT', '/srv/mobius_strip/media')
MEDIA_URL = '/media/'

# Database
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.environ.get('DB_NAME', 'mobius_clinica'),
        'USER': os.environ.get('DB_USER', 'mobius_user'),
        'PASSWORD': os.environ.get('DB_PASSWORD', 'Alex_Weatherwax_90'),
        'HOST': os.environ.get('DB_HOST', 'localhost'),
        'PORT': os.environ.get('DB_PORT', '5432'),
    }
}

# Redis cache
if os.environ.get('USE_REDIS', '1') == '1':
    CACHES = {
        'default': {
            'BACKEND': 'django_redis.cache.RedisCache',
            'LOCATION': os.environ.get('REDIS_URL', 'redis://127.0.0.1:6379/1'),
            'OPTIONS': {
                'CLIENT_CLASS': 'django_redis.client.DefaultClient',
            }
        }
    }

# CSRF settings
CSRF_TRUSTED_ORIGINS = os.environ.get('CSRF_TRUSTED_ORIGINS', '').split(',') if os.environ.get('CSRF_TRUSTED_ORIGINS') else []

# Security settings (for production)
if not DEBUG:
    SECURE_HSTS_SECONDS = 31536000  # 1 year
    SECURE_SSL_REDIRECT = False  # Set to True if you have SSL
    SESSION_COOKIE_SECURE = False  # Set to True if you have SSL
    CSRF_COOKIE_SECURE = False  # Set to True if you have SSL
