from django.core.cache import cache
from django.db.models.signals import post_save
from django.dispatch import receiver

from .models import AwarenessMap, NightmareMap
from .services import maps as maps_svc

@receiver(post_save, sender=AwarenessMap)
def clear_awareness_cache(sender, instance, **kwargs):
    cache.delete(maps_svc._awareness_key(instance.patient_id))

@receiver(post_save, sender=NightmareMap)
def clear_nightmare_cache(sender, instance, **kwargs):
    cache.delete(maps_svc._nightmare_key(instance.patient_id))

