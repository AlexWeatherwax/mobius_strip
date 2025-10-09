from ..models import Patient, Doctor

def update_patient_profile(patient: Patient, *, full_name: str, nickname: str, telegram: str = '', avatar=None) -> Patient:
    patient.full_name = full_name
    patient.nickname = nickname
    patient.telegram = telegram or ''
    if avatar is not None:
        patient.avatar = avatar
        patient.save()
    if patient.user and patient.user.username != nickname:
        patient.user.username = nickname
        patient.user.save()
    return patient

def update_doctor_profile(doctor: Doctor, *, full_name: str, nickname: str, telegram: str = '', avatar=None) -> Doctor:
    doctor.full_name = full_name
    doctor.nickname = nickname
    doctor.telegram = telegram or ''
    if avatar is not None:
        doctor.avatar = avatar
        doctor.save() 
    if doctor.user and doctor.user.username != nickname:
        doctor.user.username = nickname
        doctor.user.save()
        return doctor