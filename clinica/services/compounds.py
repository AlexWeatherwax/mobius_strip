from typing import Iterable
from ..models import Patient, Doctor, ChemicalRecipe, MechanicalCompound

def list_patient_chemical(patient: Patient) -> Iterable[ChemicalRecipe]:
    return ChemicalRecipe.objects.filter(owner=patient).order_by('-created_at')

def list_patient_mechanical(patient: Patient) -> Iterable[MechanicalCompound]:
    return MechanicalCompound.objects.filter(owner=patient).order_by('-created_at')

def list_all_chemical() -> Iterable[ChemicalRecipe]:
    return ChemicalRecipe.objects.select_related('owner').order_by('-created_at')

def list_all_mechanical() -> Iterable[MechanicalCompound]:
    return MechanicalCompound.objects.select_related('owner').order_by('-created_at')

def create_patient_chemical(patient: Patient, *, property_1: str, property_2: str, property_3: str, duration, extra_property: str = '') -> ChemicalRecipe:
    return ChemicalRecipe.objects.create( owner=patient, author_patient=patient, property_1=property_1, property_2=property_2, property_3=property_3, duration=duration, extra_property=extra_property or '' )

def create_patient_mechanical(patient: Patient, *, property_1: str, property_2: str, property_3: str, duration, extra_property: str = '') -> MechanicalCompound:
    return MechanicalCompound.objects.create( owner=patient, author_patient=patient, property_1=property_1, property_2=property_2, property_3=property_3, duration=duration, extra_property=extra_property or '' )

def create_doctor_chemical(doctor: Doctor, owner: Patient, *, property_1: str, property_2: str, property_3: str, duration, extra_property: str = '') -> ChemicalRecipe:
    return ChemicalRecipe.objects.create( owner=owner, author_doctor=doctor, property_1=property_1, property_2=property_2, property_3=property_3, duration=duration, extra_property=extra_property or '' )

def create_doctor_mechanical(doctor: Doctor, owner: Patient, *, property_1: str, property_2: str, property_3: str, duration, extra_property: str = '') -> MechanicalCompound:
    return MechanicalCompound.objects.create( owner=owner, author_doctor=doctor, property_1=property_1, property_2=property_2, property_3=property_3, duration=duration, extra_property=extra_property or '' )