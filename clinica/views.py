
from django.contrib import messages
from django.contrib.auth import login, logout
from django.contrib.auth.decorators import login_required
from django.shortcuts import get_object_or_404, redirect, render
from django.urls import reverse
from .forms import ( LoginForm, RegisterForm, PatientProfileForm, DoctorProfileForm, ChemicalRecipeForm, MechanicalCompoundForm, PatientEditByDoctorForm, MentalStateDescriptionForm )
from .models import Patient
from .services import auth as auth_svc
from .services import profiles as profiles_svc
from .services import mental_state as ms_svc
from .services import compounds as compounds_svc
from .services import maps as maps_svc
from .services import doctors as doctors_svc


def login_view(request):
    if request.user.is_authenticated:
        return redirect('clinica:dashboard')
    form = LoginForm(request.POST or None)
    next_url = request.GET.get('next') or request.POST.get('next') or reverse('clinica:dashboard')
    if request.method == 'POST':
        if form.is_valid():
            nickname = form.cleaned_data['nickname']
            password = form.cleaned_data['password']
            try:
                user = auth_svc.authenticate_by_nickname(nickname, password)
            except Exception:
                user = None  # на всякий случай, если сервис бросает исключение
            if user is None:
                # Неверные учетные данные — остаемся на этой странице и показываем ошибку
                form.add_error(None, 'Неверный никнейм или пароль')
            else:
                login(request, user)
                return redirect(next_url)
        # form невалидна — тоже остаемся на странице с ошибками полей

    return render(request, 'clinica/auth/login.html', {'form': form, 'next': next_url})

def logout_view(request):
    logout(request)
    return redirect('clinica:login')

def register_view(request):
    if request.user.is_authenticated:
        return redirect('clinica:dashboard')
    form = RegisterForm(request.POST or None)
    if request.method == 'POST' and form.is_valid():
        nickname = form.cleaned_data['nickname']
        password = form.cleaned_data['password1']
        full_name = form.cleaned_data['full_name']
        role = form.cleaned_data['role']
        telegram = form.cleaned_data.get('telegram') or ''
        try:
            auth_svc.register_user(nickname, password, full_name, role, telegram)
        except ValueError as e:
            form.add_error(None, str(e))
        else:
            messages.success(request, 'Регистрация успешна. Войдите в систему.')
            return redirect('clinica:login')
    return render(request, 'clinica/auth/register.html', {'form': form})

def _build_props_and_extras(obj):
    # obj — AwarenessMap или NightmareMap
    def val(name):
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
    return props, extras

@login_required
def dashboard(request):
    if hasattr(request.user, 'doctor_profile'):
        return redirect('clinica:doctor_patients')
    elif hasattr(request.user, 'patient_profile'):
        return redirect('clinica:patient_profile')
    return redirect('clinica:logout')

@login_required
def patient_profile(request):
    if not hasattr(request.user, 'patient_profile'):
        return redirect('clinica:doctor_patients')
    patient = request.user.patient_profile
    form = PatientProfileForm(request.POST or None, request.FILES or None, instance=patient)
    if request.method == 'POST' and form.is_valid():
        profiles_svc.update_patient_profile( patient, full_name=form.cleaned_data['full_name'], nickname=form.cleaned_data['nickname'], telegram=form.cleaned_data.get('telegram') or '', avatar=form.cleaned_data.get('avatar') )
        messages.success(request, 'Профиль обновлен')
        return redirect('clinica:patient_profile')
    return render(request, 'clinica/patient/profile.html', {'patient': patient, 'form': form})

@login_required
def patient_mental_state(request):
    if not hasattr(request.user, 'patient_profile'):
        return redirect('clinica:dashboard')
    patient = request.user.patient_profile
    ms = ms_svc.get_or_create(patient)
    if request.method == 'POST':
        action = request.POST.get('action')
        if action == 'inc':
            ms_svc.change_level(ms, +1)
        elif action == 'dec':
            ms_svc.change_level(ms, -1)
        return redirect('clinica:patient_mental_state')

    # GET — показываем уровень и актуальное описание (read-only)
    return render(request, 'clinica/patient/mental_state.html', {'patient': patient, 'ms': ms})


