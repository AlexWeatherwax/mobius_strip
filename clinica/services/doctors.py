from ..models import Patient
from .mental_state import get_or_create as get_or_create_ms

def list_patients():
    return Patient.objects.all().order_by('full_name')

def update_patient(patient: Patient, *, full_name: str, nickname: str, telegram: str, chemistry_level: int, mechanics_level: int, social_skills_level: int, physical_skills_level: int, bonus_level: str) -> Patient:
    patient.full_name = full_name
    patient.nickname = nickname
    patient.telegram = telegram or ''
    patient.chemistry_level = chemistry_level
    patient.mechanics_level = mechanics_level
    patient.social_skills_level = social_skills_level
    physical_skills_level = physical_skills_level
    bonus_level = bonus_level
    patient.save()
    if patient.user and patient.user.username != nickname:
        patient.user.username = nickname
        patient.user.save()
    return patient

def update_ms_description_for_patient(patient: Patient, description: str):
    ms = get_or_create_ms(patient)
    ms.description = description or ''
    ms.save(update_fields='description')
    return ms