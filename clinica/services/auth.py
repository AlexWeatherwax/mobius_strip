from django.contrib.auth import authenticate
from django.contrib.auth.models import User, Permission
from django.db import transaction
from ..models import Patient, Doctor, MentalState, AwarenessMap, NightmareMap

def authenticate_by_nickname(nickname: str, password: str):
    return authenticate(username=nickname, password=password)

@transaction.atomic
def register_user(nickname: str, password: str, full_name: str, role: str, telegram: str = '') -> User:
    if User.objects.filter(username=nickname).exists():
        raise ValueError('Никнейм уже занят')
    user = User.objects.create_user(username=nickname, password=password)
    if role == 'patient':
        patient = Patient.objects.create(
            user=user, full_name=full_name, nickname=nickname, telegram=telegram or ''
        )
        ms = MentalState.objects.create(level=0, description='')
        patient.mental_state = ms
        patient.save()
        AwarenessMap.objects.create(patient=patient)
        NightmareMap.objects.create(patient=patient)
    elif role == 'doctor':
        Doctor.objects.create(
            user=user, full_name=full_name, nickname=nickname, telegram=telegram or '')
        try:
            perm = Permission.objects.get(codename='can_edit_patients')
            user.user_permissions.add(perm)
        except Permission.DoesNotExist:
            pass
    else:
        raise ValueError('Неизвестная роль')
    return user