#!/usr/bin/env bash set -euo pipefail
APP_NAME="mobius_strip"
PROJECT_DIR="/srv/morbius_strip"
DJANGO_USER="django"
BRANCH="${BRANCH:-main}"


sudo -u "$DJANGO_USER" -H bash -lc "cd '$PROJECT_DIR' && git fetch --all && git checkout '$BRANCH' && git pull --ff-only && .venv/bin/pip install -r requirements.txt && .venv/bin/python manage.py migrate && .venv/bin/python manage.py collectstatic --noinput"

sudo supervisorctl restart "$APP_NAME" echo "Deploy complete."

.env.sample
DEBUG=0
SECRET_KEY=change_me
ALLOWED_HOSTS=vm-686640,127.0.0.1,localhost
CSRF_TRUSTED_ORIGINS=https://your-domain.tld

DB_NAME=mobius_clinica
DB_USER=mobius_user
DB_PASSWORD=ChangeMeStrong
DB_HOST=127.0.0.1
DB_PORT=5432

USE_REDIS=1
REDIS_URL=redis://127.0.0.1:6379/1


