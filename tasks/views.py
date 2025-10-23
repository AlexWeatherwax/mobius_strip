from rest_framework import viewsets, permissions, status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from .models import Task
from .serializers import TaskSerializer, RegisterSerializer


class TaskViewSet(viewsets.ModelViewSet):
    """ GET /api/tasks/ — список (пагинация) POST /api/tasks/ — создать (только для аутентифицированных) GET /api/tasks/{id}/ — получить PUT/PATCH /api/tasks/{id}/— обновить (только для аутентифицированных) DELETE /api/tasks/{id}/ — удалить (только для аутентифицированных) """
    queryset = Task.objects.all().order_by('-created_at')
    serializer_class = TaskSerializer
    permission_classes = [permissions.AllowAny]

    def get_permissions(self):
        if self.action in ['create', 'update', 'partial_update', 'destroy']:
            return [permissions.IsAuthenticated()]
        return [permissions.AllowAny()]

    def perform_create(self, serializer):
        # Привяжем владельца к задаче, если пользователь аутентифицирован
        owner = self.request.user if self.request.user.is_authenticated else None
        serializer.save(owner=owner)


class RegisterView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        return Response({'id': user.id, 'username': user.username, 'email': user.email}, status=status.HTTP_201_CREATED)


class LogoutView(APIView):
    """ Делает refresh-токен недействительным (Blacklist). Тело запроса: { "refresh": "<refresh_token>" } """
    permission_classes = [permissions.IsAuthenticated]
    def post(self, request):
        refresh = request.data.get('refresh')
        if not refresh:
            return Response({'detail': 'Refresh token is required'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            token = RefreshToken(refresh)
            token.blacklist()
        except Exception:
            return Response({'detail': 'Invalid refresh token'}, status=status.HTTP_400_BAD_REQUEST)
        return Response(status=status.HTTP_205_RESET_CONTENT)
