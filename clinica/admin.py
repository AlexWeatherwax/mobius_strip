from django.contrib import admin
from .models import ( Patient, Doctor, MentalState, NightmareMap, AwarenessMap, ChemicalRecipe, MechanicalCompound, MentalStatePreset )

from django.utils.html import format_html
@admin.register(MentalStatePreset)
class MentalStatePresetAdmin(admin.ModelAdmin):
    list_display = ('level', 'description')
    search_fields = ('description',)

@admin.register(Patient)
class PatientAdmin(admin.ModelAdmin):
    list_display = ('avatar_preview', 'full_name', 'nickname', 'telegram', 'chemistry_level', 'mechanics_level', 'social_skills_level', 'mental_state', 'physical_skills_level', 'bonus_level')
    search_fields = ('full_name', 'nickname', 'telegram')
    def avatar_preview(self, obj):
        if obj.avatar:
            return format_html('<img src="{}" style="height:40px;border-radius:50%;" />', obj.avatar.url)
        return '—'
    avatar_preview.short_description = 'Аватар'

@admin.register(Doctor)
class DoctorAdmin(admin.ModelAdmin):
    list_display = ('avatar_preview', 'full_name', 'nickname', 'telegram', 'user')
    search_fields = ('full_name', 'nickname', 'telegram')
    def avatar_preview(self, obj):
        if obj.avatar:
            return format_html('<img src="{}" style="height:40px;border-radius:50%;" />', obj.avatar.url)
        return '—'
    avatar_preview.short_description = 'Аватар'

@admin.register(MentalState)
class MentalStateAdmin(admin.ModelAdmin):
    list_display = ('level', 'description', 'created_at', 'updated_at')
    search_fields = ('description',)

@admin.register(NightmareMap)
class NightmareMapAdmin(admin.ModelAdmin):
    list_display = ('patient', 'property_1_condition', 'property_1_description')

@admin.register(AwarenessMap)
class AwarenessMapAdmin(admin.ModelAdmin):
    list_display = ('patient', 'property_1_condition', 'property_1_description')

@admin.register(ChemicalRecipe)
class ChemicalRecipeAdmin(admin.ModelAdmin):
    list_display = ('owner', 'author_display', 'property_1', 'property_2', 'property_3', 'duration')
    autocomplete_fields = ('owner', 'author_patient', 'author_doctor')
    def author_display(self, obj):
        return obj.author_str()
    author_display.short_description = 'Автор'

@admin.register(MechanicalCompound)
class MechanicalCompoundAdmin(admin.ModelAdmin):
    list_display = ('owner', 'author_display', 'property_1', 'property_2', 'property_3', 'duration')
    autocomplete_fields = ('owner', 'author_patient', 'author_doctor')
    def author_display(self, obj):
        return obj.author_str()
    author_display.short_description = 'Автор'










