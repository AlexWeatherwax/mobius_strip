from django import forms
from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from .models import Patient, Doctor, ChemicalRecipe, MechanicalCompound


class LoginForm(forms.Form):
    nickname = forms.CharField(label='Никнейм')
    password = forms.CharField(label='Пароль', widget=forms.PasswordInput)

class RegisterForm(forms.Form):
    ROLE_CHOICES = (('patient', 'Пациент'), ('doctor', 'Врач'))
    nickname = forms.CharField(label='Никнейм')
    password1 = forms.CharField(label='Пароль', widget=forms.PasswordInput)
    password2 = forms.CharField(label='Повторите пароль', widget=forms.PasswordInput)
    full_name = forms.CharField(label='Имя персонажа')
    role = forms.ChoiceField(label='Тип персонажа', choices=ROLE_CHOICES)
    telegram = forms.CharField(label='Telegram', required=False)

    def clean_nickname(self):
        nickname = self.cleaned_data['nickname']
        if User.objects.filter(username=nickname).exists():
            raise forms.ValidationError('Никнейм уже занят')
        return nickname
    def clean(self):
        cleaned = super().clean()
        if cleaned.get('password1') != cleaned.get('password2'):
            raise forms.ValidationError('Пароли не совпадают')
        return cleaned

class PatientProfileForm(forms.ModelForm):
    class Meta:
        model = Patient
        fields = ['full_name', 'nickname', 'telegram', 'avatar']

class DoctorProfileForm(forms.ModelForm):
    class Meta:
        model = Doctor
        fields = ['full_name', 'nickname', 'telegram', 'avatar']

class ChemicalRecipeForm(forms.ModelForm):
    class Meta:
        model = ChemicalRecipe
        fields = ['property_1', 'property_2', 'property_3', 'duration', 'extra_property']

class MechanicalCompoundForm(forms.ModelForm):
    class Meta:
        model = MechanicalCompound
        fields = ['property_1', 'property_2', 'property_3', 'duration', 'extra_property']

class PatientEditByDoctorForm(forms.ModelForm):
    class Meta:
        model = Patient
        fields = ['full_name', 'nickname', 'telegram', 'chemistry_level', 'mechanics_level', 'social_skills_level', 'physical_skills_level', 'bonus_level']

class MentalStateDescriptionForm(forms.Form):
    description = forms.CharField(label='Описание состояния', widget=forms.Textarea, required=False)