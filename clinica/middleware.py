from django.conf import settings
from django.shortcuts import redirect
from . import views as clinica_views
from django.urls import reverse

class LoginRequiredMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response
        # Публичные вьюхи (без авторизации)
        self.public_views = {
            clinica_views.login_view,
            clinica_views.register_view,
            clinica_views.logout_view,
        }

    def __call__(self, request):
        return self.get_response(request)

    def process_view(self, request, view_func, view_args, view_kwargs):
        path = request.path_info

        # Разрешаем статику/медиа
        if settings.STATIC_URL and path.startswith(settings.STATIC_URL):
            return None
        if settings.MEDIA_URL and path.startswith(settings.MEDIA_URL):
            return None

        # Разрешаем админку
        if path.startswith('/admin/'):
            return None

        # Уже авторизован — пропускаем всё
        if request.user.is_authenticated:
            return None

        # Неавторизован: пропускаем только публичные вьюхи
        if view_func in self.public_views:
            return None

        # Остальное — редирект на логин
        return redirect(reverse('clinica:login'))