@login_required
def patient_chemical_recipes(request):
    if not hasattr(request.user, 'patient_profile'):
        return redirect('clinica:dashboard')
    patient = request.user.patient_profile
    items = compounds_svc.list_patient_chemical(patient)
    form = ChemicalRecipeForm(request.POST or None)
    if request.method == 'POST' and form.is_valid():
        compounds_svc.create_patient_chemical( patient, property_1=form.cleaned_data['property_1'], property_2=form.cleaned_data['property_2'], property_3=form.cleaned_data['property_3'], duration=form.cleaned_data['duration'], extra_property=form.cleaned_data.get('extra_property') or '' )
        messages.success(request, 'Рецепт добавлен')
        return redirect('clinica:patient_chemical_recipes')
    return render(request, 'clinica/patient/chemical_recipes.html', {'patient': patient, 'items': items, 'form': form})

@login_required
def patient_mechanical_compounds(request):
    if not hasattr(request.user, 'patient_profile'):
        return redirect('clinica:dashboard')
    patient = request.user.patient_profile
    items = compounds_svc.list_patient_mechanical(patient)
    form = MechanicalCompoundForm(request.POST or None)
    if request.method == 'POST' and form.is_valid():
        compounds_svc.create_patient_mechanical( patient, property_1=form.cleaned_data['property_1'], property_2=form.cleaned_data['property_2'], property_3=form.cleaned_datap['property_3'], duration=form.cleaned_data['duration'], extra_property=form.cleaned_data.get('extra_property') or '' )
        messages.success(request, 'Прибор добавлен')
        return redirect('clinica:patient_mechanical_compounds')
    return render(request, 'clinica/patient/mechanical_compounds.html', {'patient': patient, 'items': items, 'form': form})

@login_required
def patient_awareness(request):
    if not hasattr(request.user, 'patient_profile'):
        return redirect('clinica:dashboard')
    patient = request.user.patient_profile
    amap = maps_svc.get_or_create_awareness(patient)
    props, extras = _build_props_and_extras(amap)
    return render(request, 'clinica/patient/awareness.html', { 'patient': patient, 'props': props, 'extras': extras, 'mode': 'awareness', })

@login_required
def patient_nightmare(request):
    if not hasattr(request.user, 'patient_profile'):
        return redirect('clinica:dashboard')
    patient = request.user.patient_profile
    nmap = maps_svc.get_or_create_nightmare(patient)
    props, extras = _build_props_and_extras(nmap)
    return render(request, 'clinica/patient/nightmare.html', { 'patient': patient, 'props': props, 'extras': extras, 'mode': 'nightmare', })


@login_required
def doctor_profile(request):
    if not hasattr(request.user, 'doctor_profile'):
        return redirect('clinica:dashboard')
    doctor = request.user.doctor_profile
    form = DoctorProfileForm(request.POST or None, request.FILES or None, instance=doctor)
    if request.method == 'POST' and form.is_valid():
        profiles_svc.update_doctor_profile( doctor, full_name=form.cleaned_data['full_name'], nickname=form.cleaned_data['nickname'], telegram=form.cleaned_data.get('telegram') or '', avatar=form.cleaned_data.get('avatar') )
        messages.success(request, 'Профиль обновлен')
        return redirect('clinica:doctor_profile')
    return render(request, 'clinica/doctor/profile.html', {'doctor': doctor, 'form': form})

@login_required
def doctor_patients(request):
    if not hasattr(request.user, 'doctor_profile'):
        return redirect('clinica:dashboard')
    patients = doctors_svc.list_patients()
    return render(request, 'clinica/doctor/patients.html', {'patients': patients})

