from typing import TYPE_CHECKING
from django.core.cache import cache
if TYPE_CHECKING: from ..models import Patient, AwarenessMap, NightmareMap
FIELDS = ['property_1_condition', 'property_1_description', 'property_2_condition', 'property_2_description', 'property_3_condition', 'property_3_description', 'property_4_condition', 'property_4_description', 'extra_property_1_description', 'extra_property_2_description',]

CACHE_TTL = 300
def get_or_create_awareness(patient: 'Patient') -> 'AwarenessMap':
    from ..models import AwarenessMap # локальный импорт
    amap = getattr(patient, 'awareness_map', None)
    if amap:
        return amap
    return AwarenessMap.objects.create(patient=patient)

def get_or_create_nightmare(patient: 'Patient') -> 'NightmareMap':
    from ..models import NightmareMap # локальный импорт
    nmap = getattr(patient, 'nightmare_map', None)
    if nmap:
        return nmap
    return NightmareMap.objects.create(patient=patient)

def _build_payload(obj):
    def val(name: str) -> str:
        return getattr(obj, name, '') or ''
    props = []
    for i in range(1, 5):
        props.append({
            'num': i,
            'condition': val(f'property_{i}_condition'),
            'description': val(f'property_{i}_description'),
        })

    extras = {
        'extra1': val('extra_property_1_description'),
        'extra2': val('extra_property_2_description'),
    }
    return {'props': props, 'extras': extras}
def _awareness_key(pid: int) -> str:
    return f'awareness:payload:{pid}'
def _nightmare_key(pid: int) -> str:
    return f'nightmare:payload:{pid}'

def get_awareness_payload(patient: 'Patient') -> dict:
    key = _awareness_key(patient.id)
    data = cache.get(key)
    if data is not None:
        return data
    amap = get_or_create_awareness(patient)
    data = _build_payload(amap)
    cache.set(key, data, CACHE_TTL)
    return data

def get_nightmare_payload(patient: 'Patient') -> dict:
    key = _nightmare_key(patient.id)
    data = cache.get(key)
    if data is not None:
        return data
    nmap = get_or_create_nightmare(patient)
    data = _build_payload(nmap)
    cache.set(key, data, CACHE_TTL)
    return data

def update_awareness(amap: 'AwarenessMap', data: dict) -> 'AwarenessMap':

    changed_fields = []
    for f in FIELDS:
        new_val = data.get(f, '')
        if getattr(amap, f) != new_val:
            setattr(amap, f, new_val)
            changed_fields.append(f)
    if changed_fields:
        amap.save(update_fields=changed_fields)
        cache.delete(_awareness_key(amap.patient_id))
    return amap

def update_nightmare(nmap: 'NightmareMap', data: dict) -> 'NightmareMap':
    changed_fields = []
    for f in FIELDS:
        new_val = data.get(f, '')
        if getattr(nmap, f) != new_val:
            setattr(nmap, f, new_val)
            changed_fields.append(f)
    if changed_fields:
        nmap.save(update_fields=changed_fields)
        cache.delete(_nightmare_key(nmap.patient_id))
    return nmap

