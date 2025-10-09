from ..models import Patient, MentalState, MentalStatePreset

def get_or_create(patient: Patient) -> MentalState:
    if patient.mental_state:
        ms = patient.mental_state
        try:
            preset = MentalStatePreset.objects.get(level=ms.level)
            if ms.description != preset.description:
                ms.description = preset.description
                ms.save(update_fields=['description'])
        except MentalStatePreset.DoesNotExist:
            pass
        return ms
        # создаем новое состояние, сразу с описанием из справочника (если есть)
        preset_desc = ''
        try:
            preset_desc = MentalStatePreset.objects.get(level=0).description
        except MentalStatePreset.DoesNotExist:
            pass
        ms = MentalState.objects.create(level=0, description=preset_desc)
        patient.mental_state = ms
        patient.save(update_fields=['mental_state'])
        return ms


def change_level(ms: MentalState, delta: int) -> MentalState:
    new_level = max(-3, min(3, ms.level + delta))
    if new_level != ms.level:
        ms.level = new_level
        # тянем описание из справочника
        try:
            preset = MentalStatePreset.objects.get(level=new_level)
            ms.description = preset.description
            ms.save(update_fields=['level', 'description'])
        except MentalStatePreset.DoesNotExist:
            # если нет пресета — сохраняем только уровень
            ms.save(update_fields=['level'])
    return ms


def update_description(ms: MentalState, description: str) -> MentalState:
    # Если потребуется редактирование (например, врачом) — оставляем метод,
    # но в текущей постановке пациент его не использует.
    ms.description = description or ''
    ms.save(update_fields=['description'])
    return ms