@login_required
def doctor_patient_detail(request, patient_id):
    if not hasattr(request.user, 'doctor_profile'):
        return redirect('clinica:dashboard')
    patient = get_object_or_404(Patient, id=patient_id)
    form = PatientEditByDoctorForm(request.POST or None, instance=patient)
    ms_initial = {'description': patient.mental_state.description if patient.mental_state else ''}
    ms_form = MentalStateDescriptionForm(request.POST or None, initial=ms_initial)
    if request.method == 'POST':
        saved = False
        if 'save_patient' in request.POST and form.is_valid():
            doctors_svc.update_patient( patient, full_name=form.cleaned_data['full_name'], nickname=form.cleaned_data['nickname'], telegram=form.cleaned_data['telegram'], chemistry_level=form.cleaned_data['chemistry_level'], mechanics_level=form.cleaned_data['mechanics_level'], social_skills_level=form.cleaned_data['social_skills_level'], physical_skills_level=form.cleaned_data['physical_skills_level'], bonus_level=form.cleaned_data['bonus_level'] )
            saved = True
        if 'save_ms' in request.POST and ms_form.is_valid():
            doctors_svc.update_ms_description_for_patient(patient, ms_form.cleaned_data['description'])
            saved = True
        if saved:
            messages.success(request, 'Изменения сохранены')
            return redirect('clinica:doctor_patient_detail', patient_id=patient.id)
    return render(request, 'clinica/doctor/patient_detail.html', {'patient': patient, 'form': form, 'ms_form': ms_form})

@login_required
def doctor_patient_awareness_edit(request, patient_id):
    if not hasattr(request.user, 'doctor_profile'):
        return redirect('clinica:dashboard')
    patient = get_object_or_404(Patient, id=patient_id)
    amap = maps_svc.get_or_create_awareness(patient)
    if request.method == 'POST':
        maps_svc.update_awareness(amap, request.POST)
        messages.success(request, 'Карта осознания обновлена')
        return redirect('clinica:doctor_patient_awareness_edit', patient_id=patient.id)
    return render(request, 'clinica/doctor/awareness_edit.html', {'patient': patient, 'amap': amap})

@login_required
def doctor_patient_nightmare_edit(request, patient_id):
    if not hasattr(request.user, 'doctor_profile'):
        return redirect('clinica:dashboard')
    patient = get_object_or_404(Patient, id=patient_id)
    nmap = maps_svc.get_or_create_nightmare(patient)
    if request.method == 'POST':
        maps_svc.update_nightmare(nmap, request.POST)
        messages.success(request, 'Карта кошмара обновлена')
        return redirect('clinica:doctor_patient_nightmare_edit', patient_id=patient.id)
    return render(request, 'clinica/doctor/nightmare_edit.html', {'patient': patient, 'nmap': nmap})

@login_required
def doctor_chemical_recipes(request):
    if not hasattr(request.user, 'doctor_profile'):
        return redirect('clinica:dashboard')
    doctor = request.user.doctor_profile
    items = compounds_svc.list_all_chemical()
    form = ChemicalRecipeForm(request.POST or None)
    if request.method == 'POST' and form.is_valid():
        owner_id = request.POST.get('owner_id')
        owner = get_object_or_404(Patient, id=owner_id)
        compounds_svc.create_doctor_chemical( doctor, owner, property_1=form.cleaned_data['property_1'], property_2=form.cleaned_data['property_2'], property_3=form.cleaned_data['property_3'], duration=form.cleaned_data['duration'], extra_property=form.cleaned_data.get('extra_property') or '' )
        messages.success(request, 'Рецепт добавлен')
        return redirect('clinica:doctor_chemical_recipes')
    patients = doctors_svc.list_patients()
    return render(request, 'clinica/doctor/chemical_recipes.html', {'doctor': doctor, 'items': items, 'form': form, 'patients': patients})

@login_required
def doctor_mechanical_compounds(request):
    if not hasattr(request.user, 'doctor_profile'):
        return redirect('clinica:dashboard')
    doctor = request.user.doctor_profile
    items = compounds_svc.list_all_mechanical()
    form = MechanicalCompoundForm(request.POST or None)
    if request.method == 'POST' and form.is_valid():
        owner_id = request.POST.get('owner_id')
        owner = get_object_or_404(Patient, id=owner_id)
        compounds_svc.create_doctor_mechanical( doctor, owner, property_1=form.cleaned_data['property_1'], property_2=form.cleaned_data['property_2'], property_3=form.cleaned_data['property_3'], duration=form.cleaned_data['duration'], extra_property=form.cleaned_data.get('extra_property') or '' )
        messages.success(request, 'Прибор добавлен')
        return redirect('clinica:doctor_mechanical_compounds')
    patients = doctors_svc.list_patients()
    return render(request, 'clinica/doctor/mechanical_compounds.html', {'doctor': doctor, 'items': items, 'form': form, 'patients': patients})
